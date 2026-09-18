// test_lib.s - programa de teste standalone para validar libembarcado.a
// (gpio_lib, strings_lib, buffer_lib) antes de usa-la em main_tp5.s.
// Nao faz parte da entrega funcional do semaforo -- e' um harness de
// verificacao, equivalente a um testbench, so' que para a biblioteca ARM.

    .data
buf_dados:  .space 8
buf_head:   .word 0
buf_tail:   .word 0
str_buf:    .space 16
nl: .ascii "\n"
msg_ok1: .ascii "[OK] str_len\n"
len_ok1 = . - msg_ok1
msg_fail1: .ascii "[FALHA] str_len\n"
len_fail1 = . - msg_fail1
msg_ok2: .ascii "[OK] uint_to_dec\n"
len_ok2 = . - msg_ok2
msg_fail2: .ascii "[FALHA] uint_to_dec\n"
len_fail2 = . - msg_fail2
msg_ok3: .ascii "[OK] cbuf push/pop (FIFO correto)\n"
len_ok3 = . - msg_ok3
msg_fail3: .ascii "[FALHA] cbuf push/pop\n"
len_fail3 = . - msg_fail3
msg_ok4: .ascii "[OK] gpio_lib (set/read/clear)\n"
len_ok4 = . - msg_ok4
msg_fail4: .ascii "[FALHA] gpio_lib\n"
len_fail4 = . - msg_fail4
texto_teste: .asciz "abcde"

    .text
    .global _start
_start:
    // ---- teste 1: str_len ----
    adrp    x0, texto_teste
    add     x0, x0, :lo12:texto_teste
    bl      str_len
    cmp     x0, #5
    b.ne    .Lfail1
    adrp    x1, msg_ok1
    add     x1, x1, :lo12:msg_ok1
    mov     x2, #len_ok1
    b       .Lprint1
.Lfail1:
    adrp    x1, msg_fail1
    add     x1, x1, :lo12:msg_fail1
    mov     x2, #len_fail1
.Lprint1:
    mov     x0, #1
    bl      escreve_fd

    // ---- teste 2: uint_to_dec(1234) deve produzir "1234" (len=4) ----
    mov     x0, #1234
    adrp    x1, str_buf
    add     x1, x1, :lo12:str_buf
    bl      uint_to_dec
    cmp     x0, #4
    b.ne    .Lfail2
    adrp    x2, str_buf
    add     x2, x2, :lo12:str_buf
    ldrb    w3, [x2, #0]
    cmp     w3, #'1'
    b.ne    .Lfail2
    ldrb    w3, [x2, #3]
    cmp     w3, #'4'
    b.ne    .Lfail2
    adrp    x1, msg_ok2
    add     x1, x1, :lo12:msg_ok2
    mov     x2, #len_ok2
    b       .Lprint2
.Lfail2:
    adrp    x1, msg_fail2
    add     x1, x1, :lo12:msg_fail2
    mov     x2, #len_fail2
.Lprint2:
    mov     x0, #1
    bl      escreve_fd

    // imprime a string convertida, so' para conferencia visual
    adrp    x1, str_buf
    add     x1, x1, :lo12:str_buf
    mov     x2, #4
    mov     x0, #1
    bl      escreve_fd
    adrp    x1, nl
    add     x1, x1, :lo12:nl
    mov     x2, #1
    mov     x0, #1
    bl      escreve_fd

    // ---- teste 3: cbuf_push/cbuf_pop (FIFO com capacidade 8) ----
    adrp    x0, buf_dados
    add     x0, x0, :lo12:buf_dados
    mov     x1, #8
    adrp    x2, buf_head
    add     x2, x2, :lo12:buf_head
    adrp    x3, buf_tail
    add     x3, x3, :lo12:buf_tail
    mov     x4, #10
    bl      cbuf_push                  // empilha 10

    adrp    x0, buf_dados
    add     x0, x0, :lo12:buf_dados
    mov     x1, #8
    adrp    x2, buf_head
    add     x2, x2, :lo12:buf_head
    adrp    x3, buf_tail
    add     x3, x3, :lo12:buf_tail
    mov     x4, #20
    bl      cbuf_push                  // empilha 20

    adrp    x0, buf_dados
    add     x0, x0, :lo12:buf_dados
    mov     x1, #8
    adrp    x2, buf_head
    add     x2, x2, :lo12:buf_head
    adrp    x3, buf_tail
    add     x3, x3, :lo12:buf_tail
    bl      cbuf_pop                   // deve retornar 10 (FIFO)
    cmp     w0, #10
    b.ne    .Lfail3
    cmp     w1, #1
    b.ne    .Lfail3

    adrp    x0, buf_dados
    add     x0, x0, :lo12:buf_dados
    mov     x1, #8
    adrp    x2, buf_head
    add     x2, x2, :lo12:buf_head
    adrp    x3, buf_tail
    add     x3, x3, :lo12:buf_tail
    bl      cbuf_pop                   // deve retornar 20
    cmp     w0, #20
    b.ne    .Lfail3

    adrp    x0, buf_dados
    add     x0, x0, :lo12:buf_dados
    mov     x1, #8
    adrp    x2, buf_head
    add     x2, x2, :lo12:buf_head
    adrp    x3, buf_tail
    add     x3, x3, :lo12:buf_tail
    bl      cbuf_pop                   // buffer ja vazio -> w1 deve ser 0
    cmp     w1, #0
    b.ne    .Lfail3

    adrp    x1, msg_ok3
    add     x1, x1, :lo12:msg_ok3
    mov     x2, #len_ok3
    b       .Lprint3
.Lfail3:
    adrp    x1, msg_fail3
    add     x1, x1, :lo12:msg_fail3
    mov     x2, #len_fail3
.Lprint3:
    mov     x0, #1
    bl      escreve_fd

    // ---- teste 4: gpio_lib (mapeamento simulado + set/read/clear em GPIO17) ----
    bl      gpio_map_init
    mov     x19, x0                    // x19 = base mapeada

    mov     x0, x19
    mov     x1, #0x1C                  // GPSET0
    mov     x2, #17
    bl      gpio_set_bit

    // simula GPLEV0 == GPSET0 para fins de teste (mesma tecnica de gpio_map.s)
    ldr     w4, [x19, #0x1C]
    str     w4, [x19, #0x34]

    mov     x0, x19
    mov     x1, #0x34                  // GPLEV0
    mov     x2, #17
    bl      gpio_read_bit
    cmp     w0, #1
    b.ne    .Lfail4

    mov     x0, x19
    mov     x1, #0x28                  // GPCLR0
    mov     x2, #17
    bl      gpio_clear_bit

    mov     w4, #0
    str     w4, [x19, #0x34]

    mov     x0, x19
    mov     x1, #0x34
    mov     x2, #17
    bl      gpio_read_bit
    cmp     w0, #0
    b.ne    .Lfail4

    adrp    x1, msg_ok4
    add     x1, x1, :lo12:msg_ok4
    mov     x2, #len_ok4
    b       .Lprint4
.Lfail4:
    adrp    x1, msg_fail4
    add     x1, x1, :lo12:msg_fail4
    mov     x2, #len_fail4
.Lprint4:
    mov     x0, #1
    bl      escreve_fd

    mov     x0, #0
    mov     x8, #93
    svc     #0
