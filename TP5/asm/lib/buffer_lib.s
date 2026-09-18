// buffer_lib.s - biblioteca de buffer circular (FIFO) para telemetria
// (AArch64 / GAS). O chamador aloca o vetor de dados e duas variaveis de
// 32 bits (head e tail) separadamente; a biblioteca so' opera sobre os
// ponteiros recebidos, sem assumir uma struct fixa.
//
//   cbuf_push(x0=data_ptr, x1=capacidade, x2=head_addr, x3=tail_addr, x4=byte)
//       -> w0 = 1 (sucesso) ou 0 (buffer cheio)
//   cbuf_pop(x0=data_ptr, x1=capacidade, x2=head_addr, x3=tail_addr)
//       -> w0 = byte lido (se sucesso), w1 = 1 (sucesso) ou 0 (buffer vazio)

    .text
    .global cbuf_push
    .global cbuf_pop

cbuf_push:
    ldr     w5, [x2]                // w5 = head
    ldr     w6, [x3]                // w6 = tail
    add     w7, w6, #1
    udiv    w8, w7, w1
    msub    w7, w8, w1, w7          // w7 = (tail+1) % capacidade

    cmp     w7, w5
    b.eq    .Lpush_cheio            // proximo tail colidiria com head -> cheio

    add     x9, x0, x6              // endereco = data_ptr + tail
    strb    w4, [x9]                // STR: grava o byte na posicao "tail"
    str     w7, [x3]                // atualiza tail
    mov     w0, #1
    ret

.Lpush_cheio:
    mov     w0, #0
    ret

cbuf_pop:
    ldr     w5, [x2]                // w5 = head
    ldr     w6, [x3]                // w6 = tail

    cmp     w5, w6
    b.eq    .Lpop_vazio             // head == tail -> vazio

    add     x9, x0, x5              // endereco = data_ptr + head
    ldrb    w0, [x9]                // LDR: le o byte na posicao "head"
    add     w7, w5, #1
    udiv    w8, w7, w1
    msub    w7, w8, w1, w7          // w7 = (head+1) % capacidade
    str     w7, [x2]                // atualiza head
    mov     w1, #1
    ret

.Lpop_vazio:
    mov     w0, #0
    mov     w1, #0
    ret
