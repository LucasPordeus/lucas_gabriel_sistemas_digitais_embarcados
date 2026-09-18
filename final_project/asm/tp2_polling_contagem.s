// tp2_polling_contagem.s - AArch64 (GAS)
// Rotina estruturada que simula o polling do registrador de status
// enviado pela FPGA (mecanismo de interacao ARM-FPGA proposto para o
// protocolo paralelo do TP3: bit0 = sensor_estavel, bit1 = solicitacao_pedestre).
// Cada amostra do vetor "status_capturado" representa um poll consecutivo.
// Usa registradores, LDR/STR, CMP, B e loops, com decisao por bitfields.
//
// Protocolo de sinais proposto (formalizado em Verilog no TP3):
//   status[0] = sensor_estavel (saida da FPGA)
//   status[1] = solicitacao_pedestre (saida da FPGA, latch)
//   strobe    = 1 pulso da FPGA cada vez que "status" e atualizado
// Aqui a linha de strobe e simulada implicitamente (uma amostra por poll).
//
// Registradores callee-saved (x19-x24) guardam o estado persistente do
// loop, pois x0-x2/x8 sao usados pelas sub-rotinas de impressao (syscall
// write) e nao podem guardar estado entre chamadas "bl".

    .data
status_capturado:
    // bit0=sensor bit1=botao, um byte por ciclo de polling
    .byte 0b00, 0b01, 0b01, 0b00, 0b11, 0b10, 0b10, 0b00, 0b01, 0b00, 0b10, 0b00
N_POLLS = 12

contagem_veiculos:      .byte 0
contagem_solicitacoes:  .byte 0

msg_veiculo:      .ascii "[poll] veiculo detectado (borda de subida do sensor)\n"
len_veiculo = . - msg_veiculo
msg_solicitacao:  .ascii "[poll] solicitacao de pedestre recebida (borda do botao)\n"
len_solicitacao = . - msg_solicitacao
msg_resumo:       .ascii "Resumo: veiculos="
len_resumo = . - msg_resumo
msg_solic2:       .ascii " solicitacoes="
len_solic2 = . - msg_solic2
digitos: .ascii "0123456789"
nl: .ascii "\n"

    .text
    .global _start
_start:
    mov     x19, #0                      // x19 = indice do poll
    mov     x20, #0                      // x20 = bit0 (sensor) da amostra anterior
    mov     x21, #0                      // x21 = contador de veiculos
    mov     x22, #0                      // x22 = contador de solicitacoes
    mov     x24, #0                      // x24 = bit1 (botao) da amostra anterior
    adrp    x23, status_capturado
    add     x23, x23, :lo12:status_capturado

poll_loop:
    cmp     x19, #N_POLLS
    b.ge    poll_fim                     // decisao: fim do vetor de polls?

    ldrb    w5, [x23, x19]               // LDR: le a amostra de status atual

    and     w6, w5, #0b01                // isola bit0 (sensor)
    cmp     w6, w20
    b.eq    sem_borda_sensor             // decisao: sem transicao no sensor?
    cbz     w20, borda_subida_sensor     // bit anterior era 0 -> borda de subida
    b       sem_borda_sensor             // borda de descida: nao conta

borda_subida_sensor:
    add     x21, x21, #1
    bl      imprime_veiculo

sem_borda_sensor:
    mov     x20, x6                      // atualiza bit0 anterior

    lsr     w7, w5, #1
    and     w7, w7, #0b01                // isola bit1 (solicitacao), normalizado p/ 0/1
    cmp     w7, w24
    b.eq    proximo_poll                 // decisao: sem transicao na solicitacao?
    cbz     w24, borda_subida_botao      // bit anterior era 0 -> nova solicitacao
    b       proximo_poll

borda_subida_botao:
    add     x22, x22, #1
    bl      imprime_solicitacao

proximo_poll:
    mov     x24, x7                      // atualiza bit1 anterior
    add     x19, x19, #1
    b       poll_loop

poll_fim:
    adrp    x8, contagem_veiculos
    add     x8, x8, :lo12:contagem_veiculos
    strb    w21, [x8]                    // STR: persiste contagem final de veiculos

    adrp    x8, contagem_solicitacoes
    add     x8, x8, :lo12:contagem_solicitacoes
    strb    w22, [x8]                    // STR: persiste contagem final de solicitacoes

    bl      imprime_resumo

    mov     x0, #0
    mov     x8, #93
    svc     #0

// ---- sub-rotinas de impressao (write syscall); usam apenas x0-x2,x8,x9 ----
imprime_veiculo:
    stp     x29, x30, [sp, #-16]!
    adrp    x1, msg_veiculo
    add     x1, x1, :lo12:msg_veiculo
    mov     x0, #1
    mov     x2, #len_veiculo
    mov     x8, #64
    svc     #0
    ldp     x29, x30, [sp], #16
    ret

imprime_solicitacao:
    stp     x29, x30, [sp, #-16]!
    adrp    x1, msg_solicitacao
    add     x1, x1, :lo12:msg_solicitacao
    mov     x0, #1
    mov     x2, #len_solicitacao
    mov     x8, #64
    svc     #0
    ldp     x29, x30, [sp], #16
    ret

imprime_resumo:
    stp     x29, x30, [sp, #-16]!
    adrp    x1, msg_resumo
    add     x1, x1, :lo12:msg_resumo
    mov     x0, #1
    mov     x2, #len_resumo
    mov     x8, #64
    svc     #0

    adrp    x9, digitos
    add     x9, x9, :lo12:digitos
    add     x1, x9, x21                  // x21 (veiculos) usado como indice na tabela
    mov     x0, #1
    mov     x2, #1
    mov     x8, #64
    svc     #0

    adrp    x1, msg_solic2
    add     x1, x1, :lo12:msg_solic2
    mov     x0, #1
    mov     x2, #len_solic2
    mov     x8, #64
    svc     #0

    add     x1, x9, x22                  // x22 (solicitacoes) usado como indice
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
