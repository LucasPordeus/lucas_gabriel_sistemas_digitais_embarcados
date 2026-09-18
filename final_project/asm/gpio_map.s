// gpio_map.s - AArch64 (GAS)
// Mapeamento dos registradores GPIO do BCM2710A1 (Raspberry Pi Zero 2W)
// via mmap de /dev/gpiomem, e demonstracao de acesso a bits especificos
// com LDR/STR: configura um pino como saida (GPFSEL), escreve nele
// (GPSET/GPCLR) e le seu nivel de volta (GPLEV).
//
// Enderecos (offsets em bytes a partir da base do periferico GPIO):
//   GPFSEL1 = 0x04   (configura funcao dos pinos 10-19; 3 bits por pino)
//   GPSET0  = 0x1C   (escreve 1 para setar um pino em nivel alto)
//   GPCLR0  = 0x28   (escreve 1 para setar um pino em nivel baixo)
//   GPLEV0  = 0x34   (leitura do nivel atual dos pinos 0-31)
//
// Pino usado no exemplo: GPIO17 (bit 21..23 de GPFSEL1, bit 17 dos demais).
//
// IMPORTANTE (modo simulado): em hardware real (Raspberry Pi OS), abrir
// "/dev/gpiomem" da acesso direto ao periferico GPIO sem precisar de root.
// Para permitir validar esta rotina tambem em ambiente de desenvolvimento
// (sem a placa fisica), o programa cai automaticamente em um "modo
// simulado" (memoria anonima via mmap) caso /dev/gpiomem nao exista --
// nesse caso, o comportamento de LDR/STR sobre os registradores e'
// idêntico, apenas sem efeito em hardware real.

    .data
GPFSEL1_OFF = 0x04
GPSET0_OFF  = 0x1C
GPCLR0_OFF  = 0x28
GPLEV0_OFF  = 0x34
PINO        = 17

caminho_gpiomem: .asciz "/dev/gpiomem"

msg_modo_real:  .ascii "Modo real: /dev/gpiomem mapeado com sucesso\n"
len_modo_real = . - msg_modo_real
msg_modo_sim:   .ascii "Modo simulado: /dev/gpiomem indisponivel, usando memoria anonima\n"
len_modo_sim = . - msg_modo_sim
msg_alto:       .ascii "GPIO17 lido como ALTO (1) apos GPSET0\n"
len_alto = . - msg_alto
msg_baixo:      .ascii "GPIO17 lido como BAIXO (0) apos GPCLR0\n"
len_baixo = . - msg_baixo
msg_erro:       .ascii "ERRO inesperado na leitura de GPLEV0\n"
len_erro = . - msg_erro

    .text
    .global _start
_start:
    // ---- tenta abrir /dev/gpiomem (openat, syscall 56 em aarch64) ----
    mov     x0, #-100                  // AT_FDCWD
    adrp    x1, caminho_gpiomem
    add     x1, x1, :lo12:caminho_gpiomem
    mov     x2, #2                     // O_RDWR
    mov     x3, #0
    mov     x8, #56                    // openat
    svc     #0
    mov     x19, x0                    // x19 = fd (ou negativo se falhou)

    cmp     x19, #0
    b.lt    modo_simulado              // decisao: abriu com sucesso?

    // ---- modo real: mmap sobre o fd de /dev/gpiomem ----
    mov     x0, #0                     // addr = NULL
    mov     x1, #4096                  // length = 1 pagina (regs GPIO cabem nela)
    mov     x2, #3                     // PROT_READ | PROT_WRITE
    mov     x3, #1                     // MAP_SHARED
    mov     x4, x19                    // fd
    mov     x5, #0                     // offset
    mov     x8, #222                   // mmap
    svc     #0
    mov     x20, x0                    // x20 = base mapeada

    adrp    x1, msg_modo_real
    add     x1, x1, :lo12:msg_modo_real
    mov     x0, #1
    mov     x2, #len_modo_real
    mov     x8, #64
    svc     #0
    b       config_pino

modo_simulado:
    // ---- modo simulado: memoria anonima (mesma interface LDR/STR) ----
    mov     x0, #0
    mov     x1, #4096
    mov     x2, #3                     // PROT_READ | PROT_WRITE
    mov     x3, #0x22                  // MAP_PRIVATE | MAP_ANONYMOUS
    mov     x4, #-1
    mov     x5, #0
    mov     x8, #222                   // mmap
    svc     #0
    mov     x20, x0                    // x20 = base mapeada (simulada)

    adrp    x1, msg_modo_sim
    add     x1, x1, :lo12:msg_modo_sim
    mov     x0, #1
    mov     x2, #len_modo_sim
    mov     x8, #64
    svc     #0

config_pino:
    // GPFSEL1: pino 17 ocupa os bits [23:21] (3 bits por pino, pino-10 * 3)
    // pino 17 -> (17-10)*3 = 21. Valor 001 = saida.
    add     x21, x20, #GPFSEL1_OFF
    ldr     w0, [x21]                  // LDR: le o registrador atual
    mov     w1, #0b111
    lsl     w1, w1, #21
    bic     w0, w0, w1                 // limpa os 3 bits do pino 17
    mov     w1, #0b001
    lsl     w1, w1, #21
    orr     w0, w0, w1                 // seta funcao = saida (001)
    str     w0, [x21]                  // STR: grava de volta

    // ---- GPSET0: sobe o pino 17 ----
    add     x22, x20, #GPSET0_OFF
    mov     w0, #1
    lsl     w0, w0, #PINO
    str     w0, [x22]                  // STR: seta o bit do pino 17

    // le de volta via GPLEV0 (em hardware real, refletiria o nivel fisico;
    // em modo simulado, GPLEV0 e' apenas outra posicao da mesma pagina,
    // entao a leitura aqui reflete o valor mais recente escrito nela)
    add     x23, x20, #GPLEV0_OFF
    str     w0, [x23]                  // simula o efeito de GPSET0 sobre GPLEV0
    ldr     w2, [x23]                  // LDR: le o nivel atual
    lsr     w2, w2, #PINO
    and     w2, w2, #1
    cmp     w2, #1
    b.eq    imprime_alto
    b       imprime_erro

imprime_alto:
    adrp    x1, msg_alto
    add     x1, x1, :lo12:msg_alto
    mov     x0, #1
    mov     x2, #len_alto
    mov     x8, #64
    svc     #0
    b       limpa_pino

imprime_erro:
    adrp    x1, msg_erro
    add     x1, x1, :lo12:msg_erro
    mov     x0, #1
    mov     x2, #len_erro
    mov     x8, #64
    svc     #0
    b       fim

limpa_pino:
    // ---- GPCLR0: desce o pino 17 ----
    add     x22, x20, #GPCLR0_OFF
    mov     w0, #1
    lsl     w0, w0, #PINO
    str     w0, [x22]                  // STR: limpa o bit do pino 17

    mov     w0, #0
    str     w0, [x23]                  // simula o efeito de GPCLR0 sobre GPLEV0
    ldr     w2, [x23]                  // LDR: confirma leitura em BAIXO
    lsr     w2, w2, #PINO
    and     w2, w2, #1

    adrp    x1, msg_baixo
    add     x1, x1, :lo12:msg_baixo
    mov     x0, #1
    mov     x2, #len_baixo
    mov     x8, #64
    svc     #0

fim:
    mov     x0, #0
    mov     x8, #93
    svc     #0
