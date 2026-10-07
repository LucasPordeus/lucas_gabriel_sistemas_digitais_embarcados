// gpio_lib.s - acesso direto aos registradores de GPIO do BCM2710A1
// (Raspberry Pi Zero 2W) pelo mapeamento de /dev/gpiomem. Base de
// protocolo_serial_gpio.s. Convencao AAPCS64: argumentos em x0-x7,
// retorno em x0, x19-x29 preservados.
//
//   gpio_map_init()                       -> x0 = base dos registradores, ou 0 se falhar
//   gpio_configura_pino(x0=base, w1=pino, w2=modo)   modo: 0 = entrada, 1 = saida
//   gpio_escreve(x0=base, w1=pino, w2=nivel)         nivel: 0 = baixo, 1 = alto
//   gpio_le(x0=base, w1=pino)             -> w0 = nivel do pino (0 ou 1)
// Pinos validos: 0-31 (todos os usados pelo projeto).

GPSET0_OFF = 0x1C        // escrever 1 no bit n leva o pino n para nivel alto
GPCLR0_OFF = 0x28        // escrever 1 no bit n leva o pino n para nivel baixo
GPLEV0_OFF = 0x34        // bit n = nivel atual do pino n

    .data
caminho_gpiomem: .asciz "/dev/gpiomem"

    .text
    .global gpio_map_init
    .global gpio_configura_pino
    .global gpio_escreve
    .global gpio_le

// ---- gpio_map_init ----
// Abre /dev/gpiomem e mapeia 4 KiB com os registradores de GPIO.
// Retorno: x0 = endereco base mapeado; 0 se nao abriu ou nao mapeou
// (sem permissao, ou nao esta rodando numa Raspberry Pi).
gpio_map_init:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]

    mov     x0, #-100                  // AT_FDCWD
    adrp    x1, caminho_gpiomem
    add     x1, x1, :lo12:caminho_gpiomem
    movz    x2, #0x1002
    movk    x2, #0x10, lsl #16         // x2 = O_RDWR | O_SYNC (0x101002)
    mov     x3, #0
    mov     x8, #56                    // openat
    svc     #0
    cmp     x0, #0
    b.lt    .Lmap_falhou
    mov     x19, x0                    // x19 = descritor de /dev/gpiomem

    mov     x0, #0
    mov     x1, #4096
    mov     x2, #3                     // PROT_READ | PROT_WRITE
    mov     x3, #1                     // MAP_SHARED
    mov     x4, x19
    mov     x5, #0
    mov     x8, #222                   // mmap
    svc     #0
    mov     x9, x0                     // x9 = endereco mapeado ou -errno

    mov     x0, x19
    mov     x8, #57                    // close (o mapeamento continua valido)
    svc     #0

    mov     x10, #-4096
    cmp     x9, x10
    b.hi    .Lmap_falhou               // -4095..-1 = erro do mmap
    mov     x0, x9
    b       .Lmap_fim

.Lmap_falhou:
    mov     x0, #0
.Lmap_fim:
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ---- gpio_configura_pino ----
// GPFSELn: 10 pinos por registrador, 3 bits por pino, registrador n no
// offset 4*n. 000 = entrada, 001 = saida.
gpio_configura_pino:
    mov     w9, #10
    udiv    w10, w1, w9                // w10 = indice do GPFSELn (pino / 10)
    msub    w11, w10, w9, w1           // w11 = posicao no registrador (pino % 10)
    add     w11, w11, w11, lsl #1      // w11 = deslocamento em bits (posicao * 3)
    add     x10, x0, x10, lsl #2       // x10 = endereco de GPFSELn

    ldr     w3, [x10]
    mov     w4, #0b111
    lsl     w4, w4, w11
    bic     w3, w3, w4                 // 000 = entrada
    cbz     w2, 1f
    mov     w4, #0b001
    lsl     w4, w4, w11
    orr     w3, w3, w4                 // 001 = saida
1:  str     w3, [x10]
    ret

// ---- gpio_escreve ----
// GPSET0/GPCLR0 sao so' de escrita: grava apenas a mascara do pino, sem
// ler antes, e os demais pinos nao mudam.
gpio_escreve:
    mov     w3, #1
    lsl     w3, w3, w1                 // w3 = mascara do pino
    mov     x4, #GPCLR0_OFF
    mov     x5, #GPSET0_OFF
    cmp     w2, #0
    csel    x4, x4, x5, eq             // nivel 0 -> GPCLR0, nivel 1 -> GPSET0
    str     w3, [x0, x4]
    ret

// ---- gpio_le ----
gpio_le:
    ldr     w3, [x0, #GPLEV0_OFF]
    lsr     w3, w3, w1
    and     w0, w3, #1
    ret
