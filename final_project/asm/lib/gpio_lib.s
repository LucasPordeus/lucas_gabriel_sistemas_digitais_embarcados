// gpio_lib.s - biblioteca de acesso a GPIO (AArch64 / GAS)
// Funcoes reutilizaveis extraidas de gpio_map.s (TP3), agora organizadas
// como uma biblioteca estatica (libembarcado.a) para uso por qualquer
// programa do projeto. Segue a convencao AAPCS64 (parametros em x0-x7,
// retorno em x0, x19-x28/x29/x30 preservados pelo chamado).
//
//   gpio_map_init()              -> x0 = ponteiro base mapeado (real ou simulado)
//   gpio_set_bit(x0=base,x1=offset,x2=bit)   -> seta o bit "bit" no registrador em offset
//   gpio_clear_bit(x0=base,x1=offset,x2=bit) -> limpa o bit "bit" no registrador em offset
//   gpio_read_bit(x0=base,x1=offset,x2=bit)  -> w0 = valor do bit (0/1)
//   gpio_configura_pino(x0=base,w1=pino,w2=funcao) -> configura GPFSELn
//       (funcao: 0=entrada, 1=saida). Extraida da logica de config_pino de
//       gpio_map.s (TP3) e generalizada para qualquer pino 0-53, usada pelo
//       driver do protocolo serial (ver protocolo_serial_gpio.s).

    .data
caminho_gpiomem: .asciz "/dev/gpiomem"

    .text
    .global gpio_map_init
    .global gpio_set_bit
    .global gpio_clear_bit
    .global gpio_read_bit
    .global gpio_configura_pino

gpio_map_init:
    stp     x29, x30, [sp, #-16]!
    mov     x0, #-100                  // AT_FDCWD
    adrp    x1, caminho_gpiomem
    add     x1, x1, :lo12:caminho_gpiomem
    mov     x2, #2                     // O_RDWR
    mov     x3, #0
    mov     x8, #56                    // openat
    svc     #0
    mov     x9, x0                     // x9 = fd (ou negativo)

    cmp     x9, #0
    b.lt    .Lmapa_simulado

    mov     x0, #0
    mov     x1, #4096
    mov     x2, #3                     // PROT_READ | PROT_WRITE
    mov     x3, #1                     // MAP_SHARED
    mov     x4, x9
    mov     x5, #0
    mov     x8, #222                   // mmap
    svc     #0
    b       .Lmapa_fim

.Lmapa_simulado:
    mov     x0, #0
    mov     x1, #4096
    mov     x2, #3
    mov     x3, #0x22                  // MAP_PRIVATE | MAP_ANONYMOUS
    mov     x4, #-1
    mov     x5, #0
    mov     x8, #222
    svc     #0

.Lmapa_fim:
    ldp     x29, x30, [sp], #16
    ret

gpio_set_bit:
    add     x3, x0, x1
    ldr     w4, [x3]
    mov     w5, #1
    lsl     w5, w5, w2
    orr     w4, w4, w5
    str     w4, [x3]
    ret

gpio_clear_bit:
    add     x3, x0, x1
    ldr     w4, [x3]
    mov     w5, #1
    lsl     w5, w5, w2
    bic     w4, w4, w5
    str     w4, [x3]
    ret

gpio_read_bit:
    add     x3, x0, x1
    ldr     w4, [x3]
    lsr     w4, w4, w2
    and     w0, w4, #1
    ret

// GPFSELn: 10 pinos por registrador, 3 bits cada, registrador n comeca no
// offset n*4 a partir da base (GPFSEL0=0x00, GPFSEL1=0x04, ...). Mesma
// tecnica de bit a bit usada em gpio_map.s, generalizada para qualquer
// pino em vez de fixa em GPIO17.
gpio_configura_pino:
    mov     w9, #10
    udiv    w10, w1, w9           // w10 = pino / 10  (indice do registrador GPFSELn)
    msub    w11, w10, w9, w1      // w11 = pino % 10  (posicao dentro do registrador)
    mov     w12, #3
    mul     w11, w11, w12         // w11 = deslocamento em bits (posicao * 3)

    lsl     w10, w10, #2          // w10 = indice * 4 (offset em bytes de GPFSELn)
    add     x10, x0, x10          // x10 = endereco do registrador (w10 ja zero-estendido)

    ldr     w3, [x10]
    mov     w4, #0b111
    lsl     w4, w4, w11
    bic     w3, w3, w4            // zera os 3 bits (equivale a configurar ENTRADA)

    cmp     w2, #0
    b.eq    1f
    mov     w4, #0b001
    lsl     w4, w4, w11
    orr     w3, w3, w4            // 001 = SAIDA
1:
    str     w3, [x10]
    ret
