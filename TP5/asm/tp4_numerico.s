// tp4_numerico.s - AArch64 (GAS)
// Rotinas numericas avancadas: aritmetica multi-palavra (128 bits via
// ADDS/ADCS), conversao inteiro<->ponto flutuante (SCVTF/FCVTZS), lookup
// table de classificacao de fluxo, e operacoes bitwise organizadas em
// macros parametrizadas (reutilizadas para decodificar o registrador de
// status de 1 byte usado desde o TP2/TP3).

// ---- macro generica para extrair um campo de bits (bitwise + shift) ----
// extrai_campo destino, origem, deslocamento, mascara
.macro extrai_campo dst, src, desloc, mascara
    lsr     \dst, \src, \desloc
    and     \dst, \dst, \mascara
.endm

    .data
// 128 bits (2x64) para demonstrar soma multi-palavra
numA_lo: .quad 0xFFFFFFFFFFFFFFFF
numA_hi: .quad 0x0000000000000001
numB_lo: .quad 0x0000000000000002
numB_hi: .quad 0x0000000000000000
resultado_lo: .quad 0
resultado_hi: .quad 0

// status de exemplo (mesmo formato de TP2/TP3): bit0=sensor bit1=botao
status_exemplo: .byte 0b00000011

// contagem total (inteiro) usada na conversao int->float->int
contagem_total: .word 37
divisor_amostras: .word 4

tabela_niveis:
    .quad msg_nivel_baixo
    .quad msg_nivel_medio
    .quad msg_nivel_alto

msg_multiprecisao: .ascii "Soma 128 bits: hi="
len_multiprecisao = . - msg_multiprecisao
msg_meio:          .ascii " lo=0x"
len_meio = . - msg_meio
msg_media:         .ascii "Media (int->float->int) = "
len_media = . - msg_media
msg_bits:          .ascii "Status decodificado: sensor="
len_bits = . - msg_bits
msg_botao:         .ascii " botao="
len_botao = . - msg_botao
msg_nivel_baixo:   .ascii "Nivel de fluxo (lookup): BAIXO\n"
len_nivel_baixo = . - msg_nivel_baixo
msg_nivel_medio:   .ascii "Nivel de fluxo (lookup): MEDIO\n"
len_nivel_medio = . - msg_nivel_medio
msg_nivel_alto:    .ascii "Nivel de fluxo (lookup): ALTO\n"
len_nivel_alto = . - msg_nivel_alto
hexdig: .ascii "0123456789abcdef"
digitos: .ascii "0123456789"
nl: .ascii "\n"

    .text
    .global _start
_start:
    // ---- 1) soma multi-palavra (128 bits) ----
    adrp    x0, numA_lo
    add     x0, x0, :lo12:numA_lo
    ldr     x1, [x0]                 // x1 = numA_lo
    adrp    x0, numA_hi
    add     x0, x0, :lo12:numA_hi
    ldr     x2, [x0]                 // x2 = numA_hi
    adrp    x0, numB_lo
    add     x0, x0, :lo12:numB_lo
    ldr     x3, [x0]                 // x3 = numB_lo
    adrp    x0, numB_hi
    add     x0, x0, :lo12:numB_hi
    ldr     x4, [x0]                 // x4 = numB_hi

    adds    x5, x1, x3               // soma as partes baixas, gera carry
    adc     x6, x2, x4               // soma as partes altas + carry

    adrp    x0, resultado_lo
    add     x0, x0, :lo12:resultado_lo
    str     x5, [x0]                 // STR: guarda resultado_lo
    adrp    x0, resultado_hi
    add     x0, x0, :lo12:resultado_hi
    str     x6, [x0]                 // STR: guarda resultado_hi (deve ser 2, com carry propagado)

    bl      imprime_multiprecisao

    // ---- 2) conversao inteiro -> float -> inteiro ----
    adrp    x0, contagem_total
    add     x0, x0, :lo12:contagem_total
    ldr     w1, [x0]                 // w1 = contagem_total (37)
    adrp    x0, divisor_amostras
    add     x0, x0, :lo12:divisor_amostras
    ldr     w2, [x0]                 // w2 = divisor_amostras (4)

    scvtf   s0, w1                   // int -> float
    scvtf   s1, w2
    fdiv    s2, s0, s1                // media em ponto flutuante (37/4 = 9.25)
    fcvtzs  w3, s2                    // float -> int (trunca): 9

    bl      imprime_media

    // ---- 3) macros de bitwise sobre o registrador de status ----
    adrp    x0, status_exemplo
    add     x0, x0, :lo12:status_exemplo
    ldrb    w4, [x0]                  // LDR: le o status
    extrai_campo w5, w4, #0, #0b1     // w5 = bit0 (sensor)
    extrai_campo w6, w4, #1, #0b1     // w6 = bit1 (botao)
    bl      imprime_bits

    // ---- 4) lookup table de nivel de fluxo (baseado na media calculada) ----
    cmp     w3, #5
    b.le    indice_baixo
    cmp     w3, #10
    b.le    indice_medio
    mov     x7, #2                    // alto
    b       usa_tabela
indice_baixo:
    mov     x7, #0
    b       usa_tabela
indice_medio:
    mov     x7, #1

usa_tabela:
    adr     x8, tabela_niveis
    ldr     x9, [x8, x7, lsl #3]      // x9 = tabela_niveis[x7] (ponteiro para a mensagem)
    // busca o comprimento correspondente (mesma ordem da tabela)
    cmp     x7, #0
    b.eq    imprime_nivel_baixo
    cmp     x7, #1
    b.eq    imprime_nivel_medio
    mov     x10, #len_nivel_alto
    b       imprime_nivel_final
imprime_nivel_baixo:
    mov     x10, #len_nivel_baixo
    b       imprime_nivel_final
imprime_nivel_medio:
    mov     x10, #len_nivel_medio

imprime_nivel_final:
    mov     x0, #1
    mov     x1, x9
    mov     x2, x10
    mov     x8, #64
    svc     #0

    mov     x0, #0
    mov     x8, #93
    svc     #0

// ---- sub-rotinas ----
imprime_multiprecisao:
    stp     x29, x30, [sp, #-16]!
    adrp    x1, msg_multiprecisao
    add     x1, x1, :lo12:msg_multiprecisao
    mov     x0, #1
    mov     x2, #len_multiprecisao
    mov     x8, #64
    svc     #0

    // imprime x6 (hi) como um digito decimal (valor pequeno, 0-9, suficiente aqui)
    adrp    x9, digitos
    add     x9, x9, :lo12:digitos
    add     x1, x9, x6
    mov     x0, #1
    mov     x2, #1
    mov     x8, #64
    svc     #0

    adrp    x1, msg_meio
    add     x1, x1, :lo12:msg_meio
    mov     x0, #1
    mov     x2, #len_meio
    mov     x8, #64
    svc     #0

    // imprime resultado_lo em hexadecimal (16 digitos)
    mov     x11, #60                  // desloc inicial (16 nibbles * 4 - 4)
    adrp    x12, hexdig
    add     x12, x12, :lo12:hexdig
loop_hex:
    lsr     x13, x5, x11
    and     x13, x13, #0xF
    add     x14, x12, x13
    mov     x0, #1
    mov     x1, x14
    mov     x2, #1
    mov     x8, #64
    svc     #0
    subs    x11, x11, #4
    b.ge    loop_hex

    adrp    x1, nl
    add     x1, x1, :lo12:nl
    mov     x0, #1
    mov     x2, #1
    mov     x8, #64
    svc     #0
    ldp     x29, x30, [sp], #16
    ret

imprime_media:
    stp     x29, x30, [sp, #-16]!
    adrp    x1, msg_media
    add     x1, x1, :lo12:msg_media
    mov     x0, #1
    mov     x2, #len_media
    mov     x8, #64
    svc     #0

    adrp    x9, digitos
    add     x9, x9, :lo12:digitos
    add     x1, x9, x3                // media inteira (0-9, suficiente para este exemplo)
    mov     x0, #1
    mov     x2, #1
    mov     x8, #64
    svc     #0

    adrp    x1, nl
    add     x1, x1, :lo12:nl
    mov     x0, #1
    mov     x2, #1
    mov     x8, #64
    svc     #0
    ldp     x29, x30, [sp], #16
    ret

imprime_bits:
    stp     x29, x30, [sp, #-16]!
    adrp    x1, msg_bits
    add     x1, x1, :lo12:msg_bits
    mov     x0, #1
    mov     x2, #len_bits
    mov     x8, #64
    svc     #0

    adrp    x9, digitos
    add     x9, x9, :lo12:digitos
    add     x1, x9, x5
    mov     x0, #1
    mov     x2, #1
    mov     x8, #64
    svc     #0

    adrp    x1, msg_botao
    add     x1, x1, :lo12:msg_botao
    mov     x0, #1
    mov     x2, #len_botao
    mov     x8, #64
    svc     #0

    add     x1, x9, x6
    mov     x0, #1
    mov     x2, #1
    mov     x8, #64
    svc     #0

    adrp    x1, nl
    add     x1, x1, :lo12:nl
    mov     x0, #1
    mov     x2, #1
    mov     x8, #64
    svc     #0
    ldp     x29, x30, [sp], #16
    ret
