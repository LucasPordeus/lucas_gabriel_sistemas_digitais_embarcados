// protocolo_serial_gpio.s - AArch64 (GAS)
// Driver de GPIO "bit-banged" (via gpio_lib) que implementa de verdade,
// em hardware real, o mesmo protocolo definido em rtl/protocolo_serial.v
// -- diferente de main_tp5.s/monitor_semaforo.s, que so' simulam o
// round-trip internamente via buffer_lib.s (nao ha nenhum fio fisico
// envolvido naqueles dois).
//
// Timing (equivalente a SPI modo CPOL=0/CPHA=0), deduzido diretamente da
// logica de protocolo_serial.v:
//   - enquanto cs_n=1 (fora do quadro), a FPGA mantem miso estavel no bit
//     mais significativo da telemetria atual;
//   - a cada borda de SUBIDA de sclk, a FPGA amostra mosi e desloca miso
//     para o proximo bit -- ou seja, cada bit de miso deve ser LIDO ANTES
//     de subir sclk, nao depois;
//   - MSB primeiro, 8 bits por quadro, em ambas as direcoes.
//
// AVISO (leia antes de conectar hardware):
//   1) Este arquivo foi montado, linkado (aarch64-linux-gnu-as/ld) e
//      executado via qemu-aarch64 neste ambiente de desenvolvimento para
//      validar a logica de controle (nenhum crash, fluxo correto), mas
//      NAO existe uma Tang Nano 4K fisica conectada aqui -- sem hardware
//      real, gpio_map_init cai no modo simulado (memoria anonima) e os
//      valores lidos/escritos nao correspondem a nenhum sinal eletrico
//      de verdade. A validacao final do timing so' pode ser feita por
//      voce, na Raspberry Pi, com a FPGA de fato conectada.
//   2) O sinal "busy" da FPGA fica em nivel alto por apenas 1 ciclo do
//      clock interno de 27 MHz (~37 ns) -- curto demais para software em
//      espaco de usuario conseguir ler de forma confiavel por polling.
//      Por isso esta implementacao NAO tenta sincronizar via "busy": ela
//      confia que, pela propria logica de protocolo_serial.v, o comando
//      ja foi capturado (comando_recebido/comando_valido) no mesmo ciclo
//      interno em que o 8o bit de sclk e' processado -- ou seja, ao fim
//      dos 8 pulsos de clock o comando ja' foi aplicado.
//   3) LEMBRE-SE de ligar o GND da Raspberry Pi ao GND da Tang Nano 4K
//      (referencia comum) alem dos sinais de dados -- sem isso os niveis
//      logicos de 3,3V nao tem uma referencia confiavel entre as placas.

    .text
    .global protocolo_serial_configura_pinos
    .global protocolo_serial_transfere

GPSET0_OFF   = 0x1C
GPCLR0_OFF   = 0x28
GPLEV0_OFF   = 0x34
ATRASO_ITER  = 200     // folga de sobra: a FPGA roda a 27 MHz (~37 ns/ciclo)

// ---- protocolo_serial_configura_pinos(x0=base,w1=sclk,w2=cs_n,w3=mosi,w4=miso) ----
// Configura sclk/cs_n/mosi como saida e miso como entrada; deixa cs_n em
// repouso (ALTO = fora do quadro) e sclk/mosi em BAIXO.
protocolo_serial_configura_pinos:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    str     x23,      [sp, #48]

    mov     x19, x0            // base
    mov     w20, w1            // pino sclk
    mov     w21, w2            // pino cs_n
    mov     w22, w3            // pino mosi
    mov     w23, w4            // pino miso

    mov     x0, x19
    mov     w1, w20
    mov     w2, #1
    bl      gpio_configura_pino      // sclk = saida

    mov     x0, x19
    mov     w1, w21
    mov     w2, #1
    bl      gpio_configura_pino      // cs_n = saida

    mov     x0, x19
    mov     w1, w22
    mov     w2, #1
    bl      gpio_configura_pino      // mosi = saida

    mov     x0, x19
    mov     w1, w23
    mov     w2, #0
    bl      gpio_configura_pino      // miso = entrada

    mov     x0, x19
    mov     x1, #GPSET0_OFF
    mov     x2, x21
    bl      gpio_set_bit             // cs_n = ALTO (repouso, fora do quadro)

    mov     x0, x19
    mov     x1, #GPCLR0_OFF
    mov     x2, x20
    bl      gpio_clear_bit           // sclk = BAIXO

    mov     x0, x19
    mov     x1, #GPCLR0_OFF
    mov     x2, x22
    bl      gpio_clear_bit           // mosi = BAIXO

    ldr     x23,      [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// ---- protocolo_serial_transfere(x0=base,w1=sclk,w2=cs_n,w3=mosi,w4=miso,w5=byte_comando) ----
// Retorno: w0 = byte de telemetria recebido ([7:6]=fase [5:0]=contagem,
// mesmo formato usado por monitor_semaforo.s / protocolo_serial.v).
protocolo_serial_transfere:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]

    mov     x19, x0        // base
    mov     w20, w1        // pino sclk
    mov     w21, w2        // pino cs_n
    mov     w22, w3        // pino mosi
    mov     w23, w4        // pino miso
    mov     w24, w5        // byte a enviar
    mov     w25, #0        // acumulador do byte recebido
    mov     w26, #0        // contador de bits (0..7)

    mov     x0, x19
    mov     x1, #GPCLR0_OFF
    mov     x2, x21
    bl      gpio_clear_bit           // CS_N = BAIXO (inicio do quadro)
    bl      .Latraso_curto

.Lbit_loop:
    cmp     w26, #8
    b.ge    .Lfim_bits

    // bit a enviar = bit (7 - contador) do byte de comando, MSB primeiro
    mov     w9, #7
    sub     w9, w9, w26
    lsr     w10, w24, w9
    and     w10, w10, #1
    cbz     w10, .Lmosi_zero

    mov     x0, x19
    mov     x1, #GPSET0_OFF
    mov     x2, x22
    bl      gpio_set_bit
    b       .Lmosi_feito
.Lmosi_zero:
    mov     x0, x19
    mov     x1, #GPCLR0_OFF
    mov     x2, x22
    bl      gpio_clear_bit
.Lmosi_feito:
    bl      .Latraso_curto

    // le MISO -- estavel desde a borda anterior, e' o bit que a FPGA
    // preparou ANTES desta subida de SCLK (ver comentario de timing acima)
    mov     x0, x19
    mov     x1, #GPLEV0_OFF
    mov     x2, x23
    bl      gpio_read_bit            // w0 = bit lido
    lsl     w25, w25, #1
    orr     w25, w25, w0

    mov     x0, x19
    mov     x1, #GPSET0_OFF
    mov     x2, x20
    bl      gpio_set_bit             // SCLK = ALTO (borda de subida)
    bl      .Latraso_curto

    mov     x0, x19
    mov     x1, #GPCLR0_OFF
    mov     x2, x20
    bl      gpio_clear_bit           // SCLK = BAIXO
    bl      .Latraso_curto

    add     w26, w26, #1
    b       .Lbit_loop

.Lfim_bits:
    mov     x0, x19
    mov     x1, #GPSET0_OFF
    mov     x2, x21
    bl      gpio_set_bit             // CS_N = ALTO (fim do quadro)
    bl      .Latraso_curto

    and     w0, w25, #0xff

    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// atraso ocupado, nao-preciso: apenas da tempo de acomodacao aos niveis
// eletricos antes/depois de cada mudanca -- a FPGA roda a 27 MHz (periodo
// ~37 ns), entao ATRASO_ITER iteracoes ja' garantem varias ordens de
// magnitude de folga.
.Latraso_curto:
    mov     w6, #ATRASO_ITER
1:  subs    w6, w6, #1
    b.ne    1b
    ret
