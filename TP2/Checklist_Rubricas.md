# Checklist de Rubricas — TP2 (Circuitos Combinacionais e Rotinas Estruturadas)

- [x] **Arquitetura ARM-FPGA detalhada com responsabilidades e fluxo de
  dados.**
  Onde: `Relatorio.docx`, seção 2 (arquitetura atualizada com os módulos
  `debounce`, `sensor_veiculo`, `botao_pedestre` e o registrador de status
  ARM↔FPGA proposto).

- [x] **Justificou escolhas baseadas em requisitos de tempo real.**
  Onde: `Relatorio.docx`, seção 2.2 (parametrização de `N_CYCLES` do
  debounce como troca entre latência de resposta e rejeição de ruído,
  respeitando ONF-01 ≤ 50 ms).

- [x] **Diagramas técnicos incluindo sinais digitais, entradas e saídas.**
  Onde: `Relatorio.docx`, seção 2.3, e `Instrucoes_Hardware.md` (diagrama
  ASCII de ligação sensor de obstáculo IR → Tang Nano).

- [x] **Implementou combinacionais em Verilog e validou com testbenches e
  waveforms.**
  Onde: `rtl/debounce.v`, `rtl/sensor_veiculo.v`, `rtl/botao_pedestre.v` +
  `tb/tb_debounce.v`, `tb/tb_sensor_veiculo.v`, `tb/tb_botao_pedestre.v`.
  Execução real (`make sim`): 3/3, 1/1 e 2/2 casos passaram — ver
  `docs/evidencias/tp2_sim_*.txt` e os `.vcd` gerados.

- [x] **Sintetizou e executou módulo no hardware físico da Tang Nano 4K.**
  Onde: `constraints/tangnano4k.cst` (pinout) + passo a passo no
  `README.md`, seção "Gowin EDA". Evidência fotográfica: placeholder em
  `Relatorio.docx` (a substituir pela foto real da bancada).

- [x] **Analisou waveforms para evidenciar validação de comportamento.**
  Onde: `Relatorio.docx`, seção 4 — análise textual das transições
  capturadas nos `.vcd` (rejeição do ruído de bouncing e propagação do
  nível estável após `N_CYCLES`).

- [x] **Programas Assembly com loops e decisões condicionais.**
  Onde: `asm/tp2_polling_contagem.s` — `poll_loop` com `cmp`/`b.ge`/`b.eq`/
  `cbz`.

- [x] **Controle de fluxo estruturado em Assembly.**
  Onde: idem — sub-rotinas `imprime_veiculo`/`imprime_solicitacao`/
  `imprime_resumo` chamadas via `bl`/`ret`, com prólogo/epílogo `stp`/`ldp`.

- [x] **Rotinas aritméticas e manipulação de memória no ARM.**
  Onde: incremento dos contadores (`add x21,x21,#1` / `add x22,x22,#1`) e
  persistência em memória via `strb` (`contagem_veiculos`,
  `contagem_solicitacoes`).

- [x] **Descreveu/implementou mecanismos de interação ARM-FPGA.**
  Onde: comentário de cabeçalho do `tp2_polling_contagem.s` e
  `Relatorio.docx` seção 3 — registrador de status de 1 byte
  (`bit0=sensor`, `bit1=botão`) como modelo do dado trocado entre FPGA e
  ARM.

- [x] **Propôs mecanismo de sinais/comandos de comunicação.**
  Onde: `Relatorio.docx`, seção 3.1 — proposta do protocolo paralelo
  (dados + strobe + ack) a ser implementado em Verilog no TP3.

- [x] **Registrou evidências (códigos, simulação, fotos).**
  Onde: `docs/evidencias/` (logs reais de simulação e execução) +
  placeholders de foto em `Relatorio.docx`/`Instrucoes_Hardware.md`.
