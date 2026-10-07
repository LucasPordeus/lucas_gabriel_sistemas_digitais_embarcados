# Rubricas Não Cumpridas — Reavaliação

Reavaliação item a item do `Checklist_Rubricas.md` contra o estado real do
repositório (código, `.cst`, `docs/evidencias/`, arquivos citados). Cada
item abaixo está marcado como `[x]` cumprido no checklist original, mas a
verificação encontrou uma divergência real. Itens não listados aqui foram
confirmados como realmente cumpridos.

## Situação após a refatoração para o hardware real (2026-10-06)

| Item abaixo | Situação |
|---|---|
| Diagrama de blocos / arquitetura consolidada | Diagrama em `APRESENTACAO_PROJETO.md` §3.1; divisão de responsabilidades em `ARQUITETURA_FPGA_RASPBERRY.md` |
| Justificativa de ausência de PLL | Escrita em `ARQUITETURA_FPGA_RASPBERRY.md` e `APRESENTACAO_PROJETO.md` §4.6 |
| Histórico de depuração BRAM/DSP | Tabela de bugs em `APRESENTACAO_PROJETO.md` §8.3 |
| Números de casos de teste | Desatualizados de vez: agora são 10 testbenches (ver `docs/evidencias/simulacao.txt`) |
| Parsers em Assembly | **Parcial:** `asm/lib/telemetria.s` interpreta e valida o quadro binário de 16 bits; continua sem parsing de texto → número |
| Mapa de pinos do guia × `.cst` | Resolvido: `GUIA_MONTAGEM_HARDWARE.md` foi reescrito a partir do `.cst` atual (que mudou: sensor e LEDs saíram do banco de 2,5 V) |
| Roteiro de validação em hardware físico | Escrito em `GUIA_MONTAGEM_HARDWARE.md` §7; **falta executar na bancada** |

O texto abaixo é a reavaliação original, mantida como registro.

## 1. Arquitetura (ARM-FPGA)

### ❌ "Entradas, saídas e fluxos claramente explicados" / "Divisão de responsabilidades justificada" / "Diagramas integrais de todo o sistema"

O checklist cita `Relatorio.docx` como evidência primária dos três itens
(seção 2, "Arquitetura Consolidada", com diagrama de blocos ARM↔FPGA).

**Esse arquivo não existe e nunca existiu no repositório** (confirmado
via `git log --all` — nenhum commit jamais tocou `Relatorio.docx`, e não
há nenhum `.docx` em lugar nenhum do projeto). O diagrama de blocos
ARM↔FPGA descrito no checklist também não existe em nenhum outro arquivo
`.md` do projeto (`README.md` e `ARQUITETURA_FPGA_RASPBERRY.md` explicam
a divisão de responsabilidades em prosa, mas nenhum dos dois contém um
diagrama de blocos do sistema completo).

**Falta:** criar o diagrama de blocos e a documentação de arquitetura
consolidada em um arquivo que exista de fato (`.docx`, `.md` ou `.pdf`),
ou atualizar o checklist para apontar para onde essa informação
realmente está.

### ❌ "Requisitos de tempo real (BRAM, DSP, PLL, banda) totalmente dominados"

A discussão sobre por que o PLL não é necessário — citada como estando em
`Relatorio.docx` — não aparece em nenhum `.md` do projeto (`grep -rl
"PLL" *.md` só retorna o próprio `Checklist_Rubricas.md`, citando a si
mesmo). O mapeamento para BRAM/DSP está corretamente implementado e
testado em RTL, mas a discussão textual exigida pelo critério não existe
em lugar nenhum.

**Falta:** escrever a justificativa de ausência de PLL em um documento
real do projeto (ex.: `ARQUITETURA_FPGA_RASPBERRY.md` ou um relatório
técnico).

## 2. Hardware Verilog

### ❌ "Integração aritmética e BRAM/DSP perfeitamente correspondente à simulação"

O checklist afirma que o bug real encontrado no TP4 (lag de 1 ciclo no
cálculo da média + arredondamento) está "documentado em detalhe" em
`Relatorio.docx` — arquivo inexistente (ver item acima). Não há registro
desse histórico de depuração em nenhum outro arquivo do projeto
(`grep -rl` por "lag de 1 ciclo" / "arredondamento" nos `.md` só retorna
o próprio checklist). A correção em si está correta e validada por
`tb_media_movel_dsp.v`, mas a documentação do histórico de bug exigida
pelo critério não existe.

**Falta:** documentar o histórico de depuração (bug + causa + correção)
em algum arquivo do repositório.

### ⚠️ Números de casos de teste desatualizados no próprio checklist

O checklist cita `tb_fsm_semaforo.v` com "4/4" casos e `tb_top_semaforo.v`
com "4/4" casos. Os números reais atuais (`docs/evidencias/`, gerados
nesta sessão) são **5/5** e **12/12**, respectivamente — o sistema
evoluiu bastante desde que o checklist foi escrito. Não é uma falha
funcional (o sistema testa mais coisas do que o texto afirma), mas o
texto do checklist está desatualizado e deveria ser corrigido para não
subestimar a cobertura de teste real.

## 3. Software Assembly ARM 64-bit

### ❌ "Manipulação de vetores, strings e parsers"

O checklist cita `asm/lib/strings_lib.s`, `asm/lib/buffer_lib.s` e
`asm/tp4_numerico.s` como evidência de "parsers". Inspecionando as três
bibliotecas Assembly do projeto (`gpio_lib.s`, `strings_lib.s`,
`buffer_lib.s`, `protocolo_serial_gpio.s`) e todos os programas em
`asm/`, **não existe nenhuma rotina de parsing** (nenhuma leitura de
`stdin`/`argv`, nenhuma conversão string→número). O que existe é o
oposto: `uint_to_dec` (`strings_lib.s`) converte número→string (formatação
de saída, não parsing de entrada), `str_len` mede comprimento de string, e
`tp4_numerico.s` opera só sobre constantes fixas em `.data` — não há
nenhum texto externo sendo interpretado/parseado em nenhum lugar do
código Assembly.

**Falta:** implementar uma rotina real de parsing (ex.: `dec_to_uint`,
leitura de argumento de linha de comando, ou parsing de um campo de
texto recebido) para cumprir genuinamente este critério.

## 4. Integração

### ❌ "Integração com periféricos perfeitamente sincronizada eletricamente" / "Diagramas integrais de todo o sistema" (mapa de pinos da FPGA)

O `GUIA_MONTAGEM_HARDWARE.md` (citado no checklist sob o nome inexistente
`Instrucoes_Hardware.md`) contém uma tabela de mapa de pinos que **não
bate com o `constraints/tangnano4k.cst` real do projeto**:

| Sinal | Doc (`GUIA_MONTAGEM_HARDWARE.md`) | `.cst` real (atual) |
|---|---|---|
| `rst_n` | sem pino fixo (Gowin escolhe sozinho) | **pino 15, fixo** |
| `botao_raw` | pino 29, pull-**down** (botão externo protoboard) | **pino 14, pull-up** (botão onboard) |
| `led_vermelho` | pino 16 | **pino 31** |
| `led_amarelo` | pino 19 | **pino 32** |
| `led_verde` | pino 18 | **pino 33** |
| `led_ped_verde` | pino 13 | **pino 34** |
| `led_ped_vermelho` | pino 12 | **pino 35** |

Todos os 7 sinais do lado FPGA estão com pino e/ou pull errado no
documento em relação ao `.cst` que de fato será sintetizado. O próprio
comentário em `rtl/top_semaforo.v:19` ("rst_n ... sem pino fixo no .cst")
também contradiz o `.cst` atual, que já tem `rst_n` fixado no pino 15 —
ou seja, a inconsistência não é só entre doc e `.cst`, mas também entre o
comentário do RTL e o `.cst`. O guia inclusive argumenta explicitamente
que os pinos 14/15 "colidiriam" com os botões onboard e por isso devem
ser evitados — mas o `.cst` atual usa justamente 14 e 15 (o que sugere
que a mudança para usar os botões onboard foi proposital, só que o guia
nunca foi atualizado para refletir isso).

**Falta:** atualizar `GUIA_MONTAGEM_HARDWARE.md` (tabela da seção 2, nota
sobre pinos 14/15, e checklist da seção 7) para bater com o `.cst` atual,
e corrigir o comentário de `rtl/top_semaforo.v:19`.

## 5. Documentação e Validação

### ❌ "FSMs modulares validadas no hardware físico" — roteiro de aceitação em hardware físico

O checklist cita uma seção `Instrucoes_Hardware.md`, "Validação funcional
definitiva", cobrindo "segurança (ONF-08), ciclo completo e
estabilidade". **Essa seção não existe em nenhum arquivo do projeto.**
`GUIA_MONTAGEM_HARDWARE.md` tem apenas:
- seção 4.4, um checkpoint isolado da FPGA (sem botão/pedestre, só
  luzes piscando);
- seção 7, um checklist de fiação (conferir se cada fio está no pino
  certo) — que, além de não ser um roteiro de validação funcional,
  ainda lista os pinos antigos e errados (ver item anterior).

Nenhum dos dois cobre um roteiro de aceitação da regra de segurança
ONF-08 no hardware físico, um ciclo completo observado na placa real, ou
um teste de estabilidade prolongado.

**Falta:** escrever um roteiro de validação funcional real (passo a
passo do que observar na Tang Nano 4K física para confirmar ONF-08, um
ciclo completo carro→pedestre→carro, e estabilidade ao longo do tempo).
