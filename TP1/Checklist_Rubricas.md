# Checklist de Rubricas — TP1 (Estruturação e Arquitetura Preliminar)

- [x] **Explicou entradas, saídas e fluxo básico de dados relacionando ARM,
  FPGA e hardware.**
  Onde: `Relatorio.docx`, seções 2 ("Visão Geral da Aplicação") e 4.4
  ("Fluxo Geral de Dados"), com o diagrama de fluxo (Figura 1).

- [x] **Definiu e justificou a divisão de responsabilidades.**
  Onde: `Relatorio.docx`, seções 4.1 a 4.3 e 4.5 (justificativa da
  arquitetura ARM = controle de alto nível / FPGA = tempo real
  determinístico).

- [x] **Implementou módulo combinacional simples em Verilog e desenvolveu
  testbench funcional.**
  Onde: `rtl/estado_basico_decoder.v` (decodificador de estado → LEDs) e
  `tb/tb_estado_basico_decoder.v`.

- [x] **Estruturou corretamente a simulação em Verilog.**
  Onde: testbench com `task check(...)` reutilizável, `$dumpfile`/`$dumpvars`
  para forma de onda, contagem de erros e `$display` de resultado agregado.
  Execução real (`make sim`): 4/4 casos passaram — ver
  `docs/evidencias/tp1_sim_log.txt`.

- [x] **Codificou programa em Assembly ARM 64 bits utilizando
  registradores, LDR/STR, decisão e loops.**
  Onde: `asm/tp1_fluxo_basico.s` — laço `contagem_loop` (registradores
  `x0`–`x4`, `ldrb`, `strb`), decisões `cmp`/`b.eq`/`b.ge`/`b.le` para fim de
  laço e classificação de fluxo.

- [x] **Demonstrou compreensão de manipulação de dados estruturados em
  Assembly.**
  Onde: vetor `amostras` (12 bytes) percorrido por índice, resultado
  persistido em `resultado_contagem` via `strb`, e uso de `digitos` como
  tabela de consulta (lookup) indexada pelo valor da contagem. Execução
  real na Raspberry Pi confirma o resultado: `Fluxo MEDIO: contagem=7`
  — ver `docs/evidencias/tp1_asm_run.txt`.

## Artefatos adicionais exigidos no enunciado geral

- [x] Diagrama preliminar de arquitetura — `Relatorio.docx`, Figuras 1 e 2.
- [x] Fotos das conexões — ver `Instrucoes_Hardware.md` (placeholder de
  imagem a ser substituído pelas fotos reais da bancada).
- [x] Relatório técnico com visão geral, arquitetura, ambiente e primeiras
  implementações — `Relatorio.docx` (arquivo original fornecido, mantido
  sem alterações).
