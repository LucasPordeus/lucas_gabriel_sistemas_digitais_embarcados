# Por que a FPGA não depende da Raspberry Pi

**A FPGA decide e age; a Raspberry Pi só observa.**

## A FPGA é autônoma

1. **Tempos fixos no projeto.** Verde (5/10/20 s, conforme o fluxo), amarelo
   (3 s), travessia (15 s) e os limiares de fluxo são parâmetros de
   [`rtl/top_semaforo.v`](rtl/top_semaforo.v). Já valem desde o reset e não
   existe registrador que outra placa possa alterar.
2. **Decisão interna a cada ciclo.** [`rtl/fsm_semaforo.v`](rtl/fsm_semaforo.v)
   usa só o pedido do botão, o contador da fase e o tempo de verde vindo do
   fluxo medido. Nada no código consulta a Raspberry.
3. **Link só de saída.** [`rtl/protocolo_serial.v`](rtl/protocolo_serial.v)
   não tem entrada de dados. `sclk` e `cs_n` apenas definem quando a FPGA
   envia o quadro de telemetria, e não existe comando que mude o semáforo.

Se a Raspberry travar, for desligada ou o cabo soltar, o semáforo continua
igual. O monitor passa a mostrar `QUADRO INVALIDO` (sem conexão) ou para de
imprimir, e só isso.

## O que a Raspberry Pi faz

| Programa | Função | Essencial para o semáforo? |
|---|---|---|
| `asm/monitor_semaforo.s` | lê a telemetria 1×/s e imprime cor dos carros, cor do pedestre, tempo restante, fluxo e pedido | não, é só visualização |

## Recursos dedicados da FPGA

- **BSRAM** (`bram_historico.v`): guarda a contagem de veículos de cada janela
  de 10 s. O filtro lê dela a amostra que sai da média.
- **DSP MULT18X18** (`media_movel_dsp.v`): divide por 5 multiplicando pelo
  recíproco em ponto fixo.
- **PLL: não é usado.** O sistema roda direto nos 27 MHz do oscilador, que é
  ~7× abaixo da frequência máxima obtida no place & route (198 MHz). Toda a
  temporização em segundos vem de um divisor digital (`prescaler.v`).
