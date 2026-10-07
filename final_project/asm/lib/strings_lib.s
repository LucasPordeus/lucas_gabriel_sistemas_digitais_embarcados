// strings_lib.s - rotinas de texto usadas para montar as linhas do monitor.
//
//   uint_to_dec(x0=valor, x1=destino)  -> x0 = quantidade de caracteres escritos
//   str_copia(x0=destino, x1=texto terminado em 0) -> x0 = destino + caracteres copiados
//   escreve_fd(x0=fd, x1=ptr, x2=tamanho) -> x0 = bytes escritos (ou -errno)

    .text
    .global uint_to_dec
    .global str_copia
    .global escreve_fd

// ---- uint_to_dec ----
// Escreve o valor de 64 bits em decimal, sem zeros a esquerda ("0" para
// zero). Os digitos saem do menos significativo para o mais significativo
// numa area temporaria da pilha e depois sao copiados na ordem certa.
// A area de digitos comeca em sp+16, longe de x29/x30 salvos em sp+0.
uint_to_dec:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    add     x9, sp, #16                // area temporaria (ate 20 digitos)
    mov     x3, #0                     // digitos gerados
    mov     x6, #10

    // gera um digito por volta; termina quando o valor chega a 0
    // (roda pelo menos uma vez, para o valor 0 virar "0")
.Lutd_divide:
    udiv    x7, x0, x6                 // quociente
    msub    x8, x7, x6, x0             // resto = digito atual
    add     w8, w8, #'0'
    strb    w8, [x9, x3]
    add     x3, x3, #1
    mov     x0, x7
    cbnz    x0, .Lutd_divide

    // copia invertendo a ordem; termina quando todos os digitos foram copiados
    mov     x10, #0                    // caracteres ja copiados para o destino
.Lutd_copia:
    sub     x11, x3, x10
    sub     x11, x11, #1               // indice do proximo digito (do mais significativo)
    ldrb    w12, [x9, x11]
    strb    w12, [x1, x10]
    add     x10, x10, #1
    cmp     x10, x3
    b.lo    .Lutd_copia

    mov     x0, x3
    ldp     x29, x30, [sp], #48
    ret

// ---- str_copia ----
// Copia o texto (sem o 0 final); termina ao encontrar o byte 0.
str_copia:
    ldrb    w2, [x1], #1
    cbz     w2, 1f
    strb    w2, [x0], #1
    b       str_copia
1:  ret

// ---- escreve_fd ----
escreve_fd:
    mov     x8, #64                    // write
    svc     #0
    ret
