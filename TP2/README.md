# TP2 — Semáforo Inteligente com Botão de Pedestre (ARM–FPGA)


## Objetivo desta etapa

Implementar e validar os dois primeiros módulos combinacionais/sequenciais
reais do sistema — leitura filtrada (debounce) do sensor de veículos e do
botão de pedestre — sintetizá-los na Tang Nano 4K, e escrever a primeira
rotina Assembly ARM que faz *polling* estruturado do status simulado da
FPGA, propondo o mecanismo de sinais de comunicação ARM↔FPGA que será
formalizado no TP3 (protocolo paralelo com strobe/ack).

A arquitetura detalhada, as justificativas de tempo real e os diagramas
atualizados estão no `Relatorio.docx` desta pasta.

## Estrutura de pastas

```
TP2/
├── rtl/          -> estado_basico_decoder (TP1) + debounce, sensor_veiculo, botao_pedestre (novos)
├── tb/           -> testbenches de todos os módulos acima
├── constraints/  -> tangnano4k.cst (novo — primeiro pinout físico do projeto)
├── asm/          -> tp1_fluxo_basico.s (TP1) + tp2_polling_contagem.s (novo)
├── Makefile
├── README.md
├── Instrucoes_Hardware.md
├── Checklist_Rubricas.md
├── Relatorio.docx
└── docs/evidencias/ -> logs reais de simulação e execução (waveforms .vcd e saídas de console)
```

## Como rodar os testbenches em Verilog

```bash
cd TP2
make sim              # roda todos os testbenches (TP1 + TP2)
make sim-debounce     # roda só o testbench do debounce
make sim-sensor_veiculo
make sim-botao_pedestre
```

Cada testbench gera um `.vcd` (ex.: `tb_debounce.vcd`) que pode ser aberto
com `gtkwave tb_debounce.vcd` para inspecionar as formas de onda de entrada
ruidosa vs. saída filtrada. Os logs de console reais desta execução estão
em `docs/evidencias/tp2_sim_*.txt`.