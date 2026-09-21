# Guia de Montagem Física — Semáforo Inteligente (FPGA + Raspberry Pi)

> Passo a passo para montar o circuito na protoboard e conectar a
> **Tang Nano 4K** (FPGA) com a **Raspberry Pi Zero 2W**, usando os
> componentes físicos do projeto: protoboard, jumpers, resistores, LEDs,
> botão e sensor IR.
>
> Este guia cobre só a **montagem física**. Para compilar/gravar o
> Verilog e montar/rodar o Assembly, veja a seção 10 do

---

## 0. Antes de começar — segurança elétrica

- **Desligue (desconecte da USB) as duas placas antes de mexer em qualquer fio.** Só ligue a alimentação depois que toda a fiação estiver conferida.
- As duas placas trabalham em **3,3V**. Não ligue nada em 5V nos pinos de sinal (sensor, botão, LEDs, protocolo serial) — o GW1NSR-LV4C da Tang Nano **não é tolerante a 5V** e queima com facilidade.
- Os números de pino usados abaixo (`45`, `28`, `29`, `12`, `13`, `16`, `18`, `19`, `39`-`43`) são os mesmos declarados em [`constraints/tangnano4k.cst`](constraints/tangnano4k.cst) — ou seja, é o que o Gowin EDA vai gravar em cada pino físico do chip. Placas Sipeed normalmente imprimem esse mesmo número ao lado de cada furo do header, mas **confirme visualmente no silk-screen da sua placa** (ou no pinout oficial em `wiki.sipeed.com/hardware/en/tang/Tang-Nano-4K/Nano-4K.html`) antes de encostar um jumper — eu não tenho como validar fisicamente isso por aqui.
- **Nunca junte VCC de uma placa com VCC da outra.** As duas placas são alimentadas cada uma pela sua própria USB; a única conexão elétrica direta entre elas deve ser os fios de sinal (`sclk`, `cs_n`, `mosi`, `miso`) e o **GND comum**.

---

## 1. Lista de materiais (BOM)

| Qtd | Item | Observação |
|---|---|---|
| 1 | Tang Nano 4K (Sipeed) | FPGA GW1NSR-LV4C |
| 1 | Raspberry Pi Zero 2W | com Raspberry Pi OS **64 bits** instalado no cartão SD |
| 1 | Protoboard | tamanho médio/grande — vai acomodar sensor, botão e 5 LEDs de uma vez |
| 1 | Cabo USB-C | alimenta a Tang Nano 4K |
| 1 | Cabo micro-USB | alimenta a Raspberry Pi Zero 2W |
| ~15-20 | Jumpers macho-macho | ligações dentro da protoboard |
| ~6 | Jumpers macho-fêmea | Raspberry Pi (fêmea no header) ↔ protoboard (macho) |
| 5 | Resistor 220 Ω | limitador de corrente de cada LED |
| 1 | Resistor 10 kΩ | pull-down do botão de pedestre |
| 2 | LED vermelho | 1 para carro, 1 para pedestre |
| 1 | LED amarelo | carro |
| 2 | LED verde | 1 para carro, 1 para pedestre |
| 1 | Botão de pedestre (push-button) | tátil, 4 pinos ou 2 pinos |
| 1 | Sensor de obstáculo IR (saída digital 3,3V) | módulo com VCC/GND/OUT (tipo comparador, já com LED indicador embutido) |

---

## 2. Mapa de pinos — lado Tang Nano 4K

Direto de `constraints/tangnano4k.cst`:

| Sinal do projeto | Pino (chip Gowin) | Direção | Pull interno configurado |
|---|---|---|---|
| `clk` | 45 | entrada | — (oscilador onboard de 27 MHz, ver nota abaixo) |
| `rst_n` | (sem pino fixo) | entrada | pull-up (ativo em nível baixo) — Gowin escolhe o pino livre sozinho no Place & Route, ver nota abaixo |
| `sensor_raw` | 28 | entrada | pull-down |
| `botao_raw` | 29 | entrada | pull-down |
| `led_vermelho` | 16 | saída | drive 8mA |
| `led_amarelo` | 19 | saída | drive 8mA |
| `led_verde` | 18 | saída | drive 8mA |
| `led_ped_verde` | 13 | saída | drive 8mA |
| `led_ped_vermelho` | 12 | saída | drive 8mA |
| `sclk` | 39 | entrada (vem do ARM) | pull-down |
| `cs_n` | 40 | entrada (vem do ARM) | pull-up |
| `mosi` | 41 | entrada (vem do ARM) | pull-down |
| `miso` | 42 | saída (vai pro ARM) | drive 8mA, alta impedância quando `cs_n=1` |
| `busy` | 43 | saída (vai pro ARM) | drive 8mA — não usado pelo software (ver `asm/lib/protocolo_serial_gpio.s`) |

**Por que `led_verde`/`led_amarelo` estão em 18/19 e não em 14/15:** conferi o esquemático oficial da Sipeed e os pinos 14 e 15 do chip são exatamente onde estão soldados os **dois botões onboard da placa** (`S1`/`S2`, redes `KEY1`/`KEY2`, cada um com pull-up de ~100kΩ pro 3,3V). Usar 14/15 pra LED colidiria eletricamente com esses botões — por isso o `.cst` usa 18/19 (`IOB13A`/`IOB13B`) pros LEDs de verde/amarelo do carro, que não aparecem com nenhuma função especial no esquemático. `botao_raw` (o botão externo da protoboard) também evita 14/15 pelo mesmo motivo — está no pino 29.

**Nota sobre `clk` (pino 45):** confirmado pelo exemplo oficial da Sipeed (`github.com/sipeed/TangNano-4K-example`, projeto `key_blink`) — esse é o pino real do oscilador onboard de 27 MHz. O pino 27, usado até uma revisão anterior deste guia, **nunca foi o oscilador de verdade** — era a causa raiz de o projeto nunca avançar sozinho, com ou sem botão.

**Nota sobre `rst_n` (sem pino fixo):** não existe um botão de reset onboard pré-ligado nessa placa — os dois botões físicos (`S1`/`S2`) são de uso geral, ligados nos pinos 14/15 (ver nota acima), sem relação com `rst_n`. O pino 17 (usado antes) cai num banco elétrico travado em 1,8V, incompatível com o padrão 3,3V do resto do projeto — tentar usá-lo dá erro de síntese no Gowin (`CT1136`). Por isso o `.cst` não atribui nenhum pino fixo a `rst_n`: o Gowin escolhe um pino livre e compatível sozinho durante o Place & Route (mesmo padrão do exemplo oficial da Sipeed). Como nada externo precisa controlar esse sinal, o pull-up interno já garante repouso (inativo) sozinho, sem fiação nenhuma. Se você quiser um botão de reset manual, primeiro rode Place & Route, veja no relatório de pinos gerado qual pino o Gowin escolheu pra `rst_n`, e ligue um botão desse pino direto pro GND (sem resistor, o pull-up já está configurado).

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

Não precisa de resistor — o módulo já entrega saída digital 3,3V pronta.

### 4.2 Botão de pedestre (com pull-down de 10 kΩ)

```
                    3V3 (Tang Nano)
                     │
                    [botão]
                     │
   pino 29 ──────────┼──────── (botao_raw)
                     │
                   [10 kΩ]
                     │
                    GND
```

Ou seja: um lado do botão vai no 3V3, o outro lado vai no pino `29` **e** num resistor de 10 kΩ que desce pro GND. Em repouso (botão solto) o pino fica em nível baixo (puxado pelo resistor); ao apertar, o pino vai a nível alto — é essa borda de subida que `botao_pedestre.v` detecta.

### 4.3 Os 5 LEDs (cada um com resistor de 220 Ω em série)

Repita este padrão para cada um dos 5 LEDs, trocando o pino de origem:

```
pino da FPGA ──[220 Ω]──►|── GND
                        LED (ânodo do lado do resistor,
                             cátodo do lado do GND)
```

| LED | Pino FPGA | Cor |
|---|---|---|
| Carro — vermelho | 16 | vermelho |
| Carro — amarelo | 19 | amarelo |
| Carro — verde | 18 | verde |
| Pedestre — verde | 13 | verde |
| Pedestre — vermelho | 12 | vermelho |

Confira a polaridade do LED antes de encaixar: o cátodo (perna mais curta / lado com o corte reto no corpo do LED) vai para o GND.

### 4.4 Checkpoint — teste isolado da FPGA

Com o sensor, o botão e os 5 LEDs montados, grave o bitstream (seção 10 do `CONTEXTO_PROJETO_SEMAFORO_INTELIGENTE.md`) e ligue **só** a Tang Nano na USB-C. Teste:

- Ao ligar: LED verde de carro aceso, vermelho de pedestre aceso, os outros apagados.
- Aperte o botão de pedestre: depois do tempo mínimo de verde (10 segundos reais por padrão — graças ao prescaler de `rtl/prescaler.v`, que converte os ciclos internos de clock em ticks de 1 segundo; antes dessa extensão isso durava ~370 ns, rápido demais pra perceber a olho nu), o semáforo deve ciclar carro-verde (10s) → carro-amarelo (3s) → pedestre-verde (15s) → volta pro carro-verde sozinho, visivelmente.
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

### 6.1 Gravar a FPGA (se ainda não fez)

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
- [ ] Botão: 3V3 → botão → pino 29 → resistor 10 kΩ → GND
- [ ] 5 LEDs, cada um com resistor de 220 Ω, nos pinos 12/13/16/18/19
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
| Botão não muda nada | Confira o resistor de pull-down (sem ele o pino fica flutuando e o debounce nunca vê uma borda limpa), e se o `.cst` gravado realmente tem `botao_raw` no pino 29 |
| FPGA não reconhecida pelo Gowin EDA / não grava | Problema de driver USB ou cabo USB-C só de alimentação (sem dados) — troque o cabo |
| Programa Assembly dá "Permission denied" ao rodar | Faltou `sudo` (necessário pra abrir `/dev/gpiomem`) |
