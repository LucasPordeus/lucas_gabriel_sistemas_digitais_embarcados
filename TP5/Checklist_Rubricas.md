# Checklist de Rubricas — TP5 (Integração Final e Bibliotecas)

- [x] **Finalizar módulos Verilog (casos de borda, configurações OE,
  pinos).**
  Onde: `rtl/protocolo_serial.v` — OE do pino `miso` (`assign miso = cs_n
  ? 1'bz : miso_reg`) e `rtl/top_semaforo.v` — valores padrão de
  segurança no reset, integração de todos os blocos anteriores.

- [x] **Integrar comunicação ARM↔FPGA (protocolo final, handshaking,
  telemetria).**
  Onde: `rtl/protocolo_serial.v` — quadro serial de 8 bits com `cs_n`
  como handshake de início/fim, `busy` como confirmação de processamento,
  e telemetria (`nivel_fluxo`+`contagem_atual`) devolvida via `miso`.
  Validado em `tb/tb_protocolo_serial.v` (4/4) e integrado em
  `tb/tb_top_semaforo.v` (4/4).

- [x] **Estruturar Assembly (arquivos temáticos, bibliotecas .a,
  Makefiles robustos).**
  Onde: `asm/lib/gpio_lib.s`, `asm/lib/strings_lib.s`,
  `asm/lib/buffer_lib.s` compilados em `libembarcado.a`; `Makefile` com
  alvo `lib` dedicado e regras de link contra a biblioteca.

- [x] **Desenvolver funções avançadas Assembly (buffers, strings, macros
  parametrizadas).**
  Onde: `buffer_lib.s` (FIFO circular `cbuf_push`/`cbuf_pop`),
  `strings_lib.s` (`uint_to_dec`, `str_len`), `main_tp5.s` (macros
  `monta_comando` e `le_relogio`, parametrizadas com argumentos de
  registrador).

- [x] **Realizar testes contínuos de desempenho (throughput, latência,
  tempo de resposta).**
  Onde: `main_tp5.s` — 2000 transações medidas com `clock_gettime`
  (`CLOCK_MONOTONIC`); resultado real: throughput ≈ 13,7 milhões de
  transações/s e latência média ≈ 73 ns por transação em ambiente de
  desenvolvimento (ver `docs/evidencias/tp5_main_tp5_run.txt`; a
  metodologia de medição é a mesma que seria usada em hardware físico).

- [x] **Atualizar a documentação definitiva da arquitetura.**
  Onde: `Relatorio.docx` (relatório completo) e `Instrucoes_Hardware.md`
  (manual de hardware definitivo, consolidando TP1–TP5).

## Rubricas consolidadas (revalidadas nesta etapa)

- [x] Arquitetura completamente documentada com todos os blocos e
  fluxos — `Relatorio.docx`, seção 2.
- [x] Projeto Assembly em múltiplos módulos, bibliotecas, manipulação de
  strings e macros — seção "Estruturar Assembly" acima.
- [x] Protocolo digital finalizado com handshaking funcional, telemetria
  e troca real de dados — `rtl/protocolo_serial.v`.
- [x] Protótipo validado com testes de latência e throughput em cenário
  representativo — `main_tp5.s`, seção de desempenho.
- [x] Relatório final demonstrando domínio técnico e clareza das
  melhorias — `Relatorio.docx`, incluindo o histórico de bugs reais
  encontrados e corrigidos ao longo de todo o projeto (TP3: FSM; TP4:
  arredondamento DSP; TP5: timing do testbench de integração).
