# TP4 — Semáforo Inteligente com Botão de Pedestre (ARM–FPGA)

## Objetivo desta etapa

Adicionar o histórico de contagem de veículos em BRAM, calcular o nível de
fluxo com um filtro de média móvel usando o bloco DSP nativo da Tang Nano
4K, e ampliar o lado ARM com rotinas numéricas avançadas (aritmética
multi-palavra, conversão inteiro↔float, lookup tables, macros bitwise) e
processamento paralelo com NEON SIMD.

## Estrutura de pastas

```
TP4/
├── rtl/  -> TP1-TP3 + bram_historico, media_movel_dsp (novos)
├── tb/   -> testbenches de todos os módulos
├── constraints/ -> tangnano4k.cst (sem novos pinos: BRAM/DSP são internos)
├── asm/  -> TP1-TP3 + tp4_numerico.s, tp4_neon_simd.s (novos)
├── Makefile / README.md / Instrucoes_Hardware.md / Checklist_Rubricas.md / Relatorio.docx
└── docs/evidencias/
```

## Como rodar os testbenches em Verilog

```bash
cd TP4
make sim-bram_historico
make sim-media_movel_dsp
```

**Notas de depuração real registradas nesta etapa:**

1. `media_movel_dsp`: a primeira versão calculava a média usando o valor
   *anterior* de `soma` (o acumulador ainda não incluía a amostra recém-
   chegada), gerando uma média sempre atrasada em 1 amostra. Corrigido
   introduzindo o sinal combinacional `soma_novo`, usado tanto para
   registrar `soma` quanto para calcular `produto` no mesmo ciclo.
2. Ainda em `media_movel_dsp`: a divisão por 5 em ponto fixo Q16
   (`soma * round(65536/5) >> 16`) truncava sistematicamente 1 unidade
   abaixo do valor correto (ex.: 50/5 dava 9, não 10), por ausência de
   arredondamento. Corrigido somando meio-LSB (`+32768`) antes do
   deslocamento — prática padrão de arredondamento em aritmética de ponto
   fixo.

Essas duas correções (com o log de simulação mostrando a falha e depois o
sucesso) estão detalhadas na seção 4.1 do `Relatorio.docx` e evidenciam a
"análise de waveforms/temporização" pedida na rubrica.