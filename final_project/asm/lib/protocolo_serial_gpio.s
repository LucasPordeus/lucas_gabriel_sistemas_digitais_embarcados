// protocolo_serial_gpio.s - lado Raspberry Pi do link de telemetria com a
// FPGA (rtl/protocolo_serial.v), feito por bit-banging de GPIO. A Raspberry
// e' o mestre e so' le: gera cs_n e sclk e recebe 16 bits em miso.
//
// Sequencia de um quadro (SPI modo 0, MSB primeiro):
//   cs_n = 0 (a FPGA congela o quadro e ja coloca o bit 15 em miso)
//   16 vezes: le miso; sclk = 1 (a FPGA avanca para o proximo bit); sclk = 0
//   cs_n = 1
//
//   protocolo_serial_configura_pinos(x0=base, w1=sclk, w2=cs_n, w3=miso)
//       sclk e cs_n como saida, miso como entrada; repouso: cs_n = 1, sclk = 0
//   protocolo_serial_le_quadro(x0=base, w1=sclk, w2=cs_n, w3=miso)
//       -> w0 = quadro de 16 bits recebido

// iteracoes do atraso entre mudancas de pino (dezenas de microssegundos):
// muito acima dos ~150 ns que a FPGA leva para sincronizar e reagir
ATRASO_ITER = 20000

    .text
    .global protocolo_serial_configura_pinos
    .global protocolo_serial_le_quadro

// ---- protocolo_serial_configura_pinos ----
protocolo_serial_configura_pinos:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x19, x0                    // base dos registradores de GPIO
    mov     w20, w1                    // pino sclk
    mov     w21, w2                    // pino cs_n
    mov     w22, w3                    // pino miso

    mov     x0, x19
    mov     w1, w21
    mov     w2, #1
    bl      gpio_escreve               // cs_n = 1 antes de virar saida (sem quadro falso)
    mov     x0, x19
    mov     w1, w20
    mov     w2, #0
    bl      gpio_escreve               // sclk = 0

    mov     x0, x19
    mov     w1, w20
    mov     w2, #1
    bl      gpio_configura_pino        // sclk = saida
    mov     x0, x19
    mov     w1, w21
    mov     w2, #1
    bl      gpio_configura_pino        // cs_n = saida
    mov     x0, x19
    mov     w1, w22
    mov     w2, #0
    bl      gpio_configura_pino        // miso = entrada

    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ---- protocolo_serial_le_quadro ----
protocolo_serial_le_quadro:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    mov     x19, x0                    // base dos registradores de GPIO
    mov     w20, w1                    // pino sclk
    mov     w21, w2                    // pino cs_n
    mov     w22, w3                    // pino miso
    mov     w23, #0                    // quadro sendo montado
    mov     w24, #16                   // bits que faltam receber

    mov     x0, x19
    mov     w1, w21
    mov     w2, #0
    bl      gpio_escreve               // cs_n = 0: inicio do quadro
    bl      atraso

    // um bit por volta; termina quando os 16 bits foram lidos
.Lproximo_bit:
    mov     x0, x19
    mov     w1, w22
    bl      gpio_le                    // w0 = bit atual em miso
    orr     w23, w0, w23, lsl #1

    mov     x0, x19
    mov     w1, w20
    mov     w2, #1
    bl      gpio_escreve               // sclk = 1: FPGA avanca para o proximo bit
    bl      atraso
    mov     x0, x19
    mov     w1, w20
    mov     w2, #0
    bl      gpio_escreve               // sclk = 0
    bl      atraso

    subs    w24, w24, #1
    b.ne    .Lproximo_bit

    mov     x0, x19
    mov     w1, w21
    mov     w2, #1
    bl      gpio_escreve               // cs_n = 1: fim do quadro
    bl      atraso

    and     w0, w23, #0xFFFF
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// espera ocupada de ATRASO_ITER voltas (so' usa w9)
atraso:
    mov     w9, #ATRASO_ITER
1:  subs    w9, w9, #1
    b.ne    1b
    ret
