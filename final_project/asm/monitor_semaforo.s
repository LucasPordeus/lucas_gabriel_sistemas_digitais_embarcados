// monitor_semaforo.s - AArch64 (GAS)
// Simula o log de countdown do semaforo (fase + contagem regressiva,
// formato de protocolo_serial.v/top_semaforo.v) sem hardware conectado:
// monta o byte de telemetria, transmite/recebe via buffer circular de
// libembarcado.a (simulando o shift register serial), decodifica de
// volta e imprime -- cada tick dorme 1s real via nanosleep, e o tempo
// total e' conferido no fim via clock_gettime.
//
// Cenarios (valores de tempo_min_efetivo calculados por top_semaforo.v
// para nivel_fluxo baixo/alto):
//   Cenario 1 (trafego BAIXO): verde=5s, amarelo=3s, pedestre=15s
//   Cenario 2 (trafego ALTO):  verde=20s, amarelo=3s, pedestre=15s

// ---- macro parametrizada: le o clock monotonico ----
.macro le_relogio reg_seg, reg_nseg
    sub     sp, sp, #16
    mov     x0, #1                  // CLOCK_MONOTONIC
    mov     x1, sp
    mov     x8, #113                // clock_gettime
    svc     #0
    ldr     \reg_seg,  [sp, #0]
    ldr     \reg_nseg, [sp, #8]
    add     sp, sp, #16
.endm

    .data
    .align 3
buf_serial:  .space 8
buf_head:    .word 0
buf_tail:    .word 0
tempo_decorrido: .word 0        // segundos reais decorridos (rotulo [t=Ns])

msg_titulo: .ascii "=== Log em tempo real do semaforo (Raspberry Pi, via telemetria serial) ===\n"
len_titulo = . - msg_titulo

msg_cenario1: .ascii "\n--- Cenario 1: trafego BAIXO medido pela FPGA (tempo_min_efetivo=5s) ---\n"
len_cenario1 = . - msg_cenario1

msg_cenario2: .ascii "\n--- Cenario 2: trafego ALTO medido pela FPGA (tempo_min_efetivo=20s) ---\n"
len_cenario2 = . - msg_cenario2

msg_prefixo_t: .ascii "[t="
len_prefixo_t = . - msg_prefixo_t

msg_carro_verde: .ascii "s] Sinal dos CARROS: VERDE   -> fecha em "
len_carro_verde = . - msg_carro_verde

msg_carro_amarelo: .ascii "s] Sinal dos CARROS: AMARELO -> fecha em "
len_carro_amarelo = . - msg_carro_amarelo

msg_pedestre_verde: .ascii "s] Sinal do PEDESTRE: VERDE  -> fecha em "
len_pedestre_verde = . - msg_pedestre_verde

msg_sufixo: .ascii "s (fase+contagem decodificados do byte de telemetria via miso)\n"
len_sufixo = . - msg_sufixo

msg_fim1: .ascii "\n=== fim da simulacao -- tempo real total decorrido: "
len_fim1 = . - msg_fim1
msg_fim2: .ascii " ns (esperado ~= 61000000000 ns, 61 segundos reais) ===\n"
len_fim2 = . - msg_fim2

numbuf: .space 20

    .text
    .global _start
_start:
    bl      gpio_map_init            // demonstra reuso da biblioteca (mapeamento simulado)

    adrp    x1, msg_titulo
    add     x1, x1, :lo12:msg_titulo
    mov     x0, #1
    mov     x2, #len_titulo
    bl      escreve_fd

    le_relogio x25, x26              // x25=segundos x26=nanossegundos (inicio real)

    // ---- Cenario 1: trafego BAIXO (verde=5s, amarelo=3s, pedestre=15s) ----
    adrp    x1, msg_cenario1
    add     x1, x1, :lo12:msg_cenario1
    mov     x0, #1
    mov     x2, #len_cenario1
    bl      escreve_fd

    mov     x0, #2                  // fase=VERDE
    mov     x1, #5                  // duracao=5s (metade do padrao, trafego baixo)
    bl      roda_fase
    mov     x0, #1                  // fase=AMARELO
    mov     x1, #3
    bl      roda_fase
    mov     x0, #0                  // fase=PEDESTRE_VERDE
    mov     x1, #15
    bl      roda_fase

    // ---- Cenario 2: trafego ALTO (verde=20s, amarelo=3s, pedestre=15s) ----
    adrp    x1, msg_cenario2
    add     x1, x1, :lo12:msg_cenario2
    mov     x0, #1
    mov     x2, #len_cenario2
    bl      escreve_fd

    mov     x0, #2                  // fase=VERDE
    mov     x1, #20                 // duracao=20s (dobro do padrao, trafego alto)
    bl      roda_fase
    mov     x0, #1                  // fase=AMARELO
    mov     x1, #3
    bl      roda_fase
    mov     x0, #0                  // fase=PEDESTRE_VERDE
    mov     x1, #15
    bl      roda_fase

    le_relogio x27, x28              // x27=segundos x28=nanossegundos (fim real)

    // delta em ns = (x27-x25)*1e9 + (x28-x26)  (mesmo calculo de main_tp5.s)
    sub     x0, x27, x25
    movz    x1, #0xCA00
    movk    x1, #0x3B9A, lsl #16
    mul     x0, x0, x1
    sub     x1, x28, x26
    add     x9, x0, x1               // x9 = tempo real total em ns

    adrp    x1, msg_fim1
    add     x1, x1, :lo12:msg_fim1
    mov     x0, #1
    mov     x2, #len_fim1
    bl      escreve_fd

    mov     x0, x9
    adrp    x1, numbuf
    add     x1, x1, :lo12:numbuf
    bl      uint_to_dec
    mov     x2, x0
    adrp    x1, numbuf
    add     x1, x1, :lo12:numbuf
    mov     x0, #1
    bl      escreve_fd

    adrp    x1, msg_fim2
    add     x1, x1, :lo12:msg_fim2
    mov     x0, #1
    mov     x2, #len_fim2
    bl      escreve_fd

    mov     x0, #0
    mov     x8, #93                  // exit
    svc     #0

// ---- roda_fase(x0=fase [0=pedestre_verde,1=amarelo,2=verde], x1=duracao) ----
// Para cada segundo restante (duracao ... 1), monta o byte de telemetria,
// "transmite" via o buffer circular (simulando o link serial), decodifica
// de volta, imprime a linha do countdown e dorme 1 segundo real.
roda_fase:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    str     x20, [sp, #24]
    mov     x19, x0                  // x19 = fase
    mov     x20, x1                  // x20 = contagem (loop, decrementa a cada tick)

.Lroda_loop:
    cbz     x20, .Lroda_fim

    // monta o byte de telemetria: [7:6]=fase [5:0]=contagem (igual ao
    // shift_out de protocolo_serial.v)
    lsl     x10, x19, #6
    orr     x10, x10, x20

    // "transmite": grava no buffer circular (simula o shift register
    // deslocando o byte para fora via miso)
    adrp    x0, buf_serial
    add     x0, x0, :lo12:buf_serial
    mov     x1, #8
    adrp    x2, buf_head
    add     x2, x2, :lo12:buf_head
    adrp    x3, buf_tail
    add     x3, x3, :lo12:buf_tail
    mov     x4, x10
    bl      cbuf_push

    // "recebe": le de volta o mesmo byte (round-trip completo, igual ao
    // que main_tp5.s faz para simular push+pop do protocolo)
    adrp    x0, buf_serial
    add     x0, x0, :lo12:buf_serial
    mov     x1, #8
    adrp    x2, buf_head
    add     x2, x2, :lo12:buf_head
    adrp    x3, buf_tail
    add     x3, x3, :lo12:buf_tail
    bl      cbuf_pop                 // w0 = byte lido

    // decodifica: fase_lida=[7:6], contagem_lida=[5:0] -- guarda em
    // registradores fora da faixa que uint_to_dec usa internamente
    // (x0-x12), pra sobreviver as chamadas de impressao abaixo.
    lsr     x12, x0, #6
    and     x12, x12, #3             // fase_lida (temporario)
    and     x21, x0, #63             // x21 = contagem_lida (seguro)

    cmp     x12, #2
    b.eq    .Lroda_label_verde
    cmp     x12, #1
    b.eq    .Lroda_label_amarelo
    adrp    x22, msg_pedestre_verde
    add     x22, x22, :lo12:msg_pedestre_verde
    mov     x23, #len_pedestre_verde
    b       .Lroda_imprime
.Lroda_label_verde:
    adrp    x22, msg_carro_verde
    add     x22, x22, :lo12:msg_carro_verde
    mov     x23, #len_carro_verde
    b       .Lroda_imprime
.Lroda_label_amarelo:
    adrp    x22, msg_carro_amarelo
    add     x22, x22, :lo12:msg_carro_amarelo
    mov     x23, #len_carro_amarelo

.Lroda_imprime:
    // "[t="
    adrp    x1, msg_prefixo_t
    add     x1, x1, :lo12:msg_prefixo_t
    mov     x0, #1
    mov     x2, #len_prefixo_t
    bl      escreve_fd

    // numero de segundos reais decorridos desde o inicio
    adrp    x9, tempo_decorrido
    add     x9, x9, :lo12:tempo_decorrido
    ldr     w0, [x9]
    adrp    x1, numbuf
    add     x1, x1, :lo12:numbuf
    bl      uint_to_dec
    mov     x2, x0
    adrp    x1, numbuf
    add     x1, x1, :lo12:numbuf
    mov     x0, #1
    bl      escreve_fd

    // rotulo escolhido acima (ex.: "s] Sinal dos CARROS: VERDE -> fecha em ")
    mov     x1, x22
    mov     x2, x23
    mov     x0, #1
    bl      escreve_fd

    // contagem regressiva decodificada (x21)
    mov     x0, x21
    adrp    x1, numbuf
    add     x1, x1, :lo12:numbuf
    bl      uint_to_dec
    mov     x2, x0
    adrp    x1, numbuf
    add     x1, x1, :lo12:numbuf
    mov     x0, #1
    bl      escreve_fd

    // "s (fase+contagem decodificados ...)\n"
    adrp    x1, msg_sufixo
    add     x1, x1, :lo12:msg_sufixo
    mov     x0, #1
    mov     x2, #len_sufixo
    bl      escreve_fd

    // dorme exatamente 1 segundo real (nanosleep) -- e' isso que torna
    // este log "em tempo real", nao uma simulacao instantanea
    sub     sp, sp, #16
    mov     x0, #1
    str     x0, [sp, #0]             // tv_sec = 1
    mov     x0, #0
    str     x0, [sp, #8]             // tv_nsec = 0
    mov     x0, sp
    mov     x1, #0
    mov     x8, #101                 // nanosleep
    svc     #0
    add     sp, sp, #16

    // incrementa o contador de segundos reais decorridos
    adrp    x9, tempo_decorrido
    add     x9, x9, :lo12:tempo_decorrido
    ldr     w0, [x9]
    add     w0, w0, #1
    str     w0, [x9]

    sub     x20, x20, #1
    b       .Lroda_loop

.Lroda_fim:
    ldr     x19, [sp, #16]
    ldr     x20, [sp, #24]
    ldp     x29, x30, [sp], #32
    ret
