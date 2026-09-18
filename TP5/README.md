# TP5 — Semáforo Inteligente com Botão de Pedestre (ARM–FPGA)

## Objetivo desta etapa

Consolidar o protótipo em um `top_semaforo.v` único, substituir o
barramento paralelo (TP3/TP4) pelo protocolo serial final com
handshaking e telemetria (`protocolo_serial.v`), estruturar o Assembly ARM
em uma biblioteca estática (`libembarcado.a`) reutilizável, e medir
throughput/latência reais de um teste contínuo de desempenho.

## Estrutura de pastas

```
TP5/
├── rtl/  -> TP1-TP4 (mantido) + protocolo_serial.v, top_semaforo.v (novos)
├── tb/   -> testbenches de todos os módulos, incluindo tb_top_semaforo.v (integração)
├── constraints/ -> tangnano4k.cst: barramento paralelo trocado por 5 fios seriais
├── asm/
│   ├── lib/          -> gpio_lib.s, strings_lib.s, buffer_lib.s (biblioteca .a)
│   ├── test_lib.s     -> harness de teste da biblioteca (equivalente a um testbench)
│   ├── main_tp5.s      -> programa final: macros, buffer, teste de desempenho
│   ├── monitor_semaforo.s -> log em tempo real do countdown (extensao pos-TP5)
│   └── (TP1-TP4 mantidos)
├── Makefile / README.md / Instrucoes_Hardware.md / Checklist_Rubricas.md / Relatorio.docx
└── docs/evidencias/
```

## Como rodar os testbenches em Verilog

```bash
cd TP5
make sim-protocolo_serial   # protocolo serial isolado
make sim-top_semaforo       # integração completa (FSM + sensores + protocolo + BRAM/DSP)
```

**Nota de depuração real registrada nesta etapa**: a primeira versão de
`tb_top_semaforo.v` reportava falha ("pedestre não recebeu verde"), mas o
problema não era do hardware — era do próprio testbench: com
`tempo_min_verde=3` e `tempo_pedestre=15` (valores pequenos escolhidos
para acelerar a simulação), a fase inteira de pedestre verde dura apenas
~16 ciclos de clock, e o teste original esperava 200 ciclos antes de
checar `led_ped_verde`, ou seja, checava *depois* de o sistema já ter
voltado sozinho para `CARRO_VERDE`. Uma investigação com rastreamento
ciclo a ciclo (usando referências hierárquicas do Icarus Verilog, ex.:
`dut.u_fsm.estado`) confirmou a janela exata (ciclos 3 a 18 após a
solicitação) e permitiu corrigir o tempo de espera do teste. Isso reforça
a importância de validar não só o RTL, mas também a própria metodologia
do testbench — ver seção 3 do `Relatorio.docx`.