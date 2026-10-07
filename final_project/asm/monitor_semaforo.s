// monitor_semaforo_hw.s - AArch64 (GAS)
// Versao simplificada: bit-banga de verdade os 5 pinos GPIO da Raspberry
// Pi (usando protocolo_serial_gpio.s) e imprime SO' se o sinal do
// pedestre esta aberto ou fechado agora, lendo a telemetria real
// devolvida pela Tang Nano 4K.
//
// Pinagem usada (numeracao BCM, pinos fisicos do conector de 40 vias):
//   SCLK -> GPIO11 (pino fisico 23)
//   CS_N -> GPIO6  (pino fisico 31)
//   MOSI -> GPIO10 (pino fisico 19)
//   MISO -> GPIO20 (pino fisico 38)
// No lado da Tang Nano 4K, os pinos do protocolo serial estao fixados em
// constraints/tangnano4k.cst: sclk=39 cs_n=40 mosi=41 miso=42 busy=43.
// Ambas as placas trabalham em 3,3V, entao a ligacao e' direta, sem
// conversor de nivel -- MAS LEMBRE-SE de ligar tambem o GND da Raspberry
// Pi ao GND da Tang Nano 4K (referencia comum obrigatoria).
//
// A cada poll (1 por segundo, via nanosleep -- tempo real, nao simulado),
// este programa envia o comando "OP_TEMPO_MIN=10" (0x0A): reafirma o
// tempo minimo de verde padrao, ou seja, e' inocuo/idempotente -- so'
// serve pra ter um byte valido pra clockar e receber a telemetria de
// volta por miso.
//
// So' usamos os 4 bits baixos do byte de telemetria (ver rtl/
// top_semaforo.v): tempo_ate_pedestre, truncado para 4 bits (0-15) --
// quando chega em 0, o sinal do pedestre ja esta aberto de verdade.
//
// Roda PARA SEMPRE (Ctrl+C pra encerrar).

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
tempo_decorrido: .word 0

PINO_SCLK    = 11
PINO_CS_N    = 6
PINO_MOSI    = 10
PINO_MISO    = 20
CMD_KEEPALIVE = 0x0A      // OP_TEMPO_MIN(00) | valor=10 (reafirma o padrao, inocuo)

msg_titulo: .ascii "=== Monitor REAL do sinal do pedestre (GPIO bit-banged, Raspberry Pi <-> Tang Nano 4K) ===\n"
len_titulo = . - msg_titulo

msg_pinagem: .ascii "Pinos (BCM): SCLK=GPIO11 CS_N=GPIO6 MOSI=GPIO10 MISO=GPIO20 -- confira a ligacao antes de continuar! (Ctrl+C para encerrar)\n"
len_pinagem = . - msg_pinagem

msg_prefixo_t: .ascii "[t="
len_prefixo_t = . - msg_prefixo_t

msg_sufixo_t: .ascii "s] "
len_sufixo_t = . - msg_sufixo_t

msg_pedestre_aberto: .ascii "ABERTO PARA O PEDESTRE\n"
len_pedestre_aberto = . - msg_pedestre_aberto

msg_pedestre_fechado: .ascii "FECHADO PARA PEDESTRE\n"
len_pedestre_fechado = . - msg_pedestre_fechado

numbuf: .space 20

    .text
    .global _start
_start:
    adrp    x1, msg_titulo
    add     x1, x1, :lo12:msg_titulo
    mov     x0, #1
    mov     x2, #len_titulo
    bl      escreve_fd

    adrp    x1, msg_pinagem
    add     x1, x1, :lo12:msg_pinagem
    mov     x0, #1
    mov     x2, #len_pinagem
    bl      escreve_fd

    bl      gpio_map_init            // x0 = base (real via /dev/gpiomem, ou simulada)
    mov     x19, x0                  // x19 = base, preservado pelo resto do programa

    mov     x0, x19
    mov     w1, #PINO_SCLK
    mov     w2, #PINO_CS_N
    mov     w3, #PINO_MOSI
    mov     w4, #PINO_MISO
    bl      protocolo_serial_configura_pinos

.Lpoll_loop:
    mov     x0, x19
    mov     w1, #PINO_SCLK
    mov     w2, #PINO_CS_N
    mov     w3, #PINO_MOSI
    mov     w4, #PINO_MISO
    mov     w5, #CMD_KEEPALIVE
    bl      protocolo_serial_transfere   // w0 = byte de telemetria real

    and     x22, x0, #15             // x22 = tempo_ate_pedestre (4 bits, segura entre chamadas)

    adrp    x1, msg_prefixo_t
    add     x1, x1, :lo12:msg_prefixo_t
    mov     x0, #1
    mov     x2, #len_prefixo_t
    bl      escreve_fd

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

    adrp    x1, msg_sufixo_t
    add     x1, x1, :lo12:msg_sufixo_t
    mov     x0, #1
    mov     x2, #len_sufixo_t
    bl      escreve_fd

    cmp     x22, #0
    b.ne    .Lfechado
    adrp    x1, msg_pedestre_aberto
    add     x1, x1, :lo12:msg_pedestre_aberto
    mov     x2, #len_pedestre_aberto
    b       .Limprime
.Lfechado:
    adrp    x1, msg_pedestre_fechado
    add     x1, x1, :lo12:msg_pedestre_fechado
    mov     x2, #len_pedestre_fechado

.Limprime:
    mov     x0, #1
    bl      escreve_fd

    // dorme 1 segundo real antes do proximo poll
    sub     sp, sp, #16
    mov     x0, #1
    str     x0, [sp, #0]
    mov     x0, #0
    str     x0, [sp, #8]
    mov     x0, sp
    mov     x1, #0
    mov     x8, #101                 // nanosleep
    svc     #0
    add     sp, sp, #16

    adrp    x9, tempo_decorrido
    add     x9, x9, :lo12:tempo_decorrido
    ldr     w0, [x9]
    add     w0, w0, #1
    str     w0, [x9]

    b       .Lpoll_loop              // roda para sempre -- Ctrl+C encerra
