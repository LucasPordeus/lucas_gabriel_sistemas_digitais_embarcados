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

```

## 2. Camadas do sistema

| Camada | Onde vive | Responsabilidade |
|---|---|---|
| Hardware físico | Protoboard, sensor IR, botão, LEDs | Entradas/saídas do mundo real |
| RTL (FPGA) | `rtl/*.v` | Toda a lógica de controle e segurança, em tempo real determinístico |
| Protocolo de comunicação | `rtl/protocolo_serial.v` + `asm/lib/gpio_lib.s`/`buffer_lib.s` | Ponte síncrona ARM↔FPGA, sem depender de tensão/velocidade diferentes |
| Software ARM64 | `asm/*.s` na Raspberry Pi | Configuração, telemetria, testes de desempenho, log em tempo real |

## 3. Camada RTL (FPGA) — `rtl/top_semaforo.v` como módulo de topo

`top_semaforo.v` integra sete sub-blocos. Cada um tem uma responsabilidade
única e é testado isoladamente antes da integração (ver `tb/`, 11
conjuntos de testbenches, 100% passando):

```
sensor_raw ──► debounce.v ──► sensor_veiculo.v ──┐
                                                    │ veiculo_pulso
botao_raw  ──► debounce.v ──► botao_pedestre.v ───┼──────────────┐
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
                                                                    ▼
                                                          protocolo_serial.v ◄──► sclk/cs_n/mosi/miso/busy (Raspberry Pi)
```

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
(ver `Instrucoes_Hardware.md`, síntese no Gowin EDA). O resultado é
`nivel_fluxo` (baixo/médio/alto), usado só internamente — **nunca** chega
a decidir nada por si só; ele apenas ajusta um parâmetro que a FSM usa.

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

## 4. Camada de comunicação: protocolo serial ARM↔FPGA

5 sinais, todos a 3,3V (sem conversor de nível entre as placas):

| Sinal | Direção | Função |
|---|---|---|
| `sclk` | RPi → FPGA | clock serial da transferência |
| `cs_n` | RPi → FPGA | chip-select / handshake de início-fim de quadro (ativo em nível baixo) |
| `mosi` | RPi → FPGA | byte de comando (ARM configura a FPGA) |
| `miso` | FPGA → RPi | byte de telemetria (alta impedância quando `cs_n=1`) |
| `busy` | FPGA → RPi | pulsa 1 ciclo de `clk` ao final de cada quadro de 8 bits |

**Formato do comando** (`mosi`, MSB primeiro): `[7:6]=opcode` `[5:0]=valor`,
com 4 opcodes (`OP_TEMPO_MIN`, `OP_TEMPO_AMARELO`, `OP_LIMIAR_BAIXO`,
`OP_LIMIAR_ALTO`) — o ARM só ajusta parâmetros, nunca estados.

**Formato da telemetria** (`miso`, MSB primeiro) — atualizado na extensão
pós-TP5 especificamente para viabilizar o log de countdown:
`[7:6]=fase_carro_atual` (espelha `estado_carro` da FSM) `[5:0]=contagem_
regressiva` (0-63 ciclos restantes na fase corrente). Antes dessa
extensão, esse byte carregava `nivel_fluxo` + um ponteiro da BRAM — essa
informação continua existindo e sendo testada internamente, só deixou de
ser duplicada na telemetria, porque um único byte não cabia as duas
coisas ao mesmo tempo. Validado em `tb_top_semaforo.v` (caso 6), lendo o
byte real via `sclk`/`mosi`/`miso`, não apenas os sinais internos.

Esse protocolo foi escolhido no lugar de barramento paralelo (usado nos
TP3/TP4) porque reduz de ~10 fios para 5, elimina a necessidade de
sinalização `strobe`/`ack` separada (o `busy` já cumpre esse papel) e é o
padrão mais natural para uma interface ARM↔FPGA de baixa velocidade sem
DMA — mesmo não sendo SPI de hardware "de livro" (ver seção 6.2).

## 5. Por que a FPGA nunca depende do ARM (segurança)

No reset (`rst_n=0`), `top_semaforo.v` carrega valores padrão de
segurança nos registradores de configuração (`tempo_min_reg=10`,
`tempo_amarelo_reg=3`, `limiar_baixo_reg=3`, `limiar_alto_reg=8`) — **antes**
de qualquer comando chegar via protocolo serial. Isso significa que o
semáforo funciona corretamente mesmo se a Raspberry Pi nunca enviar um
único comando, ou se o link serial cair no meio da operação. É o
requisito de segurança do cruzamento (ONF-08): o tempo mínimo de verde dos
veículos nunca cai abaixo de um piso, mesmo com pedestre esperando e
trânsito baixo — essa garantia vive inteiramente dentro da FPGA.

## 6. Camada de software ARM64 (Raspberry Pi)

### 6.1 Biblioteca estática — `asm/lib/libembarcado.a`

Três módulos, montados uma vez e reaproveitados por todos os programas:

- **`gpio_lib.s`**: acesso a `/dev/gpiomem` (mapeamento real de registradores
  GPIO do BCM2710A1) com `gpio_map_init`/`gpio_set_bit`/`gpio_clear_bit`/
  `gpio_read_bit` — qualquer GPIO de uso geral serve, já que o protocolo
  não usa o periférico SPI de hardware da Raspberry Pi (ver seção 6.2).
- **`strings_lib.s`**: conversão de inteiro para decimal (`uint_to_dec`) e
  utilitários de string, usados para montar as linhas de log impressas
  via syscall `write()` (sem libc).
- **`buffer_lib.s`**: um buffer circular FIFO (`cbuf_push`/`cbuf_pop`) que
  simula, em software, o comportamento de round-trip do link serial —
  usado tanto no teste de desempenho (`main_tp5.s`) quanto no log de
  countdown (`monitor_semaforo.s`).

### 6.2 Por que bit-banging em vez do periférico SPI de hardware

A Raspberry Pi tem dois controladores SPI dedicados (SPI0: GPIO8/9/10/11;
SPI1: GPIO18/19/20/21), mas o protocolo deste projeto **não** os usa. O
`protocolo_serial.v` da FPGA é customizado (tem um sinal `busy` que o SPI
padrão não tem), então `gpio_lib.s` manipula GPIOs de uso geral
diretamente ("bit-banging"), com a temporização controlada em software —
por isso qualquer GPIO livre do header de 40 pinos serve para `sclk`/
`cs_n`/`mosi`/`miso`/`busy` (ver `Mapeamento_Conexoes_Hardware.md` para o
mapeamento físico sugerido).

### 6.3 Programas principais

- **`main_tp5.s`**: programa final de configuração + teste de desempenho —
  usa macros para enviar comandos e ler telemetria via o buffer circular,
  mede throughput/latência com `clock_gettime`/`nanosleep` (syscalls puros,
  sem libc).
- **`monitor_semaforo.s`** (extensão pós-TP5): lê a telemetria (fase +
  contagem regressiva) a cada segundo real e imprime o countdown até os
  sinais dos carros/pedestre fecharem, para cenários de trânsito baixo e
  alto — é o programa que produz o "log em tempo real" pedido no projeto.
- **`test_lib.s`**: harness de verificação da própria biblioteca
  (equivalente a um testbench, mas para o código ARM).
- Os programas de cada TP anterior (`tp1_fluxo_basico.s` … `tp4_neon_simd.s`,
  `gpio_map.s`) ficam mantidos como registro do desenvolvimento
  incremental exigido pelo enunciado, mas não fazem parte do caminho de
  execução final — o programa principal é `main_tp5.s` (mais
  `monitor_semaforo.s` como extensão).

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
main_tp5.s (comando)  →  mosi  →  protocolo_serial.v  →  registrador de configuração  →  (só afeta o PRÓXIMO cálculo de tempo_min_efetivo)
```

**Telemetria / countdown (FPGA → ARM, somente leitura):**

```
fsm_semaforo.v (fase + contagem_atual)  →  protocolo_serial.v (byte miso)  →  monitor_semaforo.s  →  linha de log "[t=Ns] Sinal dos CARROS: VERDE -> fecha em Ns"
```

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
│   ├── lib/         -> gpio_lib.s, strings_lib.s, buffer_lib.s (libembarcado.a)
│   ├── main_tp5.s    -> programa principal (configuração + desempenho)
│   ├── monitor_semaforo.s -> log em tempo real do countdown
│   └── (programas incrementais de cada TP, mantidos como histórico)
├── Makefile / README.md / Instrucoes_Hardware.md / Checklist_Rubricas.md / Relatorio.docx
└── docs/evidencias/ -> logs reais de simulação e execução (nunca fabricados)
```

`master_src/` é a cópia "fonte da verdade": toda alteração é feita ali
primeiro e depois propagada para `TP5/` e `final_project/`, para manter
as três cópias consistentes.

## 9. Decisões de arquitetura — resumo

| Decisão | Alternativa considerada | Por que esta escolha |
|---|---|---|
| FSM na FPGA, não no ARM | Lógica de estado no software da Raspberry Pi | Determinismo de tempo real; a Raspberry Pi roda Linux (não é RTOS), não garante latência |
| Protocolo serial de 5 fios | Barramento paralelo (usado no TP3/TP4) | Menos fios, handshaking mais simples com `busy` dedicado |
| Bit-banging em GPIO genérico | Periférico SPI de hardware (GPIO8/9/10/11) | Protocolo customizado (tem `busy`, que SPI padrão não tem) |
| Sensor IR de saída digital direta | Sensor ultrassônico HC-SR04 | Opera nativamente em 3,3V, sem conversor de nível; `sensor_raw` já era genérico no RTL |
| BRAM + DSP para média móvel | Cálculo em software no ARM | Aproveita blocos dedicados da FPGA; mantém a decisão de tempo de verde 100% dentro da FPGA |
| Telemetria repropõe o byte existente | Aumentar o quadro serial para caber mais dados | Menor "raio de explosão" da mudança; não altera o protocolo de handshaking já validado |

