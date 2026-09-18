// tp3_controle_fluxo.s - AArch64 (GAS)
// Parser simples de comandos recebidos do "operador" (simulando comandos
// que chegariam via protocolo serial/terminal), demonstrando estruturas
// de controle avancadas: multiplas condicoes (if-elseif-else), tabela de
// saltos (jump table) indexada, e loop de processamento de um vetor de
// comandos. Cada comando e' um byte com opcode em [7:6] (mesmo formato do
// protocolo_paralelo.v) e valor em [5:0].

    .data
comandos:
    .byte 0b00010100   // opcode 00 (tempo_min)     valor 20
    .byte 0b01000011   // opcode 01 (tempo_amarelo) valor 3
    .byte 0b10000011   // opcode 10 (limiar_baixo)  valor 3
    .byte 0b11001000   // opcode 11 (limiar_alto)   valor 8
    .byte 0b11111111   // OP_LIMIAR_ALTO com valor maximo (63) -- exercita o caso de 2 digitos
N_COMANDOS = 5

msg_tempo_min:     .ascii "[cmd] OP_TEMPO_MIN     valor="
len_tempo_min = . - msg_tempo_min
msg_tempo_amarelo: .ascii "[cmd] OP_TEMPO_AMARELO valor="
len_tempo_amarelo = . - msg_tempo_amarelo
msg_limiar_baixo:  .ascii "[cmd] OP_LIMIAR_BAIXO  valor="
len_limiar_baixo = . - msg_limiar_baixo
msg_limiar_alto:   .ascii "[cmd] OP_LIMIAR_ALTO   valor="
len_limiar_alto = . - msg_limiar_alto
digitos: .ascii "0123456789"
nl: .ascii "\n"

    .text
    .global _start
_start:
    mov     x19, #0                     // x19 = indice do comando
    adrp    x20, comandos
    add     x20, x20, :lo12:comandos

loop_comandos:
    cmp     x19, #N_COMANDOS
    b.ge    fim_programa                 // decisao: fim do vetor?

    ldrb    w0, [x20, x19]               // LDR: le o comando atual
    lsr     w1, w0, #6                   // isola opcode (bits 7:6)
    and     w1, w1, #0b11
    and     w2, w0, #0b111111            // isola valor (bits 5:0), x2 preservado p/ impressao

    // ---- tabela de saltos: opcode (0-3) -> rotina correspondente ----
    adr     x3, tabela_saltos
    ldr     x4, [x3, x1, lsl #3]         // x4 = tabela_saltos[opcode] (8 bytes/entrada)
    br      x4                           // salto indexado (equivalente ao if-elseif-else)

tabela_saltos:
    .dword  rot_tempo_min
    .dword  rot_tempo_amarelo
    .dword  rot_limiar_baixo
    .dword  rot_limiar_alto

rot_tempo_min:
    adrp    x5, msg_tempo_min
    add     x5, x5, :lo12:msg_tempo_min
    mov     x6, #len_tempo_min
    b       imprime_comando

rot_tempo_amarelo:
    adrp    x5, msg_tempo_amarelo
    add     x5, x5, :lo12:msg_tempo_amarelo
    mov     x6, #len_tempo_amarelo
    b       imprime_comando

rot_limiar_baixo:
    adrp    x5, msg_limiar_baixo
    add     x5, x5, :lo12:msg_limiar_baixo
    mov     x6, #len_limiar_baixo
    b       imprime_comando

rot_limiar_alto:
    adrp    x5, msg_limiar_alto
    add     x5, x5, :lo12:msg_limiar_alto
    mov     x6, #len_limiar_alto
    // cai direto em imprime_comando

imprime_comando:
    // ATENCAO: x2 guarda "valor" (usado mais abaixo para imprimir o
    // numero) -- o comprimento da mensagem vai em x12, para nao corromper x2.
    mov     x0, #1
    mov     x1, x5
    mov     x12, x2
    mov     x2, x6
    mov     x8, #64
    svc     #0
    mov     x2, x12                      // restaura x2 = valor

    // imprime o valor (0-63) como um ou dois digitos decimais
    cmp     x2, #10
    b.lt    imprime_um_digito            // decisao: valor < 10?

    // dois digitos: dezena e unidade
    mov     x7, #10
    udiv    x8, x2, x7
    msub    x9, x8, x7, x2               // x9 = x2 - (x8*10) = resto (unidade)
    adrp    x10, digitos
    add     x10, x10, :lo12:digitos
    add     x11, x10, x8
    mov     x0, #1
    mov     x1, x11
    mov     x2, #1
    mov     x8, #64
    svc     #0
    add     x11, x10, x9
    mov     x0, #1
    mov     x1, x11
    mov     x2, #1
    mov     x8, #64
    svc     #0
    b       imprime_nl

imprime_um_digito:
    adrp    x10, digitos
    add     x10, x10, :lo12:digitos
    add     x11, x10, x2
    mov     x0, #1
    mov     x1, x11
    mov     x2, #1
    mov     x8, #64
    svc     #0

imprime_nl:
    adrp    x1, nl
    add     x1, x1, :lo12:nl
    mov     x0, #1
    mov     x2, #1
    mov     x8, #64
    svc     #0

    add     x19, x19, #1
    b       loop_comandos

fim_programa:
    mov     x0, #0
    mov     x8, #93
    svc     #0
