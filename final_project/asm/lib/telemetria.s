// telemetria.s - valida e traduz para texto o quadro de 16 bits enviado
// pela FPGA (montado em rtl/top_semaforo.v):
//
//   bits 15-12  marcador fixo 1010
//   bits 11-10  cor dos carros: 00 vermelho, 01 amarelo, 10 verde
//   bit  9      pedestre: 1 verde, 0 vermelho
//   bit  8      pedido de travessia pendente
//   bits 7-6    fluxo: 00 baixo, 01 medio, 10 alto
//   bits 5-0    segundos restantes da fase atual
//
//   telemetria_valida(w0=quadro)            -> w0 = 1 se o quadro e' coerente, 0 se nao
//   telemetria_formata(w0=quadro, x1=destino) -> x0 = caracteres escritos (linha com '\n')
//
// Quadro invalido: marcador diferente de 1010 (fio solto, GND ausente ou
// FPGA nao gravada), codigo 11 em cor ou fluxo, ou pedestre verde com
// carro fora do vermelho (estado que a FSM nunca gera).

MARCADOR = 0xA

    .data
txt_carros:     .asciz "carros="
txt_pedestres:  .asciz " pedestres="
txt_restante:   .asciz " restante="
txt_segundos:   .asciz "s"
txt_fluxo:      .asciz " fluxo="
txt_pedido:     .asciz " pedido="
txt_invalido:   .asciz "QUADRO INVALIDO (valor="
txt_dica:       .asciz "): confira fiacao, GND comum e se a FPGA esta gravada"
txt_fim_linha:  .asciz "\n"

txt_vermelho:   .asciz "VERMELHO"
txt_amarelo:    .asciz "AMARELO"
txt_verde:      .asciz "VERDE"
txt_baixo:      .asciz "BAIXO"
txt_medio:      .asciz "MEDIO"
txt_alto:       .asciz "ALTO"
txt_nao:        .asciz "NAO"
txt_sim:        .asciz "SIM"

    .align 3
tab_cor_carro:  .quad txt_vermelho, txt_amarelo, txt_verde   // indice = bits 11-10
tab_pedestre:   .quad txt_vermelho, txt_verde                // indice = bit 9
tab_fluxo:      .quad txt_baixo, txt_medio, txt_alto         // indice = bits 7-6
tab_pedido:     .quad txt_nao, txt_sim                       // indice = bit 8

    .text
    .global telemetria_valida
    .global telemetria_formata

// ---- telemetria_valida ----
telemetria_valida:
    ubfx    w1, w0, #12, #4
    cmp     w1, #MARCADOR
    b.ne    .Lvalida_nao
    ubfx    w1, w0, #10, #2            // w1 = cor dos carros
    cmp     w1, #3
    b.eq    .Lvalida_nao
    ubfx    w2, w0, #6, #2             // w2 = fluxo
    cmp     w2, #3
    b.eq    .Lvalida_nao
    tbz     w0, #9, .Lvalida_sim       // pedestre vermelho: combina com qualquer cor
    cbnz    w1, .Lvalida_nao           // pedestre verde exige carro vermelho (00)
.Lvalida_sim:
    mov     w0, #1
    ret
.Lvalida_nao:
    mov     w0, #0
    ret

// acrescenta um texto fixo ao destino (x21 = posicao de escrita)
.macro acrescenta rotulo
    mov     x0, x21
    adrp    x1, \rotulo
    add     x1, x1, :lo12:\rotulo
    bl      str_copia
    mov     x21, x0
.endm

// acrescenta o texto da tabela "tabela" na posicao "registrador_indice"
.macro acrescenta_tabela tabela, registrador_indice
    adrp    x9, \tabela
    add     x9, x9, :lo12:\tabela
    ldr     x1, [x9, \registrador_indice, uxtw #3]
    mov     x0, x21
    bl      str_copia
    mov     x21, x0
.endm

// acrescenta um numero em decimal
.macro acrescenta_numero registrador_valor
    mov     x0, \registrador_valor
    mov     x1, x21
    bl      uint_to_dec
    add     x21, x21, x0
.endm

// ---- telemetria_formata ----
// Linha valida:   carros=VERDE pedestres=VERMELHO restante=4s fluxo=BAIXO pedido=SIM
// Linha invalida: QUADRO INVALIDO (valor=N): confira fiacao, GND comum e se a FPGA esta gravada
telemetria_formata:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    str     x21,      [sp, #32]
    and     w19, w0, #0xFFFF           // quadro recebido
    mov     x20, x1                    // inicio do destino
    mov     x21, x1                    // posicao de escrita no destino

    bl      telemetria_valida
    cbz     w0, .Lformata_invalido

    acrescenta txt_carros
    ubfx    w10, w19, #10, #2
    acrescenta_tabela tab_cor_carro, w10
    acrescenta txt_pedestres
    ubfx    w10, w19, #9, #1
    acrescenta_tabela tab_pedestre, w10
    acrescenta txt_restante
    and     x10, x19, #0x3F
    acrescenta_numero x10
    acrescenta txt_segundos
    acrescenta txt_fluxo
    ubfx    w10, w19, #6, #2
    acrescenta_tabela tab_fluxo, w10
    acrescenta txt_pedido
    ubfx    w10, w19, #8, #1
    acrescenta_tabela tab_pedido, w10
    b       .Lformata_fim

.Lformata_invalido:
    acrescenta txt_invalido
    acrescenta_numero x19
    acrescenta txt_dica

.Lformata_fim:
    acrescenta txt_fim_linha
    sub     x0, x21, x20               // caracteres escritos
    ldr     x21,      [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret
