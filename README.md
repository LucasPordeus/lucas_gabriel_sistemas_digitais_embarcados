# Semáforo Inteligente com Botão de Pedestre — Tang Nano 4K + Raspberry Pi

Projeto de bloco de Sistemas Digitais Embarcados (Lucas Gabriel). Cruzamento
com travessia de pedestres sob demanda: por padrão o sinal fica **verde para
os carros** e o pedestre aperta um botão para pedir a travessia. A FPGA mede
o fluxo de veículos com um sensor IR: com **fluxo baixo** o pedestre é
liberado mais rápido; com **fluxo alto** ele espera mais.

- **FPGA (Tang Nano 4K, GW1NSR-LV4C, Verilog):** lê botão e sensor, decide as
  fases e acende os LEDs. Funciona sozinha.
- **Raspberry Pi Zero 2W (Assembly ARM64):** **apenas monitora**. Lê a
  telemetria da FPGA uma vez por segundo e imprime o estado. Não envia nenhum
  comando nem configura nada.

## Organização do repositório

```
lucas_gabriel_sistemas_digitais_embarcados/
├── final_project/   sistema final, preparado para o hardware real (comece por aqui)
├── TP1/ … TP5/      entregas incrementais, mantidas como registro
└── RELATORIOS/      relatórios .docx de cada etapa e do projeto final
```

| Pasta | Conteúdo |
|---|---|
| [`final_project/`](final_project/) | RTL, testbenches, constraints, monitor ARM, Makefile e evidências da versão final |
| [`TP1/`](TP1/) | escopo, arquitetura preliminar, decoder combinacional, fundamentos de Assembly |
| [`TP2/`](TP2/) | debounce, sensor de veículo e botão; polling em Assembly |
| [`TP3/`](TP3/) | FSM completa e protocolo paralelo; GPIO via `mmap` |
| [`TP4/`](TP4/) | histórico em BRAM e média móvel em DSP; aritmética e NEON em Assembly |
| [`TP5/`](TP5/) | topo integrado com protocolo serial; biblioteca estática e benchmark |
| [`RELATORIOS/`](RELATORIOS/) | `lucas_gabriel_PB_TP1…TP5.docx`, `lucas_gabriel_PB_AT.docx` e imagens do relatório final |

Cada pasta `TP*` tem seu próprio README e Makefile e reflete o estado do
projeto naquela etapa. O que vale para o sistema final está em
`final_project/`; os programas de exercício dos TPs (NEON, benchmark, monitor
simulado) não fazem parte dele.

## Projeto final

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

Documentação detalhada:

- [`final_project/README.md`](final_project/README.md): comportamento, protocolo e uso.
- [`final_project/GUIA_MONTAGEM_HARDWARE.md`](final_project/GUIA_MONTAGEM_HARDWARE.md): fiação, bancos de tensão e roteiro de validação na placa.
- [`final_project/ARQUITETURA_FPGA_RASPBERRY.md`](final_project/ARQUITETURA_FPGA_RASPBERRY.md): por que a FPGA não depende da Raspberry; BRAM, DSP e PLL.

### Comportamento

| Fase | Carros | Pedestre | Duração | Sai quando |
|---|---|---|---|---|
| CARRO_VERDE | verde | vermelho | indefinida | há pedido **e** o tempo de verde acabou |
| CARRO_AMARELO | amarelo | vermelho | 3 s | o tempo acaba |
| PEDESTRE_VERDE | vermelho | verde | 15 s | o tempo acaba (o pedido é apagado) |

Tempo de verde dos carros, conforme o fluxo medido. O sensor conta carros em
janelas de 10 s, cada contagem é gravada na BRAM e a média das últimas 5
janelas (~50 s) é calculada no bloco DSP:

| Fluxo | Média por janela de 10 s | Carros nos últimos 50 s | Tempo de verde |
|---|---|---|---|
| Baixo | ≤ 1 | 0 a 7 | 5 s |
| Médio | 2 a 3 | 8 a 17 | 10 s |
| Alto | ≥ 4 | 18 ou mais | 20 s |

O tempo de verde vale em dois momentos: como verde mínimo ao entrar em
CARRO_VERDE, e como espera mínima a partir do aperto do botão. Assim, com
fluxo alto o pedestre espera ~20 s + 3 s de amarelo, mesmo que o verde já
esteja aceso há muito tempo. Um aperto durante o amarelo ou a travessia é
descartado ao fim da travessia.

Segurança: o pedestre só fica verde no estado em que os carros estão em
vermelho. Um estado inválido acende vermelho para os dois por 1 ciclo e
volta para CARRO_VERDE.

### Protocolo de telemetria (FPGA → Raspberry Pi)

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
  Ao descer `cs_n`, a FPGA congela os 16 bits e já coloca o bit 15 em `miso`;
  a cada subida de `sclk` passa para o bit seguinte.
- **Taxa:** não há baud rate fixo, porque o clock vem da Raspberry (na ordem
  de 10 kHz, 1 quadro por segundo).

| Bits | Campo | Valores |
|---|---|---|
| 15–12 | marcador | sempre `1010` |
| 11–10 | cor dos carros | `00` vermelho, `01` amarelo, `10` verde |
| 9 | cor do pedestre | `1` verde, `0` vermelho |
| 8 | pedido de travessia pendente | `1` sim, `0` não |
| 7–6 | nível de fluxo | `00` baixo, `01` médio, `10` alto |
| 5–0 | segundos restantes da fase atual | 0–63 |

A Raspberry descarta o quadro (`QUADRO INVALIDO`) se o marcador não for
`1010`, se cor ou fluxo valerem `11`, ou se o pedestre estiver verde com os
carros fora do vermelho. Saída do monitor:

```
[t=12s] carros=VERDE pedestres=VERMELHO restante=4s fluxo=MEDIO pedido=SIM
```

### Como usar

No PC (simulação e síntese):

```bash
cd final_project
make sim        # 10 testbenches (Icarus Verilog)
make synth      # Yosys + nextpnr-himbaechel + Apicula -> build/top_semaforo.fs
```

Para gravar pelo Gowin EDA: projeto para `GW1NSR-LV4CQN48PC7/I6` com
`final_project/rtl/*.v`, `final_project/constraints/tangnano4k.cst` e
`final_project/constraints/tangnano4k.sdc`, topo `top_semaforo`.

Na Raspberry Pi (Raspberry Pi OS 64 bits), depois de copiar a pasta
`final_project/` inteira:

```bash
cd final_project
make asm        # monta build/monitor_semaforo
make run        # sudo ./build/monitor_semaforo (Ctrl+C encerra)
```

### Verificação

Logs em [`final_project/docs/evidencias/`](final_project/docs/evidencias/):

- `simulacao.txt` — 10/10 testbenches passando, sem warnings.
- `sintese_pnr.txt` — síntese e place & route sem warnings, 198 MHz máximo
  (exigido: 27 MHz). Usa 1 BSRAM (histórico) e 1 MULT18X18 (média).
- `montagem_arm.txt` — montagem sem warnings, decodificador conferido nos
  65 536 quadros possíveis e driver serial conferido contra um modelo da FPGA.

O teste na placa física segue o roteiro da seção 7 de
[`final_project/GUIA_MONTAGEM_HARDWARE.md`](final_project/GUIA_MONTAGEM_HARDWARE.md).
