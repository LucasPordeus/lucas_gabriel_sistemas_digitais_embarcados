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

    .data
caminho_gpiomem: .asciz "/dev/gpiomem"

    .text
    .global gpio_map_init
    .global gpio_set_bit
    .global gpio_clear_bit
    .global gpio_read_bit

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
