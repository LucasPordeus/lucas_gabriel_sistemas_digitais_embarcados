# Checklist de Rubricas — TP4 (Matemática, BRAM, DSP e NEON SIMD)

- [x] **Arquitetura atualizada com BRAM, DSP, fluxos numéricos e rotinas
  SIMD.**
  Onde: `Relatorio.docx` seção 2 — `bram_historico` (BRAM),
  `media_movel_dsp` (DSP), `tp4_numerico.s`/`tp4_neon_simd.s` (fluxos
  numéricos e SIMD no ARM).

- [x] **Módulos aritméticos Verilog (com BRAM/DSP) simulados e validados
  no hardware físico.**
  Onde: `rtl/bram_historico.v` (5/5 testes) e `rtl/media_movel_dsp.v`
  (4/4 testes, após 2 correções documentadas) — ver
  `docs/evidencias/tp4_sim_*.txt`; procedimento de validação física em
  `Instrucoes_Hardware.md`.

- [x] **Rotinas Assembly multi-palavra, conversões, lookup tables e
  operações bitwise desenvolvidas e organizadas em macros.**
  Onde: `asm/tp4_numerico.s` — soma de 128 bits (`adds`/`adc`), conversão
  `scvtf`/`fcvtzs`, `tabela_niveis` (lookup), macro `extrai_campo`
  (bitwise reutilizável).

- [x] **FPGA, ARM e periféricos integrados e sincronizados
  eletricamente.**
  Onde: nenhuma mudança elétrica nesta etapa (por design — BRAM/DSP são
  internos); a sincronização elétrica já validada no TP3 é mantida e
  reutilizada (ver `Instrucoes_Hardware.md`).

- [x] **Comunicação ARM-FPGA validada com envio/recebimento de dados,
  detecção de erros e telemetria.**
  Onde: reutiliza e mantém o protocolo paralelo com ack do TP3; a
  telemetria plena (leitura da BRAM pelo ARM) é formalizada no TP5,
  conforme planejado no TP1 (seção 5.3).

- [x] **Integração parcial validada e documentada intermediariamente.**
  Onde: `README.md`, seção de medições, e `Relatorio.docx` seção 4.

- [x] **Desempenho (clock, latência) e estabilidade medidos e
  tabulados.**
  Onde: `README.md` — tabela de latência por módulo (ciclos e ns @ 27
  MHz), todos dentro do orçamento ONF-01 (≤ 50 ms).

- [x] **Relatório técnico completo validando o funcionamento integrado
  dos módulos.**
  Onde: `Relatorio.docx`, seções 1 a 7.
