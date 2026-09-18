// tp4_neon_simd.s - AArch64 (GAS) com extensao NEON (Advanced SIMD)
// Pre-processamento paralelo de 4 "vias" de sensores simultaneas (como se
// o cruzamento tivesse 4 sensores de veiculos independentes), usando
// instrucoes NEON para somar contagens em paralelo (inteiros) e calcular
// a media ponderada em paralelo (ponto flutuante), em uma unica operacao
// vetorial de 4 elementos (4x mais rapido que um loop escalar equivalente).

    .data
    .align 4
contagens_via_A: .word 5, 8, 3, 10     // 4 vias, intervalo de amostragem 1
contagens_via_B: .word 2, 1, 4, 0      // 4 vias, intervalo de amostragem 2
pesos_float:     .float 1.0, 1.5, 0.5, 2.0  // peso por via (ex.: capacidade da faixa)

somas_int:   .word 0, 0, 0, 0
medias_float: .float 0.0, 0.0, 0.0, 0.0

msg_somas:  .ascii "Somas por via (NEON, inteiro): "
len_somas = . - msg_somas
msg_medias: .ascii "\nMedias ponderadas por via (NEON, float, trunc.): "
len_medias = . - msg_medias
digitos: .ascii "0123456789"
espaco: .ascii " "
nl: .ascii "\n"

    .text
    .global _start
_start:
    // ---- soma vetorial inteira (4 vias em paralelo) ----
    adrp    x0, contagens_via_A
    add     x0, x0, :lo12:contagens_via_A
    ld1     {v0.4s}, [x0]              // carrega as 4 contagens da via A
    adrp    x0, contagens_via_B
    add     x0, x0, :lo12:contagens_via_B
    ld1     {v1.4s}, [x0]              // carrega as 4 contagens da via B

    add     v2.4s, v0.4s, v1.4s        // soma paralela das 4 vias em 1 instrucao

    adrp    x0, somas_int
    add     x0, x0, :lo12:somas_int
    st1     {v2.4s}, [x0]              // STR (NEON): guarda o vetor resultado

    // ---- conversao inteiro->float e multiplicacao por peso, em paralelo ----
    scvtf   v3.4s, v2.4s               // converte as 4 somas para float simultaneamente
    adrp    x0, pesos_float
    add     x0, x0, :lo12:pesos_float
    ld1     {v4.4s}, [x0]              // carrega os 4 pesos
    fmul    v5.4s, v3.4s, v4.4s        // multiplica cada soma pelo peso da sua via

    fcvtzs  v6.4s, v5.4s               // converte de volta para inteiro (trunca), para impressao simples
    adrp    x0, medias_float
    add     x0, x0, :lo12:medias_float
    st1     {v6.4s}, [x0]              // guarda o resultado (reaproveitando o buffer como inteiro)

    bl      imprime_resultados

    mov     x0, #0
    mov     x8, #93
    svc     #0

imprime_resultados:
    stp     x29, x30, [sp, #-16]!

    adrp    x1, msg_somas
    add     x1, x1, :lo12:msg_somas
    mov     x0, #1
    mov     x2, #len_somas
    mov     x8, #64
    svc     #0

    adrp    x19, somas_int
    add     x19, x19, :lo12:somas_int
    mov     x20, #0                    // indice (0-3)
loop_somas:
    cmp     x20, #4
    b.ge    fim_loop_somas
    ldr     w0, [x19, x20, lsl #2]     // LDR: le somas_int[indice] (vetor de 32 bits)
    bl      imprime_w0_decimal
    add     x20, x20, #1
    b       loop_somas
fim_loop_somas:

    adrp    x1, msg_medias
    add     x1, x1, :lo12:msg_medias
    mov     x0, #1
    mov     x2, #len_medias
    mov     x8, #64
    svc     #0

    adrp    x19, medias_float
    add     x19, x19, :lo12:medias_float
    mov     x20, #0
loop_medias:
    cmp     x20, #4
    b.ge    fim_loop_medias
    ldr     w0, [x19, x20, lsl #2]
    bl      imprime_w0_decimal
    add     x20, x20, #1
    b       loop_medias
fim_loop_medias:

    adrp    x1, nl
    add     x1, x1, :lo12:nl
    mov     x0, #1
    mov     x2, #1
    mov     x8, #64
    svc     #0

    ldp     x29, x30, [sp], #16
    ret

// imprime w0 (0-99) em decimal seguido de espaco; usa x0-x2,x8 e x21-x24
imprime_w0_decimal:
    stp     x29, x30, [sp, #-16]!
    mov     x21, x0
    cmp     x21, #10
    b.lt    um_digito

    mov     x22, #10
    udiv    x23, x21, x22
    msub    x24, x23, x22, x21
    adrp    x0, digitos
    add     x0, x0, :lo12:digitos
    add     x0, x0, x23
    mov     x1, x0
    mov     x0, #1
    mov     x2, #1
    mov     x8, #64
    svc     #0
    adrp    x0, digitos
    add     x0, x0, :lo12:digitos
    add     x0, x0, x24
    mov     x1, x0
    mov     x0, #1
    mov     x2, #1
    mov     x8, #64
    svc     #0
    b       imprime_espaco

um_digito:
    adrp    x0, digitos
    add     x0, x0, :lo12:digitos
    add     x0, x0, x21
    mov     x1, x0
    mov     x0, #1
    mov     x2, #1
    mov     x8, #64
    svc     #0

imprime_espaco:
    adrp    x1, espaco
    add     x1, x1, :lo12:espaco
    mov     x0, #1
    mov     x2, #1
    mov     x8, #64
    svc     #0
    ldp     x29, x30, [sp], #16
    ret
