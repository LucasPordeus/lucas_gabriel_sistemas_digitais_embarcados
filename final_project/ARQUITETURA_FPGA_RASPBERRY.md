# Por que a FPGA não depende da Raspberry Pi (e o que a Raspberry Pi faz)

> (FPGA) e a Raspberry Pi Zero 2W neste projeto — o pilar da regra de
> segurança ONF-08 citada no `CONTEXTO_PROJETO_SEMAFORO_INTELIGENTE.md`.

---

## A analogia

Pensa num semáforo de rua de verdade: ele tem um temporizador interno que
decide sozinho quando trocar de cor. Uma equipe de trânsito pode, de vez
em quando, ir lá e reprogramar esse tempo (mais verde de manhã, menos à
noite) — mas se essa equipe nunca aparecer, o semáforo continua
funcionando exatamente igual, com os valores de fábrica.

**A FPGA é o temporizador; a Raspberry Pi é a equipe de trânsito.**

---

## Por que a FPGA não depende da Raspberry Pi

Três motivos concretos, todos visíveis no código:

### 1. Os valores de segurança já nascem certos, sem nenhum comando externo

Em [`rtl/top_semaforo.v`](rtl/top_semaforo.v), no exato momento do reset
(ligar a placa), os registradores já recebem valores de fábrica:

```verilog
tempo_min_reg     <= 6'd10;
tempo_amarelo_reg <= 6'd3;
limiar_baixo_reg  <= 6'd3;
limiar_alto_reg   <= 6'd8;
```

Isso acontece **antes** de qualquer byte chegar do ARM. A FPGA nunca fica
"esperando instrução" pra saber o que fazer — ela já sabe.

### 2. A decisão de trocar de fase é 100% interna, ciclo a ciclo

Em [`rtl/fsm_semaforo.v`](rtl/fsm_semaforo.v), a máquina de estados
avalia sozinha, a cada pulso do clock de 27 MHz, se o tempo mínimo de
verde já passou e se tem pedestre esperando. Não existe um "pergunta pro
ARM se pode trocar" em lugar nenhum — a lógica está fisicamente cablada
dentro do chip.

### 3. O protocolo serial só recebe comandos — nunca pede permissão pra agir

Olhando [`rtl/protocolo_serial.v`](rtl/protocolo_serial.v) e a
instanciação em `rtl/top_semaforo.v`: a interface
`sclk`/`cs_n`/`mosi`/`miso` existe pra a FPGA *aceitar* um ajuste de
configuração *se* alguém mandar, mas o semáforo já está rodando (com os
valores padrão) independente disso.

Se você desligar a Raspberry Pi agora, literalmente nada muda no
comportamento do semáforo — ele não trava, não "espera" ninguém, não tem
nenhum código do tipo "se não receber comando em X segundos, faça Y"
(porque não precisa: ele já sabe o que fazer sozinho).

Essa é a regra de segurança **ONF-08**: o funcionamento correto do
cruzamento nunca pode depender de um computador externo que pode travar,
atrasar ou ser desligado.

---

## O que a Raspberry Pi de fato faz, então

Ela não participa de nenhuma decisão de tempo real — tudo que ela faz é
**opcional e não-crítico**:

| Programa | O que faz | É essencial pro semáforo funcionar? |
|---|---|---|
| `asm/main_tp5.s` | Simula 2000 transações do protocolo, mede throughput/latência | Não — é benchmark de desempenho |
| `asm/monitor_semaforo.s` / `asm/monitor_semaforo_hw.s` | **Lê** a telemetria (fase + contagem regressiva) e mostra num log em tempo real | Não — é só visualização, um "painel" pra humano acompanhar |
| `asm/tp4_numerico.s` / `asm/tp4_neon_simd.s` | Pré-processamento numérico (médias, vetorização) como exercício de otimização em ARM | Não — nem se conecta à FPGA |
| Comandos de configuração (`OP_TEMPO_MIN`, `OP_TEMPO_AMARELO`, `OP_LIMIAR_BAIXO`, `OP_LIMIAR_ALTO`) | Permitiriam reprogramar os tempos/limiares padrão | Não — se nunca forem enviados, os valores de fábrica seguem valendo |

Repare que a "telemetria" é **só leitura**: a Raspberry Pi manda um byte
de comando (às vezes até um comando "vazio", só reafirmando o valor
padrão, como faz o `monitor_semaforo_hw.s` com `0x0A`) apenas pra ter uma
desculpa de clockar o protocolo e puxar de volta o dado que a FPGA quer
mostrar. Ela nunca manda "abre pro pedestre agora" ou "fecha o verde" —
esse tipo de comando nem existe no protocolo.

---

## Resumindo em uma frase

**A FPGA decide e age; a Raspberry Pi só configura (quando quiser) e
observa (quando quiser).** Por isso o projeto consegue afirmar, com
confiança, que travar ou desligar a Pi nunca compromete a segurança do
cruzamento.
