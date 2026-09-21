# Semáforo Inteligente com Botão de Pedestre — Contexto e Funcionamento

> Projeto de Bloco: Sistemas Digitais Embarcados — Instituto Infnet
> Aluno: Lucas Gabriel de Oliveira Pordeus Campos | Professor: Dácio Moreira de Souza
> Desenvolvimento incremental: TP1 → TP2 → TP3 → TP4 → TP5 → Entrega Final

## 1. O que é o projeto

Um sistema embarcado híbrido que controla um cruzamento de trânsito com
travessia de pedestres sob demanda, dividido entre duas plataformas de
hardware que se comunicam entre si:

- **FPGA Tang Nano 4K** (chip GW1NSR-LV4C): executa toda a lógica com
  requisito de tempo real e segurança crítica — a máquina de estados do
  semáforo, a leitura dos sensores, o acionamento dos LEDs. Escrita em
  **Verilog**.
- **Raspberry Pi Zero 2W**: cuida da configuração de parâmetros, do
  pré-processamento numérico e da medição de desempenho da comunicação.
  Escrita em **Assembly ARM64 (AArch64)**.

A ideia central da arquitetura é: a FPGA nunca depende do ARM para
garantir segurança (o tempo mínimo de verde dos veículos nunca é
reduzido, mesmo sem nenhum comando chegar do ARM), e o ARM nunca precisa
lidar com temporização em nível de ciclo de clock — só manda comandos e
lê telemetria.

### Hardware físico usado

- FPGA Tang Nano 4K (Sipeed)
- Raspberry Pi Zero 2W
- Sensor de obstáculo reflexivo infravermelho (IR), saída digital direta
  em 3,3V — detecta veículos, ativo em nível **baixo** (tipo FC-51)
- Botão de pedestre: o botão tátil onboard `S1` da própria Tang Nano 4K
  (pino 14, pull-up interno de ~100 kΩ) — desde o bring-up físico não é
  mais um componente externo de protoboard (ver `final_project/GUIA_MONTAGEM_HARDWARE.md`)
- Reset manual: o segundo botão onboard `S2` da Tang Nano 4K (pino 15)
- 5 LEDs com resistor de 220 Ω cada: vermelho/amarelo/verde (veículos) +
  verde/vermelho (pedestre)
- Protoboard, jumpers, cabos USB-C e micro-USB

## 2. Por que o projeto é dividido em 6 entregas

O enunciado da disciplina pede uma construção **incremental**: cada TP
(Teste de Performance) adiciona uma camada nova sobre o TP anterior, sem
apagar nada do que já existia. A Entrega Final não cria nada novo — ela
apenas revisa, corrige e consolida tudo que foi validado no TP5.

| Etapa | O que entra de novo |
|---|---|
| **TP1** | Lógica combinacional básica: decodificador de estado → LEDs |
| **TP2** | Leitura de sensores reais: debounce, detecção de borda (sensor de veículo e botão de pedestre) |
| **TP3** | A máquina de estados (FSM) do semáforo + protocolo de comunicação paralelo ARM↔FPGA |
| **TP4** | Memória (histórico de veículos em BRAM) + aritmética (filtro de média móvel em DSP) |
| **TP5** | Protocolo de comunicação **serial** definitivo (substitui o paralelo) + Assembly organizado em biblioteca estática |
| **Entrega Final** | **Foi além do "só consolidação" originalmente previsto**: driver real de GPIO bit-banged (`protocolo_serial_gpio.s`), bring-up em hardware físico real (Tang Nano 4K + Raspberry Pi Zero 2W físicas), `prescaler.v` (tempo de fase em segundos reais), tempo de verde dinâmico por nível de fluxo, log de countdown real (`monitor_semaforo_hw.s`) — ver seção 7, itens 6–10, para os bugs que só apareceram nessa etapa |

Cada pasta (`TP1/` … `final_project/`) é **autocontida**: tem todo o
código acumulado até aquele ponto, não só a parte nova. Por isso o número
de arquivos cresce a cada etapa (TP1 tem 9 arquivos, TP5 tem 47,
`final_project` tem 78 — os dois últimos já contando as extensões pós-TP5:
tempo de verde dinâmico, telemetria de countdown, `prescaler.v`,
`protocolo_serial_gpio.s`, `GUIA_MONTAGEM_HARDWARE.md`,
`ARQUITETURA_FPGA_RASPBERRY.md` e os dois logs em tempo real
`monitor_semaforo.s`/`monitor_semaforo_hw.s`).

## 3. Como a FPGA funciona por dentro (Verilog)

Módulos em `rtl/`, cada um com seu testbench correspondente em `tb/`
(11 pares no total, todos com 100% dos casos de teste passando):

- **`estado_basico_decoder.v`** — combinacional puro: recebe um código de
  2 bits e acende o LED correspondente. É a base de tudo (TP1).
- **`debounce.v`** — filtro parametrizado que só aceita uma mudança de
  sinal depois que ela se mantém estável por N ciclos de clock, evitando
  falsos disparos por ruído elétrico (bouncing).
- **`sensor_veiculo.v`** / **`botao_pedestre.v`** — usam o debounce +
  detecção de borda de subida para transformar o sinal bruto do sensor/
  botão em um pulso de 1 ciclo ("veículo detectado" / "pedestre pediu
  travessia").
- **`contador_tempo.v`** — contador regressivo parametrizável, usado para
  cronometrar cada fase do semáforo (verde, amarelo, etc.).
- **`fsm_semaforo.v`** — o coração do projeto: uma máquina de estados de
  Moore com 3 estados (CARRO_VERDE → CARRO_AMARELO → PEDESTRE_VERDE →
  volta para CARRO_VERDE). Ela usa o `contador_tempo` internamente e
  garante que o pedestre só recebe o verde depois que o tempo mínimo de
  segurança dos veículos já passou.
- **`protocolo_paralelo.v`** (TP3) — versão inicial da comunicação
  ARM→FPGA: um barramento de 8 bits (opcode + valor) com sinais de
  strobe/ack.
- **`bram_historico.v`** (TP4) — um buffer circular de 256 posições
  implementado como memória síncrona, guardando o histórico das últimas
  passagens de veículos.
- **`media_movel_dsp.v`** (TP4) — calcula a média móvel das últimas 5
  amostras de fluxo de veículos usando aritmética de ponto fixo (Q16),
  de forma que a multiplicação seja sintetizada como um bloco DSP
  dedicado do chip, em vez de lógica genérica.
- **`protocolo_serial.v`** (TP5) — substitui o barramento paralelo por um
  protocolo serial estilo SPI, com 5 fios (`sclk`, `cs_n`, `mosi`,
  `miso`, `busy`), handshaking completo e telemetria de retorno.
- **`prescaler.v`** (Entrega Final, hardware físico) — divide o clock de
  27 MHz por um parâmetro (`DIVISOR_TICK`, 27\_000\_000 no hardware real,
  1 nos testbenches) para gerar `tick_fsm`, convertendo "N ciclos" em "N
  segundos reais". Sem esse módulo, os tempos de fase (5/10/20/3/15) duram
  frações de microssegundo em vez de segundos — ver seção 6.
- **`top_semaforo.v`** — o módulo de topo que integra todos os anteriores
  em um único sistema, com valores padrão de segurança aplicados
  automaticamente no reset.

## 4. Como o Raspberry Pi funciona por dentro (Assembly ARM64)

Os programas em `asm/` evoluem de scripts avulsos (TP1-TP4) para uma
**biblioteca estática reutilizável** no TP5/final:

- **`asm/lib/gpio_lib.s`** — mapeia e manipula os registradores GPIO
  físicos (todos os sinais do projeto passam por aqui).
- **`asm/lib/strings_lib.s`** — conversão de número inteiro para texto
  decimal (para imprimir resultados) e utilitário de tamanho de string.
- **`asm/lib/buffer_lib.s`** — um FIFO circular (fila) usado para simular
  o canal de telemetria vindo da FPGA (sem hardware físico conectado).
- **`asm/lib/protocolo_serial_gpio.s`** (Entrega Final, hardware físico) —
  o driver que de fato bate os pinos `sclk`/`cs_n`/`mosi`/`miso` via
  `/dev/gpiomem`, implementando o protocolo SPI-like em hardware real (não
  em buffer simulado). É este módulo que faz a Raspberry Pi conversar de
  verdade com a Tang Nano.

Essas **quatro** bibliotecas são compiladas e empacotadas em
`libembarcado.a` (um arquivo `.a`, como uma "biblioteca .lib/.so" do mundo
ARM; `LIB_OBJS` no `Makefile` confirma os quatro objetos). O programa
final, **`main_tp5.s`**, usa essa biblioteca para simular 2000 transações
de comunicação com a FPGA e medir throughput e latência reais usando o
relógio do sistema (`clock_gettime`). Também há um programa de teste
dedicado (`test_lib.s`) que verifica a própria biblioteca antes de ela
ser usada, e programas que exploram recursos avançados do ARM (operações
vetoriais NEON/SIMD, aritmética de 128 bits) mantidos como registro do
aprendizado incremental.

Extensão pós-TP5: existem **duas** versões do monitor de countdown, com
propósitos diferentes:

- **`asm/monitor_semaforo.s`** — versão **simulada**: monta seu próprio
  byte de telemetria em software (sem ler nada da FPGA de verdade) para
  demonstrar dois cenários fixos (tráfego baixo/alto) sem depender de
  hardware conectado. É o motivo pelo qual um bug real foi encontrado e
  corrigido em `strings_lib.s` (ver seção 7, item 5).
- **`asm/monitor_semaforo_hw.s`** — versão **real**, usa
  `protocolo_serial_gpio.s` para ler de verdade o byte de telemetria vindo
  da Tang Nano via GPIO bit-banged. Ver seção 6 para o porquê o formato do
  byte que ela decodifica é diferente do que `monitor_semaforo.s` simula.

## 5. Como as duas plataformas se comunicam

Esse é o ponto de integração entre RTL e Assembly, e evolui em duas
versões:

- **TP3/TP4 — Protocolo paralelo**: um byte de comando de uma vez
  (opcode nos 2 bits mais altos, valor nos 6 mais baixos), com sinais
  `strobe` (ARM avisa "tenho um comando pronto") e `ack` (FPGA confirma
  "recebi").
- **TP5/Final — Protocolo serial (definitivo)**: 5 fios só, todos em
  3,3V (não precisa de conversor de nível entre as duas placas):
  - `sclk` — clock da transferência, gerado pelo ARM
  - `cs_n` — chip-select / início-fim de quadro (nível baixo = ativo)
  - `mosi` — dados de comando, ARM → FPGA
  - `miso` — dados de telemetria, FPGA → ARM (fica em alta impedância
    quando `cs_n` está em nível alto)
  - `busy` — a FPGA pulsa esse sinal por 1 ciclo ao terminar de processar
    cada quadro, confirmando ao ARM que o comando foi aplicado. **Na
    prática, o driver de hardware físico (`protocolo_serial_gpio.s`) não
    usa esse sinal** — o pulso dura só ~37 ns a 27 MHz, curto demais para
    o software (rodando a dezenas de kHz de bit-bang) conseguir ler; o
    fio nem é conectado na montagem física (ver
    `final_project/GUIA_MONTAGEM_HARDWARE.md`).

Essa mudança de paralelo para serial reduz o número de fios físicos de
10 para 5 e é o motivo de a montagem de hardware do TP5/Final ser mais
simples que a do TP3/TP4 nesse ponto específico.

**Formato do byte de telemetria em `miso` — versão real, usada por
`top_semaforo.v`/`protocolo_serial.v` e decodificada por
`monitor_semaforo_hw.s`:**

- `[7:6] = fase_telemetria` — normalmente espelha `estado_carro`
  (00=vermelho/pedestre-verde, 01=amarelo, 10=verde), mas reaproveita o
  código `11` (nunca usado por `estado_carro`) para indicar especificamente
  "CARRO_VERDE com solicitação de pedestre pendente" — um jeito de
  diferenciar esse caso do "CARRO_VERDE sem pedido" sem gastar um bit
  extra no byte.
- `[5:4] = nivel_fluxo` (00=baixo, 01=médio, 10=alto).
- `[3:0] = tempo_ate_pedestre` truncado para 4 bits (0–15) — **não** é a
  contagem regressiva bruta da fase corrente (`contagem_atual`), é um
  valor derivado: durante `CARRO_VERDE` soma o tempo restante de verde
  **mais** o amarelo inteiro que ainda vai rodar; durante `CARRO_AMARELO`
  é só o tempo restante do amarelo; durante `PEDESTRE_VERDE` é `0`
  (o pedestre já pode atravessar). É essa combinação, não o countdown puro
  da FSM, que responde à pergunta que interessa para quem lê a telemetria:
  "quanto falta para o pedestre poder atravessar?". Em tráfego alto o
  valor real pode passar de 15 e saturar no byte (limitação só de exibição
  — a FSM interna não trunca nada).

**Importante — isto é diferente do formato usado até uma revisão anterior
deste documento** (`[7:6]=fase`, `[5:0]=contagem regressiva` de 6 bits,
sem `nivel_fluxo` empacotado): esse formato mais simples é o que
**`asm/monitor_semaforo.s`** (a versão *simulada*, sem hardware
conectado) ainda fabrica localmente para sua demonstração — ela nunca lê
a FPGA de verdade, então nunca precisou acompanhar a mudança de formato.
Só **`asm/monitor_semaforo_hw.s`**, que lê o byte real via
`protocolo_serial_gpio.s`, precisa (e consegue) decodificar o formato
atual — e o faz corretamente, extraindo só os 4 bits baixos
(`and x22, x0, #15`) como `tempo_ate_pedestre`.

## 6. Como funciona o cálculo de tempo do semáforo (sem trânsito e com trânsito)

O cálculo de tempo mora inteiro dentro de `fsm_semaforo.v`, que usa um
contador regressivo (`contador_tempo.v`): esse contador é carregado com
um valor e decrementa 1 por ciclo de clock até chegar a zero, e é esse
"chegar a zero" (`tempo_esgotado`) que dispara cada troca de fase. O
relógio de referência é o oscilador interno da própria Tang Nano 4K, de
27 MHz.

**Sem solicitação de pedestre**: o semáforo fica parado na fase
CARRO_VERDE indefinidamente. A transição para amarelo só acontece quando
**duas** condições são verdadeiras ao mesmo tempo — o tempo mínimo de
verde já esgotou *e* existe uma solicitação de pedestre pendente. Se não
há solicitação, mesmo com o contador zerado o sistema simplesmente
continua em verde. Essa é a regra de segurança (ONF-08) que a rubrica
exige: o fluxo de veículos nunca é interrompido à toa.

**Com solicitação de pedestre**: no momento em que o botão é pressionado,
e assim que o tempo mínimo de verde já tiver decorrido, a FSM avança pela
sequência CARRO_VERDE → CARRO_AMARELO → PEDESTRE_VERDE → volta pra
CARRO_VERDE, e cada uma dessas três fases tem sua própria duração
carregada no contador: o valor de verde vem do registrador
`tempo_min_reg`, o de amarelo vem de `tempo_amarelo_reg`, e o do
pedestre é fixo em 15 ciclos no código atual. Os valores padrão de
fábrica (aplicados automaticamente no reset, antes de qualquer comando
chegar do ARM) são: verde = 10 ciclos, amarelo = 3 ciclos, pedestre = 15
ciclos.

Já o trânsito de **veículos** (fluxo, não pedestre) é medido separadamente
por `bram_historico.v` + `media_movel_dsp.v`. A cada janela de tempo
(`JANELA_AMOSTRAGEM` ciclos), conta-se quantos veículos o sensor detectou
naquela janela; essa contagem entra numa janela deslizante das últimas 5
amostras, o módulo calcula a média (por multiplicação em ponto fixo, não
divisão, pra caber num bloco DSP) e compara o resultado com dois
limiares configuráveis (`limiar_baixo` e `limiar_alto`) pra classificar o
fluxo em baixo, médio ou alto. **Os valores de fábrica atuais são
`limiar_baixo=0` e `limiar_alto=1`** — bem mais sensíveis do que os `3`/`8`
citados numa revisão anterior deste documento; o próprio RTL
(`top_semaforo.v`) comenta que `3`/`8` seriam valores de produção mais
realistas (exigindo trânsito sustentado para virar "alto"), mas foram
reduzidos de propósito para facilitar demonstração manual — basta pouco
mais de 1 detecção por janela para o sistema já classificar como "alto".

### Como a FPGA sabe se o trânsito está pesado (passo a passo)

A validação passa por uma cadeia de 4 estágios, cada um implementado num
módulo Verilog diferente, e é puramente sobre **frequência de
detecções**, não velocidade ou distância — o sensor IR só diz "tem
alguma coisa passando agora" (nível alto quando o par emissor/receptor
infravermelho detecta um obstáculo refletindo o feixe), cabe ao resto da
cadeia transformar isso numa taxa:

1. **Filtragem do sinal bruto (`debounce.v`)**: o sensor IR entrega um
   sinal elétrico bruto (`sensor_raw`, já em 3,3V, sem conversor de nível)
   que pode ter ruído — uma variação rápida e espúria de tensão que não é
   um veículo de verdade. O debounce só aceita uma mudança de estado
   depois que ela se mantém estável por 8 ciclos de clock seguidos;
   qualquer "tremulação" mais curta que isso é ignorada.
2. **Detecção de evento (`sensor_veiculo.v`)**: a partir do sinal já
   filtrado, esse módulo detecta a borda de subida (o momento exato em
   que o sinal vai de "nada" pra "objeto detectado") e gera um pulso de
   exatamente 1 ciclo de clock — `veiculo_pulso`. Isso transforma "o
   sensor está vendo algo" em um evento discreto e contável: "passou 1
   veículo agora".
3. **Contagem por janela de tempo (dentro de `top_semaforo.v`, bloco
   adicionado nesta extensão)**: aqui é onde a taxa de trânsito é de
   fato medida. Existe um contador de ciclos que define uma "janela de
   amostragem" (`JANELA_AMOSTRAGEM`, 200 ciclos por padrão); durante
   essa janela, cada `veiculo_pulso` que aparece incrementa um contador
   interno. Quando a janela fecha, esse total (quantos veículos passaram
   naqueles 200 ciclos) vira uma "amostra" entregue ao próximo estágio, e
   o contador zera para começar a próxima janela. É essa contagem por
   janela — não um pulso isolado — que representa a intensidade do
   trânsito.
4. **Média móvel e classificação (`media_movel_dsp.v`)**: as últimas 5
   amostras (5 janelas) ficam guardadas numa fila; a cada nova amostra, o
   módulo soma as 5 e calcula a média (por multiplicação em ponto fixo,
   pra caber num bloco DSP em vez de fazer uma divisão cara). Essa média
   entra numa comparação simples de dois limiares configuráveis: menor
   ou igual a `limiar_baixo` (padrão **0**) → baixo; entre `limiar_baixo`
   e `limiar_alto` (padrão **1**) → médio; acima de `limiar_alto` → alto. O
   resultado (`nivel_fluxo`, um número de 2 bits) alimenta tanto a
   telemetria enviada pro ARM quanto o cálculo do tempo de verde
   dinâmico.

Em tese, o design existe para que a "certeza" de trânsito pesado venha de
detecções repetidas ao longo de várias janelas, não de um único veículo
isolado — é por isso que o teste de integração (`tb_top_semaforo.v`)
gera um burst real de 50 veículos ao longo de ~5 janelas de amostragem,
em vez de forçar `nivel_fluxo` artificialmente. **Ressalva sobre os
limiares atuais (ver acima):** com `limiar_alto=1` (reduzido para
demonstração), essa margem de segurança praticamente desaparece na
prática — bastam **duas** detecções dentro de uma **única** janela de
`JANELA_AMOSTRAGEM` ciclos para já classificar o fluxo como "alto"; o
burst de 50 veículos do teste satura o limiar já na primeira janela, bem
antes de completar as ~5 planejadas. Com os limiares de referência (3/8,
comentados no RTL como valor de produção), a margem contra picos
passageiros seria maior.

**Atualização: isso agora realmente muda o tempo de verde**, numa
extensão feita depois da entrega do TP5. Antes, o nível de fluxo era só
calculado e enviado por telemetria pro Raspberry Pi (`miso`), sem afetar
nenhum tempo — era o ARM quem teria que decidir mudar o tempo, e essa
decisão nunca foi implementada. Agora `top_semaforo.v` ajusta o tempo
mínimo de verde **sozinho, dentro da própria FPGA**, direto a partir do
`nivel_fluxo` medido:

| Nível de fluxo | Tempo de verde efetivo | Com o padrão (10 ciclos) |
|---|---|---|
| Baixo (sem trânsito ou trânsito leve) | metade do valor de referência, com piso de 3 ciclos | 5 ciclos |
| Médio | igual ao valor de referência | 10 ciclos |
| Alto | dobro do valor de referência, com teto de 63 ciclos | 20 ciclos |

Ou seja: sem trânsito (ou com trânsito leve), o pedestre é liberado mais
rápido; com trânsito pesado, os veículos escoam por mais tempo antes do
pedestre poder atravessar — exatamente o comportamento que faz sentido
num cruzamento real. Isso foi validado com um teste que gera um burst
real de 50 veículos (não um valor artificialmente forçado) até
`nivel_fluxo` virar "alto" de verdade, e então compara o tempo até a
liberação do pedestre nos dois cenários (`tb_top_semaforo.v`, casos 4 e
5 — trânsito baixo mede 11 ciclos até a liberação, trânsito alto mede 14,
confirmando que o alto realmente demora mais).

Um detalhe interessante descoberto ao validar isso: o contador só é
recarregado com um novo tempo no instante em que a FSM *entra* numa fase
nova, não a cada ciclo enquanto já está nela. Isso significa que o nível
de fluxo que importa é o medido no momento em que o semáforo entra em
verde — se o trânsito mudar no meio da fase, isso só afeta a duração da
*próxima* vez que o semáforo abrir para os carros, não a fase em
andamento. É um comportamento razoável (evita que o contador fique
instável reiniciando o tempo todo), mas exige um pouco de cuidado ao
testar (e ao explicar): não adianta gerar trânsito pesado e apertar o
botão na mesma fase de verde que já começou antes — o efeito só aparece
na fase seguinte.

Também foi corrigido, junto com essa extensão, um problema real herdado
do TP4/TP5: a amostra enviada ao filtro de média móvel estava fixa em 1
por veículo detectado — com uma janela de 5 amostras de no máximo 1, a
média nunca conseguia passar de ~1, então `nivel_fluxo` na prática jamais
saía de "baixo" na integração completa, não importava quantos veículos
passassem. A correção foi trocar essa amostra fixa pela contagem real de
veículos detectados dentro de cada janela de tempo, refletindo uma taxa
de trânsito de verdade em vez de um pulso constante.

**Atualização (Entrega Final, hardware físico): o prescaler já existe e
está em produção.** Uma revisão anterior deste documento descrevia esse
ponto como uma lacuna futura — dizia que "seria necessário inserir um
estágio de prescaler... e isso ainda não está no RTL atual". Isso deixou
de ser verdade: `rtl/prescaler.v` existe, é instanciado em
`top_semaforo.v` (`u_prescaler`) e gera o sinal `tick_fsm` que governa
tanto a FSM quanto a janela de amostragem de tráfego. Ele divide o clock
de 27 MHz por um parâmetro `DIVISOR_TICK` — `27_000_000` no hardware
físico real (1 tick = 1 segundo real) e `1` nos testbenches (1 tick =
1 ciclo, para simular rápido). Ou seja, os valores 5/10/20 (verde), 3
(amarelo) e 15 (pedestre) já representam **segundos reais** no hardware
físico atual, não mais ciclos de clock brutos — essa conversão passou a
existir dentro do próprio RTL, não é apenas uma rotulagem feita do lado
do log em Assembly (ver a ressalva equivalente que isso corrige logo
abaixo, na seção do `monitor_semaforo.s`).

Essa extensão do prescaler foi, na verdade, motivada por um bug real
descoberto no bring-up físico: com `JANELA_AMOSTRAGEM` original (200
ciclos) contada a 27 MHz sem nenhum divisor, a janela de amostragem de
tráfego fechava em ~7,4 µs — fisicamente impossível de registrar um
aceno de mão passando na frente do sensor. O `prescaler.v` resolveu os
dois problemas de uma vez: tempos de fase em segundos reais **e** uma
janela de amostragem que um ser humano consegue de fato acionar (ver
seção 7, item 9, para o restante dos bugs encontrados só no hardware
físico).

### Log em tempo real do countdown na Raspberry Pi (extensão pós-TP5)

Além do tempo de verde ser dinâmico (acima), a Raspberry Pi mostra, em
tempo real, o que está acontecendo no semáforo — pra tornar visível na
prática o que a FPGA está decidindo internamente. Existem **duas**
versões desse log, com formatos de byte diferentes (ver seção 5 para o
porquê):

**`asm/monitor_semaforo.s` (versão simulada, sem hardware conectado):**

1. A cada "tick" (1 segundo real, via `nanosleep`), monta **localmente**,
   em software, um byte no formato simplificado `[7:6]=fase`
   `[5:0]=contagem regressiva` — este programa nunca fala com uma Tang
   Nano de verdade, então usa um formato próprio, mais simples que o que a
   FPGA realmente transmite hoje.
2. "Transmite" esse byte através do buffer circular de `buffer_lib.s`
   (`cbuf_push`/`cbuf_pop`) — simula o link serial sclk/mosi/miso do
   mesmo jeito que `main_tp5.s` já fazia para medir desempenho.
3. Decodifica o byte de volta (fase + contagem) e imprime uma linha como:
   `[t=42s] Sinal dos CARROS: VERDE -> fecha em 1s`.
4. Dorme 1 segundo real antes do próximo tick — por isso é "tempo real"
   e não uma simulação instantânea. No fim, o tempo total decorrido é
   medido de verdade com `clock_gettime` e comparado com o esperado.

Demonstra os dois cenários já validados em `tb_top_semaforo.v`: primeiro
um ciclo completo com trânsito BAIXO (verde fecha em 5s, amarelo em 3s,
pedestre abre e fecha em 15s), depois um ciclo com trânsito ALTO (verde
leva 20s pra fechar). Log real: `docs/evidencias/*_monitor_semaforo_run.txt`.

**`asm/monitor_semaforo_hw.s` (versão real, com hardware conectado) —
mais recente, não fabrica nada:**

Usa `protocolo_serial_gpio.s` para bater os pinos GPIO de verdade e ler o
byte de telemetria **real** que sai do pino `miso` da Tang Nano. Extrai
só os 4 bits baixos (`tempo_ate_pedestre`, formato real da seção 5) e
imprime `[t=Ns] ABERTO PARA O PEDESTRE` ou `[t=Ns] FECHADO PARA PEDESTRE`
a cada segundo, por 20 segundos, terminando sozinho. Se rodado sem uma
Tang Nano conectada (ou sem `sudo`, necessário para abrir
`/dev/gpiomem`), cai automaticamente em modo simulado com telemetria
zerada, em vez de travar — é assim que se distingue "lendo hardware de
verdade" de "não conectado direito". Ver
`final_project/GUIA_MONTAGEM_HARDWARE.md` seção 6 para o passo a passo de
como rodar.

Em ambos os casos, os valores de tempo (5/10/20/3/15) já representam
segundos reais graças ao `prescaler.v` (ver acima) — essa conversão
acontece dentro do próprio RTL no hardware físico, não é mais só uma
rotulagem do lado do log em Assembly.

**E a Raspberry Pi participa da decisão?** Não, e é proposital: a decisão
de quanto tempo o sinal fica aberto é tomada inteiramente dentro da FPGA
(tabela acima) — a Raspberry Pi só **lê** o resultado pela telemetria e o
exibe. Isso preserva a mesma divisão de responsabilidades do projeto
inteiro: a FPGA garante a segurança e o tempo real (nunca depende do ARM
para isso), e o ARM cuida de configuração/visualização, nunca de
temporização crítica. Se a Raspberry Pi travar, atrasar ou for desligada,
o semáforo continua funcionando exatamente igual — só o log deixa de
aparecer.

## 7. Bugs reais encontrados e corrigidos (não é só "funcionou de primeira")

Documentados nos relatórios porque mostram domínio técnico real do
sistema:

1. **TP3 — duração errada de fase na FSM**: ao trocar de estado, o
   contador era recarregado com a duração do estado *atual* em vez do
   estado *de destino*, fazendo cada fase durar um ciclo a menos que o
   configurado. Corrigido calculando o valor do contador a partir do
   *próximo* estado, com uma flag extra garantindo a primeira carga
   correta depois do reset.
2. **TP4 — atraso de 1 ciclo e arredondamento errado no filtro de média
   móvel**: o cálculo usava o valor antigo do acumulador (resolvido com
   um sinal combinacional auxiliar) e truncava sempre para baixo em vez
   de arredondar (resolvido somando meio bit de correção antes do
   deslocamento final).
3. **TP5 — falso negativo de metodologia de teste**: o testbench de
   integração esperava 200 ciclos antes de checar o LED de pedestre, mas
   com os tempos de teste usados a fase inteira de pedestre durava só
   ~16 ciclos — ou seja, o sistema já tinha completado o ciclo todo e
   voltado sozinho para carro verde (comportamento correto!) quando o
   teste finalmente checava. Não era bug de hardware, era o teste que
   estava mal calibrado. Corrigido ajustando o tempo de espera do
   próprio testbench.
4. **Pós-TP5 — amostra de tráfego fixa mascarava o nível de fluxo real**:
   ao implementar o tempo de verde dinâmico, ficou evidente que a
   integração enviava sempre "1" como amostra para o filtro de média
   móvel a cada veículo, herdado do TP4. Com uma janela de 5 amostras de
   no máximo 1, a média nunca ultrapassava ~1, então `nivel_fluxo` jamais
   saía de "baixo" na prática, não importava quanto trânsito houvesse —
   um bug silencioso que não tinha sido percebido porque, até então,
   nada dependia de fato do valor de `nivel_fluxo`. Corrigido substituindo
   a amostra fixa pela contagem real de veículos detectados dentro de
   cada janela de tempo.
5. **Pós-TP5 — `uint_to_dec` corrompia o próprio endereço de retorno para
   números grandes**: ao imprimir o tempo real total decorrido no log de
   countdown (um número de 11 dígitos, ~61 bilhões de nanossegundos), o
   programa simplesmente saía do trilho depois de imprimir a primeira
   linha. Investigando: `uint_to_dec` (em `strings_lib.s`) tinha dois
   problemas nunca antes expostos porque nenhuma chamada anterior
   imprimia um número tão grande. Primeiro, ela truncava o valor de
   entrada para 32 bits (usava `w0`/`w2` em vez de `x0`/`x2`) — qualquer
   valor acima de ~4,29 bilhões já vinha errado. Segundo, e mais grave: a
   pilha local de dígitos era escrita a partir de `[sp+0]`, exatamente o
   mesmo endereço onde a função tinha acabado de salvar seu próprio
   `x30` (endereço de retorno) em `[sp+8..+15]` — qualquer número com 9
   dígitos ou mais sobrescrevia esses bytes, e o `ret` no final da função
   saltava para um endereço de lixo (por coincidência, um endereço válido
   o suficiente pra continuar executando código, só que a partir do meio
   de `roda_fase` com registradores igualmente corrompidos, o que
   explicava o log continuar imprimindo linhas sem sentido em vez de
   travar direto). Corrigido usando registradores de 64 bits inteiros na
   função e deslocando a pilha de dígitos para `[sp+16]`, bem longe da
   área onde `x29`/`x30` ficam salvos. Como `strings_lib.s` é parte de
   `libembarcado.a`, usada também por `main_tp5.s`, o teste de regressão
   completo (`test_lib`, `main_tp5`, `monitor_semaforo`) foi refeito após
   a correção para confirmar que nada quebrou.

Os itens acima (1–5) foram todos encontrados **em simulação**, antes de
qualquer hardware físico estar conectado. Depois do TP5, o protótipo foi
efetivamente ligado a uma Tang Nano 4K e uma Raspberry Pi Zero 2W físicas
— e isso expôs mais cinco problemas que só aparecem em bancada, nunca em
simulação:

6. **Oscilador no pino errado.** O `.cst` usava o pino 27 para `clk`, que
   nunca foi o oscilador de 27 MHz real da Tang Nano 4K — causa raiz de o
   sistema nunca sair do estado inicial em bancada, com ou sem botão.
   Corrigido para o pino 45, confirmado no exemplo oficial da Sipeed
   (`github.com/sipeed/TangNano-4K-example`, projeto `key_blink`).
7. **Conflito de banco de tensão em `rst_n`.** O pino usado antes para
   `rst_n` caía num banco elétrico travado em 1,8V, incompatível com o
   padrão 3,3V do restante do projeto (erro de síntese `CT1136` no Gowin
   EDA). Hoje `rst_n` está fixado no pino 15 — o botão onboard `S2` da
   própria Tang Nano, que já tem pull-up físico e opera no banco de
   tensão correto.
8. **Polaridade de sensor e botão invertida.** O sensor IR (tipo FC-51) e
   o botão de pedestre físicos usados são ativos em nível **baixo**
   (repouso alto, evento baixo), mas o RTL original assumia nível alto.
   Corrigido invertendo os sinais (`~sensor_raw`, `~botao_raw`) nos
   pontos de instanciação em `top_semaforo.v` — ver seção 3 (nota sobre
   `prescaler.v`) e a nova lista de hardware físico no topo deste
   documento.
9. **Janela de amostragem de tráfego contada em ciclos de clock puro.**
   Já detalhado acima: com `JANELA_AMOSTRAGEM` original (200 ciclos)
   contada a 27 MHz sem divisor, a janela fechava em ~7,4 µs —
   fisicamente impossível de registrar um aceno de mão. Corrigido
   introduzindo `rtl/prescaler.v` e recontando a janela em ticks reais em
   vez de ciclos brutos.
10. **Telemetria instável na protoboard.** O byte de telemetria lido via
    `protocolo_serial_gpio.s` oscilava de forma inconsistente mesmo com
    fiação, GND e banco de tensão corretos — diagnosticado como
    ringing/crosstalk de sinal em fios soltos de protoboard na frequência
    original de bit-bang (~1–2 MHz). Corrigido aumentando o atraso entre
    transições de pino (`ATRASO_ITER`: 200 → 20000 iterações), reduzindo
    `sclk` para a faixa de ~10–20 kHz.

## 8. Verificação real

Todo o código foi de fato compilado/simulado e executado neste ambiente,
não apenas escrito:

- **Verilog**: simulado com **Icarus Verilog** (`iverilog`/`vvp`), com
  formas de onda (`.vcd`) geradas e analisáveis em **GTKWave**.
- **Assembly ARM64**: montado, linkado e executado diretamente na
  Raspberry Pi (toolchain nativo `as`/`ld`/`objdump`/`ar`/`gdb`, sem
  necessidade de emulador — o binário compilado para AArch64 já é o
  binário que roda na placa).
- Todos os logs dessas execuções estão salvos em
  `docs/evidencias/` dentro de cada pasta, e crescem a cada etapa (9
  arquivos no TP5, **34** no `final_project`, porque acumula tudo —
  incluindo a evidência real do teste de tempo de verde dinâmico e da
  telemetria de countdown, e o log real de `monitor_semaforo.s`/
  `monitor_semaforo_hw.s`, todos adicionados depois do TP5). `prescaler.v`
  não tem testbench próprio — é validado indiretamente dentro de
  `tb_top_semaforo.v`.

## 9. Estrutura de cada pasta de entrega

```
TPn/ (ou final_project/)
├── rtl/                    -> módulos Verilog (acumulados até esta etapa)
├── tb/                     -> testbenches correspondentes
├── asm/                    -> programas Assembly ARM64 (e lib/ a partir do TP5)
├── constraints/            -> arquivo .cst com o mapeamento de pinos da Tang Nano 4K
├── docs/evidencias/        -> logs reais de simulação/execução + waveforms .vcd
├── Makefile                -> automatiza simulação, compilação e execução
├── README.md               -> objetivo da etapa + como rodar tudo
├── Checklist_Rubricas.md   -> cada critério da rubrica ligado ao arquivo/seção que o atende
├── GUIA_MONTAGEM_HARDWARE.md        -> (só no final_project/) passo a passo de montagem física real
└── ARQUITETURA_FPGA_RASPBERRY.md    -> (só no final_project/) por que a FPGA não depende do ARM
```

## 10. Como rodar o projeto

Dentro de qualquer pasta `TPn/` ou `final_project/`:

```bash
make sim        # roda todos os testbenches Verilog (Icarus Verilog)
make lib        # monta a biblioteca libembarcado.a (a partir do TP5)
make asm        # monta os programas Assembly
make run-asm    # executa os binários nativamente na Raspberry Pi
```

Para gravar de fato na FPGA física, o fluxo é: abrir o **Gowin EDA**,
criar um projeto para o device `GW1NSR-LV4C QFN48P`, adicionar todos os
arquivos de `rtl/` (o Gowin resolve a hierarquia sozinho a partir de
`top_semaforo.v`), adicionar o `constraints/tangnano4k.cst`, e rodar
Synthesize → Place & Route → Program Device.

## 11. Onde acompanhar/validar cada critério de nota

O arquivo `Checklist_Rubricas.md` de cada pasta é o mapa direto entre
"o que o professor vai avaliar" e "onde isso está implementado" — vale a
pena abrir ele primeiro ao revisar qualquer etapa, porque cada item da
rubrica está com o caminho exato do arquivo (ou seção do relatório) que o
comprova.
