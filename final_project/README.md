# Semáforo Inteligente com Botão de Pedestre — Tang Nano 4K + Raspberry Pi

Cruzamento com travessia de pedestres sob demanda. Por padrão o sinal fica
**verde para os carros**. O pedestre aperta um botão para pedir a travessia.
A FPGA mede o fluxo de veículos com um sensor IR: com **fluxo baixo** o
pedestre é liberado mais rápido; com **fluxo alto** ele espera mais.

- **FPGA (Tang Nano 4K, GW1NSR-LV4C):** lê botão e sensor, decide as fases e
  acende os LEDs. Funciona sozinha.
- **Raspberry Pi Zero 2W (Assembly ARM64):** **apenas monitora**. Lê a
  telemetria da FPGA uma vez por segundo e imprime o estado. Não envia nenhum
  comando nem configura nada.

## Estrutura

```
final_project/
├── rtl/                  módulos Verilog (topo: top_semaforo.v)
├── tb/                   um testbench por módulo
├── constraints/
│   ├── tangnano4k.cst    pinagem
│   └── tangnano4k.sdc    clock de 27 MHz
├── asm/
│   ├── monitor_semaforo.s           programa da Raspberry Pi
│   └── lib/                         gpio_lib, protocolo_serial_gpio, telemetria, strings_lib
├── docs/evidencias/      logs de simulação, síntese e montagem
├── GUIA_MONTAGEM_HARDWARE.md        fiação e roteiro de teste na placa
└── Makefile
```

## Comportamento

| Fase | Carros | Pedestre | Duração | Sai quando |
|---|---|---|---|---|
| CARRO_VERDE | verde | vermelho | indefinida | há pedido **e** o tempo de verde acabou |
| CARRO_AMARELO | amarelo | vermelho | 3 s | o tempo acaba |
| PEDESTRE_VERDE | vermelho | verde | 15 s | o tempo acaba (o pedido é apagado) |

Tempo de verde dos carros, conforme o fluxo medido:

| Fluxo (média de veículos por janela de 10 s, últimas 5 janelas) | Tempo de verde |
|---|---|
| Baixo (≤ 1) | 5 s |
| Médio (2 a 3) | 10 s |
| Alto (≥ 4) | 20 s |

O tempo de verde vale em dois momentos: como verde mínimo ao entrar em
CARRO_VERDE, e como espera mínima a partir do aperto do botão. Assim, com
fluxo alto o pedestre espera ~20 s + 3 s de amarelo, mesmo que o verde já
esteja aceso há muito tempo. Um aperto durante o amarelo ou a travessia é
descartado ao fim da travessia.

Segurança: o pedestre só fica verde no estado em que os carros estão em
vermelho. Um estado inválido acende vermelho para os dois por 1 ciclo e
volta para CARRO_VERDE.

## Protocolo de telemetria (FPGA → Raspberry Pi)

Link serial síncrono no estilo SPI, só de leitura: a Raspberry é o mestre e a
FPGA só responde.

| Sinal | Direção | Raspberry (BCM / pino físico) | Tang Nano 4K |
|---|---|---|---|
| `sclk` | Pi → FPGA | GPIO11 / 23 | 40 |
| `cs_n` | Pi → FPGA | GPIO6 / 31 | 42 |
| `miso` | FPGA → Pi | GPIO20 / 38 | 33 |
| GND | — | 39 | GND |

- **Modo:** SPI modo 0 (CPOL = 0, CPHA = 0), MSB primeiro, 16 bits por quadro.
- **Delimitação:** o quadro começa quando `cs_n` desce e termina quando sobe.
  Ao descer `cs_n`, a FPGA congela os 16 bits (todos os campos são do mesmo
  instante) e já coloca o bit 15 em `miso`. A cada subida de `sclk` passa para
  o bit seguinte. A Raspberry lê `miso` antes de cada subida.
- **Taxa:** não há baud rate fixo, porque o clock vem da Raspberry. O driver
  usa um atraso de 20 000 iterações por meio período, o que dá `sclk` na faixa
  de ~10–25 kHz e cerca de 1 quadro por segundo. O limite da FPGA é cada nível
  de `sclk` durar mais que ~150 ns (4 ciclos de 27 MHz, por causa da
  sincronização).

Formato do quadro:

| Bits | Campo | Valores |
|---|---|---|
| 15–12 | marcador | sempre `1010` |
| 11–10 | cor dos carros | `00` vermelho, `01` amarelo, `10` verde |
| 9 | cor do pedestre | `1` verde, `0` vermelho |
| 8 | pedido de travessia pendente | `1` sim, `0` não |
| 7–6 | nível de fluxo | `00` baixo, `01` médio, `10` alto |
| 5–0 | segundos restantes da fase atual | 0–63 |

Exemplo: `1010 10 0 1 01 000100` = carros verdes, pedestre vermelho, pedido
pendente, fluxo médio, 4 s para o fim do verde.

A Raspberry descarta o quadro (`QUADRO INVALIDO`) se o marcador não for
`1010`, se cor ou fluxo valerem `11`, ou se o pedestre estiver verde com os
carros fora do vermelho. Um fio solto, sem GND comum ou com a FPGA não gravada
lê só zeros ou só uns, que caem nesse caso.

Saída do monitor:

```
[t=12s] carros=VERDE pedestres=VERMELHO restante=4s fluxo=MEDIO pedido=SIM
```

`restante` é o tempo que falta da fase atual. Em CARRO_VERDE sem pedido,
`restante=0s` significa que o verde mínimo já foi cumprido.

## Como usar

```bash
make sim        # 10 testbenches (Icarus Verilog)
make synth      # Yosys + nextpnr-himbaechel + Apicula -> build/top_semaforo.fs
make asm        # na Raspberry Pi: monta build/monitor_semaforo
make run        # sudo ./build/monitor_semaforo
```

Para gravar pelo Gowin EDA: crie um projeto para `GW1NSR-LV4CQN48PC7/I6` e
adicione `rtl/*.v`, `constraints/tangnano4k.cst` e
`constraints/tangnano4k.sdc`, com topo `top_semaforo`.

A fiação e o roteiro de teste na placa estão em
[`GUIA_MONTAGEM_HARDWARE.md`](GUIA_MONTAGEM_HARDWARE.md).

## Verificação

Logs em `docs/evidencias/`:

- `simulacao.txt` — 10/10 testbenches passando, sem warnings.
- `sintese_pnr.txt` — síntese e place & route sem warnings, 198 MHz máximo
  (exigido: 27 MHz). Usa 1 BSRAM (histórico) e 1 MULT18X18 (média).
- `montagem_arm.txt` — montagem sem warnings, decodificador conferido nos
  65 536 quadros possíveis e driver serial conferido contra um modelo da FPGA.
