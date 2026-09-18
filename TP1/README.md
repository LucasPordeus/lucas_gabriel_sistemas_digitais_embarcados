# TP1 — Semáforo Inteligente com Botão de Pedestre (ARM–FPGA)

## Objetivo desta etapa

Estabelecer o escopo do projeto, a arquitetura preliminar ARM (Raspberry Pi
Zero 2W) ↔ FPGA (Tang Nano 4K) e os primeiros artefatos técnicos: um módulo
combinacional simples em Verilog com testbench, e um programa básico em
Assembly ARM 64 bits que já trabalha com dados estruturados (vetor de
amostras), registradores, `LDR`/`STR`, decisões e laços.

O contexto completo do projeto, a justificativa da escolha, a arquitetura e
o planejamento das entregas (TP2 a TP5) estão no `Relatorio.docx` desta
pasta.

## Estrutura de pastas

```
TP1/
├── rtl/        -> módulos Verilog sintetizáveis
├── tb/         -> testbenches
├── constraints/-> pinout Tang Nano 4K (Gowin EDA) — usado a partir do TP2
├── asm/        -> programas Assembly ARM64 (GAS)
├── Makefile
├── README.md
├── Instrucoes_Hardware.md
├── Checklist_Rubricas.md
└── Relatorio.docx
```

## Como rodar o testbench em Verilog (Icarus Verilog)

Pré-requisitos: `iverilog` e `vvp` (Icarus Verilog ≥ 12).

```bash
cd TP1
make sim
```

Saída esperada:

```
[OK]    estado=00 -> V=1 A=0 G=0
[OK]    estado=01 -> V=0 A=1 G=0
[OK]    estado=10 -> V=0 A=0 G=1
[OK]    estado=11 -> V=1 A=0 G=0
RESULTADO: TODOS OS CASOS PASSARAM (4/4)
```

Um arquivo `tb_estado_basico_decoder.vcd` é gerado com as formas de onda;
pode ser aberto com `gtkwave tb_estado_basico_decoder.vcd`.

Comando manual equivalente (sem `make`):

```bash
iverilog -g2012 -o build/tp1_decoder.vvp rtl/estado_basico_decoder.v tb/tb_estado_basico_decoder.v
vvp build/tp1_decoder.vvp
```