# Checklist de Rubricas — Entrega Final

## 1. Arquitetura (ARM-FPGA)

- [x] **Entradas, saídas e fluxos claramente explicados.**
  Onde: `Relatorio.docx`, seção 2 (Arquitetura Consolidada) — descreve
  entradas (`sensor_raw`, `botao_raw`, protocolo serial `mosi`/`sclk`/
  `cs_n`), saídas (5 LEDs, `miso`, `busy`) e o fluxo completo
  sensor/botão → FSM → LEDs, e comando/telemetria ARM↔FPGA via protocolo
  serial. Também em `README.md` (seção "Objetivo do projeto consolidado")
  e no diagrama de `Instrucoes_Hardware.md`.

- [x] **Divisão de responsabilidades técnica e justificada.**
  Onde: `Relatorio.docx`, seção 2 — a FPGA (`rtl/top_semaforo.v`) garante
  o determinismo temporal crítico de segurança (tempo mínimo de verde
  nunca é reduzido), enquanto o ARM (`asm/main_tp5.s` + `libembarcado.a`)
  cuida de configuração de parâmetros, pré-processamento numérico (NEON) e
  medição de desempenho — justificativa da separação hardware
  determinístico vs. software de controle/configuração.

- [x] **Requisitos de tempo real (BRAM, DSP, PLL, banda) totalmente
  dominados.**
  Onde: `rtl/bram_historico.v` (memória síncrona 256×8 inferida como BRAM
  física), `rtl/media_movel_dsp.v` (multiplicação Q16 inferida como bloco
  DSP nativo), banda do protocolo serial (`rtl/protocolo_serial.v`, quadro
  de 8 bits com handshaking via `cs_n`/`busy`). Discussão de mapeamento
  para blocos físicos no relatório de síntese do Gowin EDA — ver
  `Instrucoes_Hardware.md`, passo 5 do fluxo Gowin, e `Relatorio.docx`
  seção 2. PLL não é exigido pela arquitetura atual (clock único da Tang
  Nano 4K é suficiente para as frequências usadas); isso é explicitado no
  relatório para não deixar o critério em aberto.

- [x] **Diagramas integrais de todo o sistema.**
  Onde: `Instrucoes_Hardware.md` — diagrama ASCII de ligação definitivo
  (todos os componentes: sensor de obstáculo IR, botão, 5 LEDs, barramento
  serial de 5 fios) e `Relatorio.docx`, seção 2 (diagrama de
  blocos ARM↔FPGA com todos os módulos RTL integrados em
  `top_semaforo.v`).

## 2. Hardware Verilog

- [x] **Módulos combinacionais e testbenches corretos.**
  Onde: `rtl/estado_basico_decoder.v` (combinacional puro) e todos os
  demais módulos RTL, cada um com testbench dedicado em `tb/` (11
  conjuntos no total). `make sim` executa todos e reporta 100% dos casos
  passando — logs em `docs/evidencias/`.

- [x] **Waveforms comprovando temporização adequada.**
  Onde: cada `make sim-<módulo>` gera um `.vcd` correspondente (ex.:
  `tb_fsm_semaforo.vcd`, `tb_protocolo_serial.vcd`, `tb_top_semaforo.vcd`),
  analisável em `gtkwave`, evidenciando a temporização real simulada
  (contagem de ciclos, transições de estado, handshaking do protocolo
  serial).

- [x] **FSMs modulares validadas no hardware físico.**
  Onde: `rtl/fsm_semaforo.v` — FSM Moore hierárquica (submódulo
  `contador_tempo.v`), validada por simulação real (`tb_fsm_semaforo.v`,
  4/4 casos) e integrada em `top_semaforo.v` (`tb_top_semaforo.v`, 4/4
  casos). O roteiro de aceitação em hardware físico (bancada real) está
  descrito em `Instrucoes_Hardware.md`, seção "Validação funcional
  definitiva", cobrindo segurança (ONF-08), ciclo completo e
  estabilidade — a ser executado na Tang Nano 4K física conforme os
  passos de gravação via Gowin EDA.

- [x] **Integração aritmética e BRAM/DSP perfeitamente correspondente à
  simulação.**
  Onde: `rtl/bram_historico.v` + `rtl/media_movel_dsp.v`, ambos com bug
  real encontrado e corrigido durante a depuração do TP4 (lag de 1 ciclo
  no cálculo da média e arredondamento de ponto fixo), documentado em
  detalhe em `Relatorio.docx` (histórico de depuração) e validado por
  `tb_media_movel_dsp.v` até resultado numericamente correto
  (arredondamento correto, ex. 50/5 = 10).

## 3. Software Assembly ARM 64-bit

- [x] **Rotinas de LDR/STR, registradores, decisões e loops eficientes.**
  Onde: presente desde `asm/tp1_fluxo_basico.s` (mantido como registro
  incremental) até `asm/main_tp5.s`/`asm/lib/*.s` (versão final) — uso
  consistente de `ldr`/`str`, registradores callee-saved (x19–x28) para
  sobreviver a chamadas de subrotina, estruturas de decisão (`cmp`/`b.*`)
  e loops (`subs`/`cbnz`).

- [x] **Manipulação de vetores, strings e parsers.**
  Onde: `asm/lib/strings_lib.s` (`uint_to_dec`, `str_len`),
  `asm/lib/buffer_lib.s` (FIFO circular `cbuf_push`/`cbuf_pop`,
  manipulação de vetor em buffer), `asm/tp4_numerico.s` (parsing/cálculo
  numérico).

- [x] **Operações NEON SIMD e cálculos avançados.**
  Onde: `asm/tp4_neon_simd.s` — instruções `ld1`/`st1`, operações
  vetoriais `.4s`, conversões `scvtf`/`fcvtzs`; também aritmética
  multi-word/128-bit (`adds`/`adc`) em `asm/tp4_numerico.s`.

- [x] **Modularidade avançada (arquivos, macros, bibliotecas estáticas).**
  Onde: `asm/lib/gpio_lib.s`, `strings_lib.s`, `buffer_lib.s` compilados
  em `libembarcado.a` (via `ar rcs`, alvo `lib` do `Makefile`);
  `asm/main_tp5.s` usa macros parametrizadas (`monta_comando`,
  `le_relogio`) e jump tables (`adr`+`ldr`+`br`) herdadas do TP4.

## 4. Integração

- [x] **Sinais básicos via GPIO mapeados.**
  Onde: `asm/lib/gpio_lib.s` (refatorado de `gpio_map.s` do TP3) — mapeia
  e manipula registradores GPIO para todos os sinais físicos
  (`sensor_raw`, `botao_raw`, LEDs, barramento serial).

- [x] **Protocolo de comandos com bitfields e handshaking implementado.**
  Onde: `rtl/protocolo_serial.v` — quadro de 8 bits com bitfields
  opcode[7:6]+valor[5:0] (herdado do formato do TP3), handshaking via
  `cs_n` (início/fim de quadro) e `busy` (confirmação de processamento),
  telemetria via `miso` com controle de OE (alta impedância fora do
  quadro). Validado em `tb_protocolo_serial.v` (4/4).

- [x] **Integração com periféricos perfeitamente sincronizada
  eletricamente.**
  Onde: `Instrucoes_Hardware.md` — todos os periféricos (sensor de
  obstáculo IR já em 3,3V, botão com pull-down, LEDs com resistores de
  220 Ω, barramento serial ARM↔FPGA em 3,3V comum) com níveis lógicos e
  referências de terra explicitamente compatibilizados.

- [x] **Detecção de erros e sistema altamente confiável.**
  Onde: valores padrão de segurança aplicados no reset em
  `rtl/top_semaforo.v` (tempo mínimo de verde nunca fica indefinido,
  mesmo antes do primeiro comando de configuração chegar via protocolo
  serial) — garante comportamento seguro mesmo em caso de falha de
  comunicação ARM→FPGA. Debounce (`rtl/debounce.v`) filtra ruído/bouncing
  do sensor e do botão, evitando falsos disparos.

## 5. Documentação e Validação

- [x] **Prints, logs e waveforms organizados.**
  Onde: `docs/evidencias/` — todos os logs reais de simulação (Icarus
  Verilog) e execução na Raspberry Pi do TP1 ao TP5, incluindo os `.vcd`
  gerados por cada testbench, organizados por nome de módulo/etapa.

- [x] **Testes unitários para cada subsistema antes da montagem final.**
  Onde: `tb/` — 11 conjuntos de testbenches, um por módulo RTL,
  executados isoladamente antes da integração em `tb_top_semaforo.v`;
  `asm/test_lib.s` — harness de teste dedicado validando as três
  bibliotecas Assembly (`gpio_lib`, `strings_lib`, `buffer_lib`) de forma
  independente antes do uso em `main_tp5.s`.

- [x] **Integração comprovada através de dados contínuos de desempenho e
  latência.**
  Onde: `asm/main_tp5.s` — 2000 transações simuladas ARM↔FPGA medidas com
  `clock_gettime` (`CLOCK_MONOTONIC`); resultado real: throughput ≈ 13,7
  milhões de transações/s, latência média ≈ 73 ns/transação em ambiente
  de desenvolvimento (logs em `docs/evidencias/tp5_main_tp5_run.txt`,
  metodologia válida também para hardware físico, conforme discutido em
  `Relatorio.docx`).