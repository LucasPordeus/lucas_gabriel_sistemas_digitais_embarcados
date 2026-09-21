# Guia de Montagem Física — Semáforo Inteligente (FPGA + Raspberry Pi)

> Passo a passo para montar o circuito na protoboard e conectar a
> **Tang Nano 4K** (FPGA) com a **Raspberry Pi Zero 2W**, usando os
> componentes físicos do projeto: protoboard, jumpers, resistores, LEDs
> e sensor IR (o botão de pedestre e o reset usam os botões onboard da
> própria Tang Nano, sem montagem externa).
>
> Este guia cobre só a **montagem física**. Para compilar/gravar o
> Verilog e montar/rodar o Assembly, veja a seção 10 do

---

## 0. Antes de começar — segurança elétrica

- **Desligue (desconecte da USB) as duas placas antes de mexer em qualquer fio.** Só ligue a alimentação depois que toda a fiação estiver conferida.
- As duas placas trabalham em **3,3V**. Não ligue nada em 5V nos pinos de sinal (sensor, botão, LEDs, protocolo serial) — o GW1NSR-LV4C da Tang Nano **não é tolerante a 5V** e queima com facilidade.
- Os números de pino usados abaixo (`45`, `15`, `28`, `14`, `31`-`35`, `39`-`43`) são os mesmos declarados em [`constraints/tangnano4k.cst`](constraints/tangnano4k.cst) — ou seja, é o que o Gowin EDA vai gravar em cada pino físico do chip. Placas Sipeed normalmente imprimem esse mesmo número ao lado de cada furo do header, mas **confirme visualmente no silk-screen da sua placa** (ou no pinout oficial em `wiki.sipeed.com/hardware/en/tang/Tang-Nano-4K/Nano-4K.html`) antes de encostar um jumper — eu não tenho como validar fisicamente isso por aqui.
- **Nunca junte VCC de uma placa com VCC da outra.** As duas placas são alimentadas cada uma pela sua própria USB; a única conexão elétrica direta entre elas deve ser os fios de sinal (`sclk`, `cs_n`, `mosi`, `miso`) e o **GND comum**.

---

## 1. Lista de materiais (BOM)

| Qtd | Item | Observação |
|---|---|---|
| 1 | Tang Nano 4K (Sipeed) | FPGA GW1NSR-LV4C |
| 1 | Raspberry Pi Zero 2W | com Raspberry Pi OS **64 bits** instalado no cartão SD |
| 1 | Protoboard | tamanho médio — vai acomodar o sensor e os 5 LEDs de uma vez |
| 1 | Cabo USB-C | alimenta a Tang Nano 4K |
| 1 | Cabo micro-USB | alimenta a Raspberry Pi Zero 2W |
| ~10-15 | Jumpers macho-macho | ligações dentro da protoboard |
| ~6 | Jumpers macho-fêmea | Raspberry Pi (fêmea no header) ↔ protoboard (macho) |
| 5 | Resistor 220 Ω | limitador de corrente de cada LED |
| 2 | LED vermelho | 1 para carro, 1 para pedestre |
| 1 | LED amarelo | carro |
| 2 | LED verde | 1 para carro, 1 para pedestre |
| 1 | Sensor de obstáculo IR (saída digital 3,3V) | módulo com VCC/GND/OUT (tipo comparador, já com LED indicador embutido) |

> Não há botão nem resistor de pull-down na lista: o botão de pedestre e o reset usam os **dois botões onboard já soldados na Tang Nano 4K** (`S1`/`S2`), ver seção 2 — nada de externo precisa ser montado pra eles.

---

## 2. Mapa de pinos — lado Tang Nano 4K

Direto de `constraints/tangnano4k.cst`:

| Sinal do projeto | Pino (chip Gowin) | Direção | Pull interno configurado |
|---|---|---|---|
| `clk` | 45 | entrada | — (oscilador onboard de 27 MHz, ver nota abaixo) |
| `rst_n` | 15 | entrada | pull-up (ativo em nível baixo) — botão onboard `S2`, ver nota abaixo |
| `sensor_raw` | 28 | entrada | pull-up — ativo em nível **baixo** (sensor IR tipo FC-51), ver nota abaixo |
| `botao_raw` | 14 | entrada | pull-up — botão onboard `S1`, ativo em nível **baixo**, ver nota abaixo |
| `led_vermelho` | 31 | saída | drive 8mA |
| `led_amarelo` | 32 | saída | drive 8mA |
| `led_verde` | 33 | saída | drive 8mA |
| `led_ped_verde` | 34 | saída | drive 8mA |
| `led_ped_vermelho` | 35 | saída | drive 8mA |
| `sclk` | 39 | entrada (vem do ARM) | pull-down |
| `cs_n` | 40 | entrada (vem do ARM) | pull-up |
| `mosi` | 41 | entrada (vem do ARM) | pull-down |
| `miso` | 42 | saída (vai pro ARM) | drive 8mA, alta impedância quando `cs_n=1` |
| `busy` | 43 | saída (vai pro ARM) | drive 8mA — não usado pelo software (ver `asm/lib/protocolo_serial_gpio.s`) |

**Nota sobre `clk` (pino 45):** confirmado pelo exemplo oficial da Sipeed (`github.com/sipeed/TangNano-4K-example`, projeto `key_blink`) — esse é o pino real do oscilador onboard de 27 MHz.

**Nota sobre `botao_raw` (pino 14) e `rst_n` (pino 15) — botões onboard, não fiação externa:** conferi o esquemático oficial da Sipeed e os pinos 14 e 15 do chip são exatamente onde estão soldados os **dois botões onboard da placa** (`S1`/`S2`, redes `KEY1`/`KEY2`), cada um já com pull-up de ~100kΩ pro 3,3V (repouso = nível alto, apertado = nível baixo). O projeto usa exatamente esses dois botões de propósito geral: `S1` (pino 14) é o botão de pedestre e `S2` (pino 15) é o reset manual — **não há nada pra montar na protoboard pra esses dois sinais**, só apertar os botões físicos que já existem na própria Tang Nano. Em `rtl/top_semaforo.v`, `botao_raw` (e também `sensor_raw`) chegam invertidos (`~botao_raw`) antes de entrar em `botao_pedestre.v`, porque esses módulos internos esperam repouso baixo/evento alto — a inversão compensa o nível ativo-baixo do botão onboard e do sensor.

**Nota sobre `sensor_raw` (pino 28) — ativo em nível baixo:** o sensor de obstáculo IR usado (tipo FC-51) mantém a saída em nível alto em repouso e desce pra nível baixo quando detecta um obstáculo — por isso o `.cst` configura `PULL_MODE=UP` (e não pull-down) nesse pino, e `top_semaforo.v` inverte o sinal (`~sensor_raw`) internamente antes de repassar pra `sensor_veiculo.v`. A fiação física (seção 4.1) não muda por causa disso — é só lógica interna.

---

## 3. Mapa de pinos — lado Raspberry Pi Zero 2W

Usado só para o link serial com a FPGA (numeração BCM, pino físico do conector de 40 vias — este eu confirmo com total certeza, é o header padrão de todo Raspberry Pi):

| Sinal | GPIO (BCM) | Pino físico |
|---|---|---|
| `sclk` | GPIO11 | 23 |
| `cs_n` | GPIO6 | 31 |
| `mosi` | GPIO10 | 19 |
| `miso` | GPIO20 | 38 |
| GND | — | 39 |

Esses 4 pinos + GND são exatamente os usados por `asm/monitor_semaforo_hw.s` / `asm/lib/protocolo_serial_gpio.s`. O sensor IR e o botão **não** vão na Raspberry Pi — eles ligam direto na FPGA (é ela quem lê e decide tudo, por design do projeto).

---

## 4. Montagem na protoboard — periféricos da FPGA

Monte esta parte **antes** de ligar qualquer fio na Raspberry Pi. Assim você já consegue testar o semáforo funcionando sozinho (botão + sensor + LEDs), só com a Tang Nano ligada na USB, sem depender do ARM — é exatamente o comportamento de segurança que o projeto garante por design.

### 4.1 Sensor de obstáculo IR (veículo)

Módulo de 3 pinos (`VCC`, `GND`, `OUT`):

```
Tang Nano 4K                Sensor IR
  3V3   ───────────────────  VCC
  GND   ───────────────────  GND
  pino 28 (sensor_raw) ────  OUT
```

Não precisa de resistor — o módulo já entrega saída digital 3,3V pronta. Lembre-se: em repouso o `OUT` fica em nível alto e cai pra nível baixo quando detecta um obstáculo (ver nota da seção 2) — a FPGA já compensa isso internamente, você só liga os 3 fios.

### 4.2 Botão de pedestre e reset — nada a montar

Diferente de uma revisão anterior deste guia, **o botão de pedestre não é mais um componente da protoboard**. O projeto usa os dois botões táteis que já vêm soldados na própria placa Tang Nano 4K:

| Botão onboard | Pino do chip | Função no projeto |
|---|---|---|
| `S1` | 14 | Solicitação de pedestre (`botao_raw`) |
| `S2` | 15 | Reset manual (`rst_n`) |

Não há fiação, resistor de pull-down nem componente externo para esses dois sinais — só aperte o botão `S1` na própria Tang Nano para solicitar a travessia do pedestre, e `S2` para resetar a FSM manualmente. Confira no silk-screen da sua placa qual botão físico corresponde a cada rede (`KEY1`=`S1`=pino 14, `KEY2`=`S2`=pino 15) antes de assumir a posição.

### 4.3 Os 5 LEDs (cada um com resistor de 220 Ω em série)

Repita este padrão para cada um dos 5 LEDs, trocando o pino de origem:

```
pino da FPGA ──[220 Ω]──►|── GND
                        LED (ânodo do lado do resistor,
                             cátodo do lado do GND)
```

| LED | Pino FPGA | Cor |
|---|---|---|
| Carro — vermelho | 31 | vermelho |
| Carro — amarelo | 32 | amarelo |
| Carro — verde | 33 | verde |
| Pedestre — verde | 34 | verde |
| Pedestre — vermelho | 35 | vermelho |

Confira a polaridade do LED antes de encaixar: o cátodo (perna mais curta / lado com o corte reto no corpo do LED) vai para o GND.

### 4.4 Checkpoint — teste isolado da FPGA

Com o sensor e os 5 LEDs montados na protoboard (o botão de pedestre e o reset já estão prontos, são os onboard `S1`/`S2` da seção 4.2), grave o bitstream (seção 10 do `CONTEXTO_PROJETO_SEMAFORO_INTELIGENTE.md`) e ligue **só** a Tang Nano na USB-C. Teste:

- Ao ligar: LED verde de carro aceso, vermelho de pedestre aceso, os outros apagados.
- Aperte o botão onboard `S1` (pedestre): depois do tempo mínimo de verde (10 segundos reais por padrão — graças ao prescaler de `rtl/prescaler.v`, que converte os ciclos internos de clock em ticks de 1 segundo; antes dessa extensão isso durava ~370 ns, rápido demais pra perceber a olho nu), o semáforo deve ciclar carro-verde (10s) → carro-amarelo (3s) → pedestre-verde (15s) → volta pro carro-verde sozinho, visivelmente.
- Passe a mão na frente do sensor IR repetidamente (simulando vários "veículos") **antes** de apertar o botão: isso deve, na próxima vez que abrir pro carro, mudar a duração real da fase verde (5s se não passou nada recentemente, 20s se passou bastante — lembrando que essa decisão só é tomada no instante em que a fase de verde começa, não durante ela, ver `CONTEXTO_PROJETO_SEMAFORO_INTELIGENTE.md` seção 6).

Se isso já funciona, a FPGA está 100% operacional **independente da Raspberry Pi** — exatamente o comportamento de segurança que o projeto garante.

---

## 5. Conexão serial — Raspberry Pi ↔ Tang Nano 4K

Só depois do checkpoint acima. Com as duas placas **desligadas da USB**, ligue:

| Da Raspberry Pi (pino físico) | Para a Tang Nano 4K (pino do chip) | Sinal |
|---|---|---|
| 23 (GPIO11) | 39 | `sclk` |
| 31 (GPIO6) | 40 | `cs_n` |
| 19 (GPIO10) | 41 | `mosi` |
| 38 (GPIO20) | 42 | `miso` |
| 39 (GND) | qualquer pino GND da Tang Nano | GND comum |

```
Raspberry Pi Zero 2W          Tang Nano 4K
  GPIO11 (pino 23) ─────────── pino 39 (sclk)
  GPIO6  (pino 31) ─────────── pino 40 (cs_n)
  GPIO10 (pino 19) ─────────── pino 41 (mosi)
  GPIO20 (pino 38) ─────────── pino 42 (miso)
  GND    (pino 39) ─────────── qualquer GND
```

Não conecte `busy` (pino 43 da FPGA) a nada — o driver em `asm/lib/protocolo_serial_gpio.s` não usa esse sinal (o pulso dele dura só ~37 ns, curto demais pra software conseguir ler; veja o comentário no topo desse arquivo).

Como as duas placas são 3,3V, a ligação é direta — **sem** conversor de nível.

Depois de conferir a fiação, ligue as duas USBs (pode ser em qualquer ordem) e siga para a seção 6.

---

## 6. Rodando o software

### 6.1 Gravar a FPGA

Gowin EDA → projeto para `GW1NSR-LV4C QFN48P` → adicionar tudo de `rtl/` + `constraints/tangnano4k.cst` → Synthesize → Place & Route → Program Device.

### 6.2 Montar e rodar o Assembly na Raspberry Pi

Copie a pasta `final_project/` inteira para a Raspberry Pi (scp, git clone, pendrive — o que for mais fácil) e, dentro dela:

```bash
make asm
sudo ./build/monitor_semaforo_hw
```

O `sudo` é necessário aqui porque este programa abre `/dev/gpiomem` de verdade para controlar os 4 pinos físicos do protocolo serial. Ele vai imprimir 20 linhas (1 por segundo) com a telemetria **real** lida da FPGA — fase atual do semáforo de carros + contagem regressiva — e terminar sozinho.

Se você rodar sem a Tang Nano conectada (ou sem `sudo`), o programa não trava: ele só cai automaticamente no modo simulado e imprime telemetria zerada o tempo todo — é assim que você distingue "está lendo hardware de verdade" de "não está conectado direito".

---

## 7. Checklist de verificação rápida

- [ ] Sensor IR: `VCC`→3V3, `GND`→GND, `OUT`→pino 28
- [ ] Nenhuma fiação externa para pedestre/reset — usar os botões onboard `S1` (pino 14) e `S2` (pino 15) da Tang Nano
- [ ] 5 LEDs, cada um com resistor de 220 Ω, nos pinos 31/32/33/34/35
- [ ] FPGA testada sozinha (checkpoint da seção 4.4) antes de ligar a Raspberry Pi
- [ ] GND comum entre as duas placas conectado
- [ ] `sclk`/`cs_n`/`mosi`/`miso` ligados conforme a tabela da seção 5 (sem inverter nenhum)
- [ ] `busy` (pino 43) deixado sem conexão
- [ ] `make asm` roda sem erro na Raspberry Pi
- [ ] `sudo ./build/monitor_semaforo_hw` imprime telemetria variando (não fica travado em zero) — sinal de que está lendo a FPGA de verdade

---

## 8. Problemas comuns

| Sintoma | Causa provável |
|---|---|
| Telemetria sempre `0` mesmo com a Tang Nano ligada | Rodou sem `sudo` (caiu no modo simulado), ou `sclk`/`mosi`/`miso` trocados entre si, ou GND não está comum entre as placas |
| LEDs não acendem nem depois de gravar o bitstream | Confira a orientação dos LEDs (cátodo pro GND) e se os pinos batem com a tabela da seção 2 |
| Botão `S1` não muda nada | Confira se o `.cst` gravado realmente tem `botao_raw` no pino 14 (onboard `S1`) e se você está apertando o botão físico certo (não `S2`, que é o reset) |
| FPGA não reconhecida pelo Gowin EDA / não grava | Problema de driver USB ou cabo USB-C só de alimentação (sem dados) — troque o cabo |
| Programa Assembly dá "Permission denied" ao rodar | Faltou `sudo` (necessário pra abrir `/dev/gpiomem`) |
