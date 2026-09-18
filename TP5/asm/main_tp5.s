// main_tp5.s - AArch64 (GAS)
// Programa principal do TP5: usa libembarcado.a (gpio_lib, strings_lib,
// buffer_lib), demonstra macros parametrizadas para montar comandos do
// protocolo serial, gerencia um buffer circular de telemetria, e executa
// um teste continuo de desempenho (throughput e latencia media) de N
// transacoes simuladas com o protocolo FPGA, medindo o tempo real via
// clock_gettime (CLOCK_MONOTONIC).
//
// Uma "transacao" aqui e' o equivalente em software ao quadro serial de 8
// bits do protocolo_serial.v (TP5): monta um comando, "envia" (grava em
// buffer, simulando o shift register), e le a telemetria de volta
// (extraida do buffer). Isso permite medir o overhead de software da
// pilha de comunicacao mesmo sem hardware fisico conectado.

// ---- macro parametrizada: monta um byte de comando (opcode+valor) ----
// monta_comando destino, opcode, valor  =>  destino = (opcode<<6) | valor
.macro monta_comando dst, opcode, valor
    mov     \dst, \opcode
    lsl     \dst, \dst, #6
    orr     \dst, \dst, \valor
.endm

// ---- macro parametrizada: le o clock monotonico para um par de registradores ----
// le_relogio reg_seg, reg_nseg  => usa struct timespec na pilha
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
buf_telemetria: .space 32
buf_head:       .word 0
buf_tail:       .word 0

N_TRANSACOES = 2000

msg_inicio: .ascii "Iniciando teste de desempenho: "
len_inicio = . - msg_inicio
msg_transacoes: .ascii " transacoes simuladas com a FPGA...\n"
len_transacoes = . - msg_transacoes
msg_resultado_ns: .ascii "Tempo total: "
len_resultado_ns = . - msg_resultado_ns
msg_ns: .ascii " ns\n"
len_ns = . - msg_ns
msg_throughput: .ascii "Throughput: "
len_throughput = . - msg_throughput
msg_tps: .ascii " transacoes/segundo (aprox.)\n"
len_tps = . - msg_tps
msg_latencia: .ascii "Latencia media por transacao: "
len_latencia = . - msg_latencia
msg_nspertx: .ascii " ns\n"
len_nspertx = . - msg_nspertx
msg_aviso: .ascii "(valores absolutos dependem do hardware onde for executado; a\nmetodologia de medicao via clock_gettime e' a mesma em qualquer aarch64)\n"
len_aviso = . - msg_aviso

numbuf: .space 20

    .text
    .global _start
_start:
    bl      gpio_map_init            // demonstra reuso da biblioteca (mapeamento simulado)
    mov     x19, x0                  // x19 = base GPIO (nao usada diretamente neste teste)

    adrp    x1, msg_inicio
    add     x1, x1, :lo12:msg_inicio
    mov     x0, #1
    mov     x2, #len_inicio
    bl      escreve_fd

    mov     x0, #N_TRANSACOES
    adrp    x1, numbuf
    add     x1, x1, :lo12:numbuf
    bl      uint_to_dec
    mov     x20, x0                  // x20 = comprimento do numero impresso
    adrp    x1, numbuf
    add     x1, x1, :lo12:numbuf
    mov     x2, x20
    mov     x0, #1
    bl      escreve_fd

    adrp    x1, msg_transacoes
    add     x1, x1, :lo12:msg_transacoes
    mov     x0, #1
    mov     x2, #len_transacoes
    bl      escreve_fd

    // ---- marca o tempo inicial ----
    le_relogio x21, x22              // x21=segundos x22=nanossegundos (inicio)

    // ---- loop de N_TRANSACOES simuladas ----
    mov     x23, #0                  // x23 = contador de transacoes
.Lloop_transacoes:
    cmp     x23, #N_TRANSACOES
    b.ge    .Lloop_fim

    // monta um comando de exemplo (opcode variando 0-3, valor = contador mod 64)
    and     x0, x23, #3              // opcode = contador mod 4
    and     x1, x23, #63             // valor  = contador mod 64
    monta_comando x2, x0, x1         // x2 = comando montado (macro parametrizada)

    // "envia" via buffer circular (equivalente software ao shift register serial)
    adrp    x0, buf_telemetria
    add     x0, x0, :lo12:buf_telemetria
    mov     x1, #32
    adrp    x3, buf_head
    add     x3, x3, :lo12:buf_head
    adrp    x4, buf_tail
    add     x4, x4, :lo12:buf_tail
    mov     x5, x2
    // cbuf_push espera x0,x1,x2,x3,x4 = data,cap,head_addr,tail_addr,byte
    mov     x2, x3
    mov     x3, x4
    mov     x4, x5
    bl      cbuf_push

    // le de volta (drena o buffer no mesmo passo, simulando round-trip completo)
    adrp    x0, buf_telemetria
    add     x0, x0, :lo12:buf_telemetria
    mov     x1, #32
    adrp    x2, buf_head
    add     x2, x2, :lo12:buf_head
    adrp    x3, buf_tail
    add     x3, x3, :lo12:buf_tail
    bl      cbuf_pop

    add     x23, x23, #1
    b       .Lloop_transacoes
.Lloop_fim:

    // ---- marca o tempo final ----
    le_relogio x24, x25              // x24=segundos x25=nanossegundos (fim)

    // calcula delta em nanossegundos: (x24-x21)*1e9 + (x25-x22)
    sub     x0, x24, x21
    movz    x1, #0xCA00              // constroi 1_000_000_000 (0x3B9ACA00) em 2 instrucoes,
    movk    x1, #0x3B9A, lsl #16     // pois o valor nao cabe num unico MOVZ de 16 bits
    mul     x0, x0, x1
    sub     x1, x25, x22
    add     x26, x0, x1              // x26 = tempo total em ns

    adrp    x1, msg_resultado_ns
    add     x1, x1, :lo12:msg_resultado_ns
    mov     x0, #1
    mov     x2, #len_resultado_ns
    bl      escreve_fd

    mov     x0, x26
    adrp    x1, numbuf
    add     x1, x1, :lo12:numbuf
    bl      uint_to_dec
    mov     x2, x0
    adrp    x1, numbuf
    add     x1, x1, :lo12:numbuf
    mov     x0, #1
    bl      escreve_fd

    adrp    x1, msg_ns
    add     x1, x1, :lo12:msg_ns
    mov     x0, #1
    mov     x2, #len_ns
    bl      escreve_fd

    // throughput = N_TRANSACOES * 1e9 / tempo_total_ns  (transacoes/segundo)
    mov     x0, #N_TRANSACOES
    movz    x1, #0xCA00
    movk    x1, #0x3B9A, lsl #16
    mul     x0, x0, x1
    udiv    x27, x0, x26              // x27 = throughput (transacoes/s)

    adrp    x1, msg_throughput
    add     x1, x1, :lo12:msg_throughput
    mov     x0, #1
    mov     x2, #len_throughput
    bl      escreve_fd

    mov     x0, x27
    adrp    x1, numbuf
    add     x1, x1, :lo12:numbuf
    bl      uint_to_dec
    mov     x2, x0
    adrp    x1, numbuf
    add     x1, x1, :lo12:numbuf
    mov     x0, #1
    bl      escreve_fd

    adrp    x1, msg_tps
    add     x1, x1, :lo12:msg_tps
    mov     x0, #1
    mov     x2, #len_tps
    bl      escreve_fd

    // latencia media = tempo_total_ns / N_TRANSACOES
    mov     x1, #N_TRANSACOES
    udiv    x28, x26, x1

    adrp    x1, msg_latencia
    add     x1, x1, :lo12:msg_latencia
    mov     x0, #1
    mov     x2, #len_latencia
    bl      escreve_fd

    mov     x0, x28
    adrp    x1, numbuf
    add     x1, x1, :lo12:numbuf
    bl      uint_to_dec
    mov     x2, x0
    adrp    x1, numbuf
    add     x1, x1, :lo12:numbuf
    mov     x0, #1
    bl      escreve_fd

    adrp    x1, msg_nspertx
    add     x1, x1, :lo12:msg_nspertx
    mov     x0, #1
    mov     x2, #len_nspertx
    bl      escreve_fd

    adrp    x1, msg_aviso
    add     x1, x1, :lo12:msg_aviso
    mov     x0, #1
    mov     x2, #len_aviso
    bl      escreve_fd

    mov     x0, #0
    mov     x8, #93
    svc     #0
