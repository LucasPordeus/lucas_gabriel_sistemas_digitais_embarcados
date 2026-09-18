# TP3 — Semáforo Inteligente com Botão de Pedestre (ARM–FPGA)

## Objetivo desta etapa

Implementar a FSM completa do semáforo (hierárquica, com um contador de
tempo reutilizável), formalizar em Verilog o protocolo paralelo de
comunicação ARM→FPGA proposto no TP2 (dados + strobe + ack), mapear
fisicamente os registradores GPIO do Raspberry Pi em Assembly (via
`/dev/gpiomem`), e escrever um parser de comandos estruturado em Assembly
usando tabela de saltos. Também introduz automação de build via `Makefile`
modular.

## Estrutura de pastas

```
TP3/
├── rtl/          -> TP1+TP2 + contador_tempo, fsm_semaforo, protocolo_paralelo (novos)
├── tb/           -> testbenches de todos os módulos acima
├── constraints/  -> tangnano4k.cst ampliado (barramento dados[7:0]+strobe+ack, LEDs de pedestre)
├── asm/          -> TP1+TP2 + gpio_map.s, tp3_controle_fluxo.s (novos)
├── Makefile      -> modular, com alvos sim-<módulo>, asm, run-asm, objdump-<bin>
├── README.md / Instrucoes_Hardware.md / Checklist_Rubricas.md / Relatorio.docx
└── docs/evidencias/ -> logs reais de simulação, execução e objdump
```

## Como rodar os testbenches em Verilog

```bash
cd TP3
make sim                    # todos os testbenches (TP1+TP2+TP3)
make sim-fsm_semaforo       # só a FSM
make sim-protocolo_paralelo # só o protocolo paralelo
```

**Nota de depuração real registrada nesta etapa**: a primeira versão da
`fsm_semaforo` carregava a duração da fase ERRADA no contador no ciclo de
transição (usava a duração da fase que estava terminando, não da que
estava começando). O bug foi capturado pelo próprio testbench
(`tb_fsm_semaforo.v`) e corrigido calculando `valor_inicial_cont` a partir
de `prox_estado` em vez de `estado`. Isso é exatamente o tipo de erro de
temporização que a rubrica pede para ser analisado — ver seção 4.1 do
`Relatorio.docx`.
