# Guia de Montagem Física — Semáforo Inteligente (Tang Nano 4K + Raspberry Pi)

Como montar o circuito, ligar as duas placas e validar o sistema na placa
real. A pinagem é a de [`constraints/tangnano4k.cst`](constraints/tangnano4k.cst).

---

## 0. Segurança elétrica

- Monte tudo com as **duas placas desligadas da USB**.
- Os bancos de I/O da Tang Nano 4K têm tensões diferentes (pinout oficial da
  Sipeed): **banco 0 = 3,3 V, banco 1 = 3,3 V, banco 2 = 2,5 V (HDMI),
  banco 3 = 1,8 V (botões)**. Sinais de 3,3 V vindos de fora (sensor IR e
  Raspberry Pi) entram **só** nos pinos 39, 40 e 42, todos do banco 1.
- Nunca ligue 5 V em pinos de sinal.
- Não junte o VCC de uma placa com o da outra. Entre as placas vão só
  `sclk`, `cs_n`, `miso` e o **GND comum**.
- Não use os pinos 1–4, 6–9, 47 e 48 (flash, JTAG e DONE).

---

## 1. Lista de materiais

| Qtd | Item | Observação |
|---|---|---|
| 1 | Tang Nano 4K | FPGA GW1NSR-LV4C |
| 1 | Raspberry Pi Zero 2W | Raspberry Pi OS **64 bits** |
| 1 | Protoboard | |
| ~10 | Jumpers macho-macho | |
| ~4 | Jumpers macho-fêmea | header da Raspberry → protoboard |
| 5 | Resistor 220 Ω | um por LED |
| 2 | LED vermelho | carro e pedestre |
| 1 | LED amarelo | carro |
| 2 | LED verde | carro e pedestre |
| 1 | Sensor IR de obstáculo (tipo FC-51) | VCC/GND/OUT; OUT = 0 com obstáculo |

O botão de pedestre e o reset são os botões **S1** e **S2** da própria Tang
Nano 4K.

---

## 2. Pinos da Tang Nano 4K

| Sinal | Pino | Banco | Direção | Configuração |
|---|---|---|---|---|
| `clk` | 45 | 1 (3,3 V) | entrada | oscilador de 27 MHz da placa |
| `rst_n` | 15 | 3 (1,8 V) | entrada | botão **S2** (USR_KEY_2), 0 = reset |
| `botao_raw` | 14 | 3 (1,8 V) | entrada | botão **S1** (USR_KEY_1), 0 = pedido |
| `sensor_raw` | 39 | 1 (3,3 V) | entrada | pull-up, 0 = veículo |
| `led_vermelho` | 41 | 1 (3,3 V) | saída | carro vermelho |
| `led_amarelo` | 43 | 1 (3,3 V) | saída | carro amarelo |
| `led_verde` | 44 | 1 (3,3 V) | saída | carro verde |
| `led_ped_verde` | 46 | 1 (3,3 V) | saída | pedestre verde |
| `led_ped_vermelho` | 10 | 0 (3,3 V) | saída | pedestre vermelho (também é o pino do LED da placa) |
| `sclk` | 40 | 1 (3,3 V) | entrada | vem do GPIO11, pull-down |
| `cs_n` | 42 | 1 (3,3 V) | entrada | vem do GPIO6, pull-up |
| `miso` | 33 | 2 (2,5 V) | saída | vai para o GPIO20; nível alto = 2,5 V |

Por que estes pinos:

- A versão anterior usava os pinos 28 e 31–35. Eles ficam no **banco 2
  (2,5 V)** e são as linhas do HDMI, que têm pull-ups externos na placa. O
  sensor de 3,3 V nesse banco ficava acima da tensão do banco, e os LEDs
  ficavam fracos.
- O banco 1 tem apenas 7 pinos livres de 3,3 V (39–44 e 46). Eles vão para as
  3 entradas de 3,3 V e para 4 LEDs. O 5º LED vai no pino 10 (banco 0).
- O `miso` é a única saída que sobra. Ele fica no pino 33 (banco 2, livre
  quando não há câmera conectada). A Raspberry lê 2,5 V como nível alto.
- Os pinos 39–46 também vão para o conector de câmera. **Não conecte câmera.**

---

## 3. Pinos da Raspberry Pi Zero 2W

| Sinal | GPIO (BCM) | Pino físico |
|---|---|---|
| `sclk` | GPIO11 | 23 |
| `cs_n` | GPIO6 | 31 |
| `miso` | GPIO20 | 38 |
| GND | — | 39 |

---

## 4. Montagem dos periféricos da FPGA

### 4.1 Sensor IR

```
Tang Nano 4K           Sensor IR
  3V3  ──────────────  VCC
  GND  ──────────────  GND
  pino 39 ───────────  OUT
```

Ajuste o trimpot do sensor até o LED dele acender só com um objeto a poucos
centímetros.

### 4.2 LEDs (cada um com 220 Ω em série)

```
pino da FPGA ──[220 Ω]──►|── GND      (perna curta do LED no GND)
```

| LED | Pino |
|---|---|
| Carro vermelho | 41 |
| Carro amarelo | 43 |
| Carro verde | 44 |
| Pedestre verde | 46 |
| Pedestre vermelho | 10 |

### 4.3 Botões

Não há nada a montar: **S1** (pino 14) pede a travessia e **S2** (pino 15)
reseta.

---

## 5. Ligação com a Raspberry Pi

Com as duas placas desligadas:

```
Raspberry Pi Zero 2W          Tang Nano 4K
  GPIO11 (pino 23) ─────────── pino 40 (sclk)
  GPIO6  (pino 31) ─────────── pino 42 (cs_n)
  GPIO20 (pino 38) ─────────── pino 33 (miso)
  GND    (pino 39) ─────────── GND
```

Sem conversor de nível. Se o SPI do kernel estiver ligado (`dtparam=spi=on`),
o programa reconfigura o GPIO11 como saída comum. Para evitar conflito,
deixe o SPI desligado.

---

## 6. Gravar e rodar

1. **FPGA:** pelo Gowin EDA (projeto `GW1NSR-LV4CQN48PC7/I6`, arquivos
   `rtl/*.v` e `constraints/*`, topo `top_semaforo`), ou com `make synth` e
   gravando `build/top_semaforo.fs` com `openFPGALoader -b tangnano4k`.
2. **Raspberry Pi:** copie a pasta e rode `make asm` e depois `make run`
   (usa `sudo` para abrir `/dev/gpiomem`).

---

## 7. Roteiro de validação na placa

Faça na ordem. Os passos A–E usam só a Tang Nano. Os passos F–H precisam da
Raspberry.

| # | Ação | Resultado esperado |
|---|---|---|
| A | Ligar a Tang Nano | carro **verde** + pedestre **vermelho**; nenhum outro LED |
| B | Não fazer nada por 1 minuto | continua verde (sem pedido não há troca) |
| C | Sem passar nada no sensor por ≥ 50 s, apertar S1 | ~5 s depois: amarelo 3 s → pedestre verde 15 s → volta ao verde |
| D | Passar a mão no sensor ~6 vezes a cada 10 s, por 1 min; depois apertar S1 | ~20 s até o amarelo |
| E | Apertar S2 em qualquer fase | volta para carro verde + pedestre vermelho |
| F | Rodar `make run` | uma linha por segundo; `carros=` e `pedestres=` sempre iguais aos LEDs |
| G | Repetir C e D com o monitor rodando | `pedido=SIM` após o aperto; `fluxo=` vai a `ALTO` no passo D; `restante=` conta para baixo |
| H | Desconectar o fio do `miso` | `QUADRO INVALIDO`; o semáforo continua funcionando igual |

Durante todo o roteiro, confirme que **o pedestre verde nunca acende junto com
o verde ou o amarelo dos carros**. Para testar estabilidade, deixe o sistema
rodando ~30 min com o monitor ligado: não deve aparecer `QUADRO INVALIDO` com a
fiação correta.

---

## 8. Problemas comuns

| Sintoma | Causa provável |
|---|---|
| `QUADRO INVALIDO` o tempo todo | fio de `miso`/`sclk`/`cs_n` trocado ou solto, falta GND comum, FPGA não gravada |
| `ERRO: nao foi possivel mapear /dev/gpiomem` | rodou sem `sudo` ou fora da Raspberry Pi |
| LED não acende | LED invertido, ou pino errado (confira a tabela da seção 2) |
| Fluxo nunca sai de `BAIXO` | sensor desajustado: o LED do próprio sensor precisa piscar a cada passagem |
| S1 não faz nada | apertou S2 (reset), ou o verde mínimo ainda não acabou (até 20 s com fluxo alto) |
| LED da placa (pino 10) acende ao contrário do LED externo | normal: o LED da placa pode ser ativo em nível baixo |
