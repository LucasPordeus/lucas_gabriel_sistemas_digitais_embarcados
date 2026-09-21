# Arquitetura do Projeto — Semáforo Inteligente com Botão de Pedestre (ARM–FPGA)

> Este documento descreve a arquitetura do sistema: como as camadas de
> hardware, RTL (FPGA), protocolo de comunicação e software (Raspberry Pi)
> se encaixam, e por que as decisões de design foram tomadas dessa forma.


## 1. Visão geral

O sistema é um **cruzamento de trânsito híbrido ARM+FPGA**: a FPGA (Tang
Nano 4K) é o sistema embarcado de tempo real que efetivamente controla o
semáforo — lê os sensores, decide os estados, aciona os LEDs e garante a
segurança temporal do cruzamento — e a Raspberry Pi Zero 2W é o
"supervisor" que configura parâmetros, monitora o sistema e expõe um log
legível para humanos, sem nunca participar da decisão de segurança em si.

Essa divisão de responsabilidade é o princípio arquitetural central do
projeto:

- **A FPGA nunca depende do ARM para operar com segurança.** Mesmo sem
  nenhum comando chegar via protocolo serial, o semáforo funciona com
  valores padrão de segurança carregados no reset (ver seção 5).
- **O ARM nunca comanda diretamente um LED, sensor ou o tempo de fase.**
  Ele só envia parâmetros de configuração (tempos, limiares) e lê
  telemetria (estado atual, contagem regressiva). A FSM que decide as
  transições vive inteiramente na FPGA.

## 2. Camadas do sistema

| Camada | Onde vive | Responsabilidade |
|---|---|---|
| Hardware físico | Protoboard, sensor IR, botão, LEDs | Entradas/saídas do mundo real |
| RTL (FPGA) | `rtl/*.v` | Toda a lógica de controle e segurança, em tempo real determinístico |
| Protocolo de comunicação | `rtl/protocolo_serial.v` + `asm/lib/protocolo_serial_gpio.s` (real) / `buffer_lib.s` (simulado) | Ponte síncrona ARM↔FPGA, sem depender de tensão/velocidade diferentes |
| Software ARM64 | `asm/*.s` na Raspberry Pi | Configuração, telemetria, testes de desempenho, log em tempo real |

## 3. Camada RTL (FPGA) — `rtl/top_semaforo.v` como módulo de topo

`top_semaforo.v` integra oito sub-blocos (sete até o TP5; `prescaler.v`
foi adicionado na Entrega Final, ver seção 3.6). Cada um tem uma
responsabilidade única e é testado isoladamente antes da integração (ver
`tb/`, 11 conjuntos de testbenches, 100% passando — `prescaler.v` não tem
testbench próprio, é validado indiretamente dentro de `tb_top_semaforo.v`):

```
sensor_raw ──►[~]──► debounce.v ──► sensor_veiculo.v ──┐
                                                    │ veiculo_pulso
botao_raw  ──►[~]──► debounce.v ──► botao_pedestre.v ──┼──────────────┐
                                                    │              │
                                                    ▼              ▼
                                          bram_historico.v   fsm_semaforo.v ──► estado_basico_decoder.v ──► LEDs (veículos)
                                                    │              │  (usa contador_tempo.v internamente)   └─► verde_pedestre/vermelho_pedestre
                                                    ▼              │
                                          media_movel_dsp.v        │ estado_carro + contagem_atual
                                          (nivel_fluxo)             │
                                                    │              │
                                                    ▼              ▼
                                         tempo_min_efetivo ──► (entra como tempo_min_verde da FSM)
                                                                    │
                              clk ──► prescaler.v ──► tick_fsm ──► (habilita a FSM e a janela de amostragem)
                                                                    │
                                                                    ▼
                                                          protocolo_serial.v ◄──► sclk/cs_n/mosi/miso/busy (Raspberry Pi)
```

`sensor_raw`/`botao_raw` chegam invertidos (`~`) porque, no hardware
físico real, tanto o sensor IR quanto o botão de pedestre (onboard `S1`
da Tang Nano) são ativos em nível baixo — ver seção 3.1. A lista completa
dos bugs encontrados só no bring-up físico (oscilador, banco de tensão,
polaridade, janela de amostragem, telemetria instável) está em
`CONTEXTO_PROJETO_SEMAFORO_INTELIGENTE.md`, seção 7, itens 6–10; este
documento foca nas decisões de design resultantes (seção 9), não no
histórico de depuração em si.

### 3.1 Aquisição — `debounce.v`, `sensor_veiculo.v`, `botao_pedestre.v`

`debounce.v` é um filtro genérico (contador de estabilidade por N ciclos)
reaproveitado pelos dois módulos de aquisição. `sensor_veiculo.v` gera um
pulso de 1 ciclo por detecção (borda de subida do sinal filtrado do sensor
IR — a saída digital direta do sensor de obstáculo reflexivo infravermelho,
sem trigger/echo como no antigo HC-SR04). `botao_pedestre.v` gera a
solicitação de pedestre e é limpo (`limpa_solicitacao`) só quando a FSM
efetivamente concede a travessia — evitando perder ou duplicar um clique.

### 3.2 Histórico e nível de fluxo — `bram_historico.v` + `media_movel_dsp.v`

Cada pulso de veículo é contado numa janela de tempo (`JANELA_AMOSTRAGEM`
ciclos) por um amostrador dentro do próprio `top_semaforo.v`; o valor da
janela alimenta `media_movel_dsp.v`, que mapeia BRAM física e a
multiplicação do filtro de média móvel para o bloco DSP nativo da FPGA
(síntese no Gowin EDA). O resultado é `nivel_fluxo` (baixo/médio/alto),
usado só internamente — **nunca** chega a decidir nada por si só; ele
apenas ajusta um parâmetro que a FSM usa. Os limiares de classificação
(`limiar_baixo`/`limiar_alto`) são hoje `0`/`1` de fábrica — reduzidos de
propósito para facilitar demonstração manual; o RTL comenta `3`/`8` como
valores de referência mais realistas para produção (ver seção 5).

### 3.3 Tempo de verde dinâmico

`top_semaforo.v` deriva `tempo_min_efetivo` de `nivel_fluxo`: metade do
valor de referência com piso de 3 ciclos (baixo), valor de referência
(médio) ou dobro com teto de 63 ciclos (alto) — sempre respeitando o
limite de segurança mínimo (critério ONF-08) e a largura de 6 bits usada
pelo protocolo serial. Esse valor entra na FSM como `tempo_min_verde`.

### 3.4 FSM — `fsm_semaforo.v` (+ `contador_tempo.v`)

Máquina de Moore com três estados: `CARRO_VERDE → CARRO_AMARELO →
PEDESTRE_VERDE → CARRO_VERDE`. A transição de `CARRO_VERDE` só ocorre
quando **duas condições** são verdadeiras ao mesmo tempo:
`tempo_esgotado && solicitacao_pedestre` — ou seja, o pedestre nunca é
atendido antes do tempo mínimo de segurança, e os veículos nunca ficam
parados sem necessidade se ninguém solicitar a travessia. `estado_carro`
codifica `00=vermelho, 01=amarelo, 10=verde`; o contador interno
(`contador_tempo.v`) expõe seu valor corrente via `contagem_atual` —
essa é a saída que alimenta a telemetria de countdown.

### 3.5 Protocolo serial — `protocolo_serial.v`

Interface síncrona de 5 fios, estilo SPI simplificado com handshaking
próprio (ver seção 4). É o único ponto de contato entre a FPGA e o mundo
externo (ARM) — a FSM em si não sabe que a Raspberry Pi existe.

### 3.6 Temporização real — `prescaler.v` (adicionado no bring-up físico)

Um oitavo sub-bloco, ausente de uma versão anterior deste documento, e
motivado por um bug real (ver seção 9): `prescaler.v` divide o clock de
27 MHz por `DIVISOR_TICK` (parâmetro de `top_semaforo.v`) para gerar
`tick_fsm`, o sinal que efetivamente governa a FSM e a janela de
amostragem de tráfego. No hardware físico real, `DIVISOR_TICK=27_000_000`
faz cada tick valer 1 segundo real; nos testbenches, `DIVISOR_TICK=1` faz
cada tick valer 1 ciclo, para simular rápido. Sem esse módulo — que não
existia até a Entrega Final — os tempos de fase (5/10/20/3/15) durariam
frações de microssegundo em hardware real, o que motivou sua criação
durante o bring-up físico (ver `final_project/ARQUITETURA_FPGA_RASPBERRY.md`
para o resto do raciocínio de segurança). Não tem testbench próprio; é
validado indiretamente dentro de `tb_top_semaforo.v`.

## 4. Camada de comunicação: protocolo serial ARM↔FPGA

5 sinais, todos a 3,3V (sem conversor de nível entre as placas):

| Sinal | Direção | Função |
|---|---|---|
| `sclk` | RPi → FPGA | clock serial da transferência |
| `cs_n` | RPi → FPGA | chip-select / handshake de início-fim de quadro (ativo em nível baixo) |
| `mosi` | RPi → FPGA | byte de comando (ARM configura a FPGA) |
| `miso` | FPGA → RPi | byte de telemetria (alta impedância quando `cs_n=1`) |
| `busy` | FPGA → RPi | pulsa 1 ciclo de `clk` ao final de cada quadro de 8 bits — **não usado** pelo driver de hardware físico (`protocolo_serial_gpio.s`): o pulso dura ~37 ns a 27 MHz, curto demais para bit-bang em software conseguir ler; o fio nem é conectado na montagem (ver `final_project/GUIA_MONTAGEM_HARDWARE.md`) |

**Formato do comando** (`mosi`, MSB primeiro): `[7:6]=opcode` `[5:0]=valor`,
com 4 opcodes (`OP_TEMPO_MIN`, `OP_TEMPO_AMARELO`, `OP_LIMIAR_BAIXO`,
`OP_LIMIAR_ALTO`) — o ARM só ajusta parâmetros, nunca estados.

**Formato da telemetria** (`miso`, MSB primeiro) — versão real usada por
`top_semaforo.v`/`protocolo_serial.v`, decodificada por
`monitor_semaforo_hw.s`:

- `[7:6] = fase_telemetria` — normalmente espelha `estado_carro`
  (00=vermelho/pedestre-verde, 01=amarelo, 10=verde), mas reaproveita o
  código `11` (nunca usado por `estado_carro`) para indicar "CARRO_VERDE
  com solicitação de pedestre pendente", sem gastar um bit extra.
- `[5:4] = nivel_fluxo` (00=baixo, 01=médio, 10=alto).
- `[3:0] = tempo_ate_pedestre` truncado para 4 bits (0–15) — **não** é a
  contagem regressiva bruta da fase atual (`contagem_atual`): durante
  `CARRO_VERDE` soma o verde restante **mais** o amarelo inteiro que
  ainda vai rodar; durante `CARRO_AMARELO` é só o amarelo restante;
  durante `PEDESTRE_VERDE` é `0`. Em tráfego alto o valor real pode
  passar de 15 e saturar no byte (limitação só de exibição).

**Uma versão anterior deste documento descrevia um formato mais simples**
(`[7:6]=fase_carro_atual`, `[5:0]=contagem_regressiva` de 6 bits, sem
`nivel_fluxo` empacotado) — esse formato nunca chegou a ser implementado
no `protocolo_serial.v`/`top_semaforo.v` reais; é o que
`asm/monitor_semaforo.s` (a versão *simulada*, sem hardware conectado)
ainda fabrica localmente por conta própria, sem nunca ler a FPGA de
verdade. Só `monitor_semaforo_hw.s`, que lê o byte real via
`protocolo_serial_gpio.s`, precisa decodificar o formato atual — e o faz
extraindo só os 4 bits baixos (`and x22, x0, #15`). Validado em
`tb_top_semaforo.v` (caso 6), lendo o byte real via `sclk`/`mosi`/`miso`,
não apenas os sinais internos.

Esse protocolo foi escolhido no lugar de barramento paralelo (usado nos
TP3/TP4) porque reduz de ~10 fios para 5, elimina a necessidade de
sinalização `strobe`/`ack` separada (o `busy` já cumpre esse papel) e é o
padrão mais natural para uma interface ARM↔FPGA de baixa velocidade sem
DMA — mesmo não sendo SPI de hardware "de livro" (ver seção 6.2).

## 5. Por que a FPGA nunca depende do ARM (segurança)

No reset (`rst_n=0`), `top_semaforo.v` carrega valores padrão de
segurança nos registradores de configuração (`tempo_min_reg=10`,
`tempo_amarelo_reg=3`, `limiar_baixo_reg=0`, `limiar_alto_reg=1`) — **antes**
de qualquer comando chegar via protocolo serial. Os limiares de fluxo
(`0`/`1`) são deliberadamente baixos para facilitar demonstração manual;
o RTL comenta `3`/`8` como valores de referência mais realistas para uma
implantação de produção, onde se exigiria trânsito sustentado para
classificar como "alto". Isso significa que o
semáforo funciona corretamente mesmo se a Raspberry Pi nunca enviar um
único comando, ou se o link serial cair no meio da operação. É o
requisito de segurança do cruzamento (ONF-08): o tempo mínimo de verde dos
veículos nunca cai abaixo de um piso, mesmo com pedestre esperando e
trânsito baixo — essa garantia vive inteiramente dentro da FPGA.

## 6. Camada de software ARM64 (Raspberry Pi)

### 6.1 Biblioteca estática — `asm/lib/libembarcado.a`

**Quatro** módulos, montados uma vez e reaproveitados por todos os
programas (`LIB_OBJS` no `Makefile` confirma os quatro objetos — uma
versão anterior deste documento citava só três, faltando o quarto):

- **`gpio_lib.s`**: acesso a `/dev/gpiomem` (mapeamento real de registradores
  GPIO do BCM2710A1) com `gpio_map_init`/`gpio_set_bit`/`gpio_clear_bit`/
  `gpio_read_bit` — qualquer GPIO de uso geral serve, já que o protocolo
  não usa o periférico SPI de hardware da Raspberry Pi (ver seção 6.2).
- **`strings_lib.s`**: conversão de inteiro para decimal (`uint_to_dec`) e
  utilitários de string, usados para montar as linhas de log impressas
  via syscall `write()` (sem libc).
- **`buffer_lib.s`**: um buffer circular FIFO (`cbuf_push`/`cbuf_pop`) que
  simula, em software, o comportamento de round-trip do link serial —
  usado tanto no teste de desempenho (`main_tp5.s`) quanto na versão
  simulada do log de countdown (`monitor_semaforo.s`, sem hardware
  conectado).
- **`protocolo_serial_gpio.s`** (Entrega Final, hardware físico): o driver
  que efetivamente bate os pinos `sclk`/`cs_n`/`mosi`/`miso` via
  `gpio_lib.s` para falar com uma Tang Nano real, implementando o
  protocolo SPI-like em hardware — usado por `monitor_semaforo_hw.s`. É
  este módulo, não `buffer_lib.s`, que faz a comunicação real acontecer.

### 6.2 Por que bit-banging em vez do periférico SPI de hardware

A Raspberry Pi tem dois controladores SPI dedicados (SPI0: GPIO8/9/10/11;
SPI1: GPIO18/19/20/21), mas o protocolo deste projeto **não** os usa. O
`protocolo_serial.v` da FPGA é customizado (tem um sinal `busy` que o SPI
padrão não tem — e que, na prática, nem chega a ser usado pelo driver,
ver seção 4), então `protocolo_serial_gpio.s` (sobre `gpio_lib.s`)
manipula GPIOs de uso geral diretamente ("bit-banging"), com a
temporização controlada em software. Na montagem física real, os GPIOs
usados são fixos, não "qualquer um livre do header" como uma versão
anterior deste documento sugeria: `sclk`=GPIO11 (pino físico 23),
`cs_n`=GPIO6 (pino 31), `mosi`=GPIO10 (pino 19), `miso`=GPIO20 (pino 38)
— ver `final_project/GUIA_MONTAGEM_HARDWARE.md` para o mapeamento físico
completo (não existe mais um `Mapeamento_Conexoes_Hardware.md` separado).
O atraso entre transições de pino (`ATRASO_ITER` em
`protocolo_serial_gpio.s`) foi ajustado para ~10–20 kHz de `sclk` depois
de um problema real de ringing/crosstalk em protoboard — ver
`CONTEXTO_PROJETO_SEMAFORO_INTELIGENTE.md`, seção 7, item 10, para o
diagnóstico completo.

### 6.3 Programas principais

- **`main_tp5.s`**: programa de configuração + teste de desempenho —
  usa macros para enviar comandos e ler telemetria via o buffer circular
  **simulado** (`buffer_lib.s`, sem hardware conectado), mede
  throughput/latência com `clock_gettime`/`nanosleep` (syscalls puros,
  sem libc).
- **`monitor_semaforo.s`** (extensão pós-TP5, **simulado**): monta seu
  próprio byte de telemetria em software e imprime o countdown até os
  sinais dos carros/pedestre fecharem, para dois cenários fixos de
  trânsito (baixo/alto) — não lê nada de uma FPGA real.
- **`monitor_semaforo_hw.s`** (Entrega Final, **hardware físico real** —
  ausente de uma versão anterior deste documento): usa
  `protocolo_serial_gpio.s` para ler de verdade o byte de telemetria que
  sai do pino `miso` de uma Tang Nano conectada, e imprime
  `[t=Ns] ABERTO PARA O PEDESTRE` / `FECHADO PARA PEDESTRE` a cada
  segundo. Se rodado sem a placa conectada (ou sem `sudo`, necessário
  para `/dev/gpiomem`), cai automaticamente em modo simulado com
  telemetria zerada em vez de travar — é o programa que efetivamente
  produz o "log em tempo real" a partir de hardware de verdade, e não
  apenas de uma simulação em software.
- **`test_lib.s`**: harness de verificação da própria biblioteca
  (equivalente a um testbench, mas para o código ARM).
- Os programas de cada TP anterior (`tp1_fluxo_basico.s` … `tp4_neon_simd.s`,
  `gpio_map.s`) ficam mantidos como registro do desenvolvimento
  incremental exigido pelo enunciado, mas não fazem parte do caminho de
  execução final — o programa que fala com hardware físico de verdade é
  `monitor_semaforo_hw.s`.

Todos os binários são Assembly ARM64 padrão (incluindo NEON), compilados e
executados diretamente na Raspberry Pi Zero 2W — não há emulador nem
toolchain cruzado no fluxo final (`Makefile`: `as`/`ld`/`ar`/`objdump`/`gdb`
nativos).

## 7. Fluxo de dados ponta a ponta

**Detecção → atuação (caminho crítico de segurança, só dentro da FPGA):**

```
sensor IR / botão  →  debounce  →  FSM  →  decoder  →  LEDs
```

**Configuração (ARM → FPGA, opcional):**

```
protocolo_serial_gpio.s (comando via mosi)  →  protocolo_serial.v  →  registrador de configuração  →  (só afeta o PRÓXIMO cálculo de tempo_min_efetivo)
```

**Telemetria / countdown (FPGA → ARM, somente leitura, hardware real):**

```
top_semaforo.v (fase_telemetria + nivel_fluxo + tempo_ate_pedestre)  →  protocolo_serial.v (byte miso)  →  protocolo_serial_gpio.s  →  monitor_semaforo_hw.s  →  "[t=Ns] ABERTO/FECHADO PARA O PEDESTRE"
```

(`monitor_semaforo.s`, a versão simulada sem hardware conectado, não
participa deste caminho — ela fabrica seu próprio byte de demonstração
em software, num formato mais simples que não é mais o que
`protocolo_serial.v` realmente transmite; ver seção 4.)

Note que a seta de telemetria nunca volta a influenciar a FSM — a
Raspberry Pi só observa. Isso é intencional: mesmo que o programa ARM
trave, tenha bug ou pare de rodar, o cruzamento continua funcionando com
segurança.

## 8. Estrutura de diretórios

```
<TPn>/ ou final_project/
├── rtl/            -> módulos Verilog (ver seção 3)
├── tb/             -> um testbench por módulo + tb_top_semaforo.v (integração)
├── constraints/    -> tangnano4k.cst (pinout físico da Tang Nano 4K)
├── asm/
│   ├── lib/         -> gpio_lib.s, strings_lib.s, buffer_lib.s, protocolo_serial_gpio.s (libembarcado.a)
│   ├── main_tp5.s    -> configuração + desempenho (simulado, sem hardware)
│   ├── monitor_semaforo.s    -> log de countdown simulado
│   ├── monitor_semaforo_hw.s -> log de countdown real (hardware físico)
│   └── (programas incrementais de cada TP, mantidos como histórico)
├── Makefile / README.md / Checklist_Rubricas.md
└── docs/evidencias/ -> logs reais de simulação e execução (nunca fabricados)
```

No `final_project/` especificamente, há ainda dois documentos que não
existem nas pastas de TP anteriores: `GUIA_MONTAGEM_HARDWARE.md` (passo a
passo de montagem física real) e `ARQUITETURA_FPGA_RASPBERRY.md` (por que
a FPGA não depende do ARM).

**Nota de correção:** uma versão anterior deste documento citava também
`Instrucoes_Hardware.md`, `Relatorio.docx`, `Mapeamento_Conexoes_Hardware.md`
e um diretório `master_src/` como "cópia fonte da verdade" propagada para
`TP5/`/`final_project/`. Nenhum desses quatro itens jamais existiu no
repositório (confirmado via `git log --all` — nenhum commit os criou). O
conteúdo que eles deveriam conter existe, só que em outro lugar: o guia
de montagem está em `GUIA_MONTAGEM_HARDWARE.md` (acima), o mapeamento de
pinos está nas seções 2/4 deste documento e no `.cst`, e não há cópia
"fonte" separada — cada pasta `TPn/`/`final_project/` é de fato
autocontida e editada diretamente.

## 9. Decisões de arquitetura — resumo

| Decisão | Alternativa considerada | Por que esta escolha |
|---|---|---|
| FSM na FPGA, não no ARM | Lógica de estado no software da Raspberry Pi | Determinismo de tempo real; a Raspberry Pi roda Linux (não é RTOS), não garante latência |
| Protocolo serial de 5 fios | Barramento paralelo (usado no TP3/TP4) | Menos fios, handshaking mais simples com `busy` dedicado (embora, na prática, o driver de hardware físico nem chegue a usar `busy` — o pulso é curto demais para o bit-bang ler, ver seção 4) |
| Bit-banging em GPIO genérico | Periférico SPI de hardware (GPIO8/9/10/11) | Protocolo customizado (tem `busy`, que SPI padrão não tem) |
| Sensor IR de saída digital direta | Sensor ultrassônico HC-SR04 | Opera nativamente em 3,3V, sem conversor de nível; `sensor_raw` já era genérico no RTL |
| BRAM + DSP para média móvel | Cálculo em software no ARM | Aproveita blocos dedicados da FPGA; mantém a decisão de tempo de verde 100% dentro da FPGA |
| Telemetria repropõe o byte existente | Aumentar o quadro serial para caber mais dados | Menor "raio de explosão" da mudança; não altera o protocolo de handshaking já validado |
| `prescaler.v` entre `clk` e a FSM (Entrega Final) | Deixar os tempos de fase em ciclos de clock puro | Sem divisor, um "tempo mínimo de verde" de 10 ciclos a 27 MHz dura ~370 ns — fisicamente inútil em bancada; o prescaler converte para segundos reais sem alterar a lógica da FSM |
| Botão de pedestre e reset nos botões onboard `S1`/`S2` da Tang Nano (Entrega Final) | Botão externo de protoboard com resistor de pull-down (usado até o TP5) | Elimina fiação e componente externo para esses dois sinais; os botões onboard já têm pull-up físico de ~100 kΩ e ficam em bancos elétricos compatíveis com 3,3V |

