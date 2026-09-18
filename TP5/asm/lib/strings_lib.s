// strings_lib.s - biblioteca de manipulacao de strings (AArch64 / GAS)
//
//   str_len(x0=ptr)                          -> x0 = comprimento (ate byte 0)
//   uint_to_dec(x0=valor de 64 bits, x1=buf_destino) -> x0 = comprimento escrito (sem zeros a esquerda)
//   escreve_fd(x0=fd, x1=ptr, x2=len)         -> wrapper do syscall write; x0 = bytes escritos

    .data
digitos_tab: .ascii "0123456789"

    .text
    .global str_len
    .global uint_to_dec
    .global escreve_fd

str_len:
    mov     x1, x0
.Lstrlen_loop:
    ldrb    w2, [x1]
    cbz     w2, .Lstrlen_fim
    add     x1, x1, #1
    b       .Lstrlen_loop
.Lstrlen_fim:
    sub     x0, x1, x0
    ret

// uint_to_dec: converte um valor de 64 bits (0 a 18446744073709551615,
// 20 digitos no maximo) para ASCII decimal em buf_destino, sem zero a
// esquerda (excecao: valor 0 -> "0"). Usa uma pilha local de digitos
// (LIFO) para inverter a ordem.
//
// Bug real encontrado e corrigido (extensao pos-TP5, ao imprimir o
// tempo total real decorrido do monitor_semaforo.s, um numero de 11
// digitos): a versao original (1) truncava o valor de entrada pra 32
// bits (usava w0/w2 em vez de x0/x2, quebrando qualquer numero >
// 4294967295) e (2) empilhava os digitos a partir de [sp+0] -- o MESMO
// endereco onde "stp x29,x30,[sp,#-48]!" tinha acabado de salvar o
// proprio x30 (endereco de retorno) em [sp+8..+15]. Qualquer valor com
// 9 ou mais digitos sobrescrevia esses bytes, corrompendo o retorno da
// funcao (o "ret" pulava para um endereco de lixo). Passou despercebido
// porque nenhuma chamada anterior no projeto imprimia um numero com 9+
// digitos (o throughput de main_tp5.s tem 8 digitos, exatamente na
// margem). Corrigido usando os registradores de 64 bits inteiros e
// deslocando a pilha de digitos para [sp+16], bem longe de x29/x30.
uint_to_dec:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    mov     x2, x0                 // x2 = valor restante (64 bits)
    mov     x3, #0                 // x3 = quantidade de digitos empilhados
    adrp    x4, digitos_tab
    add     x4, x4, :lo12:digitos_tab
    add     x13, sp, #16           // base segura da pilha de digitos --
                                    // [sp+0..15] e' onde x29/x30 estao salvos

    cbnz    x2, .Lutd_loop
    mov     w5, #'0'
    strb    w5, [x13, x3]
    add     x3, x3, #1
    b       .Lutd_inverte

.Lutd_loop:
    cbz     x2, .Lutd_inverte
    mov     x6, #10
    udiv    x7, x2, x6              // x7 = quociente
    msub    x8, x7, x6, x2          // x8 = resto (digito atual)
    add     x9, x4, x8
    ldrb    w9, [x9]
    strb    w9, [x13, x3]           // empilha o digito (ordem invertida)
    add     x3, x3, #1
    mov     x2, x7
    b       .Lutd_loop

.Lutd_inverte:
    mov     x10, #0                 // indice de leitura na pilha (do topo p/ base)
.Lutd_copia:
    cmp     x10, x3
    b.ge    .Lutd_fim
    sub     x11, x3, x10
    sub     x11, x11, #1
    ldrb    w12, [x13, x11]
    strb    w12, [x1, x10]
    add     x10, x10, #1
    b       .Lutd_copia

.Lutd_fim:
    mov     x0, x3                  // retorna o comprimento
    ldp     x29, x30, [sp], #64
    ret

escreve_fd:
    mov     x8, #64                 // syscall write
    svc     #0
    ret
