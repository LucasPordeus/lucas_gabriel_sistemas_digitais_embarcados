// tp1_fluxo_basico.s - AArch64 (ARMv8) Assembly, GNU syntax (GAS)
// Programa basico de fundamentos: percorre um vetor estruturado de
// amostras simuladas do sensor de veiculos (0/1 por ciclo de amostragem),
// conta veiculos detectados usando registradores, LDR, decisao (CMP/B.cond)
// e loop, e classifica o nivel de fluxo (baixo/medio/alto) via cadeia de
// decisoes. O resultado e impresso via syscall write() (sem libc).
// Compilar/rodar: ver Makefile (executa nativamente na Raspberry Pi).

    .data
amostras:
    .byte 0,1,1,0,1,0,0,1,1,0,1,1      // vetor estruturado: 12 amostras
N_AMOSTRAS = 12

resultado_contagem:
    .byte 0

msg_baixo:  .ascii "Fluxo BAIXO: contagem="
len_baixo   = . - msg_baixo
msg_medio:  .ascii "Fluxo MEDIO: contagem="
len_medio   = . - msg_medio
msg_alto:   .ascii "Fluxo ALTO: contagem="
len_alto    = . - msg_alto
digitos:    .ascii "0123456789"
nl:         .ascii "\n"

    .text
    .global _start
_start:
    // ---- Loop de contagem (registradores, LDR, decisao, loop) ----
    mov     x0, #0                  // x0 = indice do vetor
    mov     x1, #0                  // x1 = contador de veiculos detectados
    adrp    x2, amostras
    add     x2, x2, :lo12:amostras  // x2 = base do vetor de amostras

contagem_loop:
    cmp     x0, #N_AMOSTRAS
    b.ge    contagem_fim            // decisao: fim do vetor?

    ldrb    w3, [x2, x0]            // LDR: carrega amostra[x0]
    cmp     w3, #0
    b.eq    proxima_amostra         // decisao: amostra == 0 -> nao conta

    add     x1, x1, #1              // veiculo detectado: incrementa contador

proxima_amostra:
    add     x0, x0, #1
    b       contagem_loop

contagem_fim:
    adrp    x4, resultado_contagem
    add     x4, x4, :lo12:resultado_contagem
    strb    w1, [x4]                // STR: guarda a contagem final na memoria

    // ---- Classificacao do nivel de fluxo (decisao em cadeia) ----
    cmp     x1, #3
    b.le    fluxo_baixo
    cmp     x1, #8
    b.le    fluxo_medio
    b       fluxo_alto

fluxo_baixo:
    adrp    x5, msg_baixo
    add     x5, x5, :lo12:msg_baixo
    mov     x6, #len_baixo
    b       imprime

fluxo_medio:
    adrp    x5, msg_medio
    add     x5, x5, :lo12:msg_medio
    mov     x6, #len_medio
    b       imprime

fluxo_alto:
    adrp    x5, msg_alto
    add     x5, x5, :lo12:msg_alto
    mov     x6, #len_alto

imprime:
    // write(1, msg, len)
    mov     x0, #1
    mov     x1, x5
    mov     x2, x6
    mov     x8, #64
    svc     #0

    // imprime o digito da contagem (0-9; suficiente para N_AMOSTRAS<=12):
    // busca o valor guardado em resultado_contagem e usa como indice na
    // tabela "digitos" (manipulacao de dados estruturados / lookup table).
    ldrb    w9, [x4]
    adrp    x7, digitos
    add     x7, x7, :lo12:digitos
    add     x7, x7, x9
    mov     x0, #1
    mov     x1, x7
    mov     x2, #1
    mov     x8, #64
    svc     #0

    // nova linha
    adrp    x1, nl
    add     x1, x1, :lo12:nl
    mov     x0, #1
    mov     x2, #1
    mov     x8, #64
    svc     #0

    // exit(0)
    mov     x0, #0
    mov     x8, #93
    svc     #0
