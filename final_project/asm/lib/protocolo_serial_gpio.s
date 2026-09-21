// protocolo_serial_gpio.s - AArch64 (GAS)
// Driver de GPIO bit-banged do protocolo serial ARM<->FPGA (equivalente a
// SPI modo CPOL=0/CPHA=0), deduzido da logica de protocolo_serial.v:
//   - com cs_n=1 (fora do quadro), a FPGA mantem miso estavel no bit mais
//     significativo da telemetria atual;
//   - a cada borda de SUBIDA de sclk, a FPGA amostra mosi e desloca miso
//     para o proximo bit -- cada bit de miso deve ser LIDO ANTES de subir
//     sclk, nao depois;
//   - MSB primeiro, 8 bits por quadro, em ambas as direcoes.
//
// Nao usa o sinal "busy": o pulso dura 1 ciclo de clock da FPGA (~37 ns),
// curto demais para polling confiavel em software de espaco de usuario.

    .text
    .global protocolo_serial_configura_pinos
    .global protocolo_serial_transfere

GPSET0_OFF   = 0x1C
GPCLR0_OFF   = 0x28
GPLEV0_OFF   = 0x34
// ATRASO_ITER: iteracoes de espera entre transicoes de pino. 20000 da'
// SCLK na faixa de ~10-20 kHz, bem abaixo da frequencia onde fios soltos
// de protoboard costumam sofrer ringing/crosstalk (sem custo, ja que so'
// fazemos 1 transferencia por segundo).
ATRASO_ITER  = 20000

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
