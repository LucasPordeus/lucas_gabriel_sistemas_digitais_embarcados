# Checklist de Rubricas — TP3 (Máquinas de Estado e Controle GPIO)

- [x] **Analisou requisitos de temporização ao simular transições das
  FSMs.**
  Onde: `Relatorio.docx` seção 4.1 — relato do bug real de carregamento de
  duração de fase encontrado e corrigido via `tb_fsm_semaforo.v`
  (ver também nota de depuração no `README.md`).

- [x] **Arquitetura atualizada com hierarquia Verilog e controle ARM.**
  Onde: `Relatorio.docx` seção 2 — `fsm_semaforo` instancia
  `contador_tempo` (hierarquia); ARM ganha `gpio_map.s` (acesso físico) e
  `tp3_controle_fluxo.s` (parser).

- [x] **Diagrama mapeando FSMs e início do mapeamento GPIO ARM-FPGA.**
  Onde: `Relatorio.docx` seção 2.1; `Instrucoes_Hardware.md` (diagrama do
  barramento paralelo de 10 fios).

- [x] **FSMs Verilog desenvolvidas, testadas e com waveforms analisados.**
  Onde: `rtl/fsm_semaforo.v` + `tb/tb_fsm_semaforo.v` — 5/5 casos passaram
  (`docs/evidencias/tp3_sim_fsm_semaforo.txt`).

- [x] **FSMs sintetizadas na Tang Nano 4K validadas com fotos.**
  Onde: `constraints/tangnano4k.cst` (pinout completo) + placeholder de
  foto em `Relatorio.docx`/`Instrucoes_Hardware.md`.

- [x] **Estruturas de controle Assembly avançadas (múltiplas condições,
  tabelas de salto).**
  Onde: `asm/tp3_controle_fluxo.s` — tabela `tabela_saltos` (jump table
  indexada por opcode, `br x4`), decisões `cmp`/`b.lt`.

- [x] **Rotinas de parsing para interpretação de comandos no ARM.**
  Onde: idem — decodifica opcode (bits 7:6) e valor (bits 5:0) de cada
  byte de comando.

- [x] **Endereços e registradores GPIO mapeados (acesso LDR/STR).**
  Onde: `asm/gpio_map.s` — offsets `GPFSEL1`, `GPSET0`, `GPCLR0`, `GPLEV0`
  do BCM2710A1, acessados via `ldr`/`str` sobre a região mapeada.

- [x] **Escrita/leitura simulada nos registradores GPIO demonstrada.**
  Onde: idem — execução real na Raspberry Pi confirma leitura ALTO
  após `GPSET0` e BAIXO após `GPCLR0`
  (`docs/evidencias/tp3_gpio_map_run.txt`).

- [x] **Integração testada fisicamente na FPGA e Raspberry Pi.**
  Onde: `Instrucoes_Hardware.md`, seção "Validação funcional esperada" —
  primeira conexão elétrica real entre as duas placas (barramento
  paralelo).

- [x] **Evidências com waveforms, objdump e GDB registradas.**
  Onde: `docs/evidencias/tp3_gpio_map_objdump.txt` (objdump real) +
  README.md (comandos de GDB) + `.vcd` dos testbenches.

- [x] **Build automatizado com Makefile modular.**
  Onde: `Makefile` — alvos independentes `sim-<módulo>`, `asm`, `run-asm`,
  `objdump-<bin>`.

- [x] **Relatório técnico de integração parcial estruturado.**
  Onde: `Relatorio.docx` completo, seções 1 a 7.
