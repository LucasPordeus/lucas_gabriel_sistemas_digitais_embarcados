// monitor_semaforo_hw.s - AArch64 (GAS)
// Versao "hardware real" de monitor_semaforo.s: em vez de simular o
// round-trip do protocolo serial internamente via buffer_lib.s, este
// programa bit-banga de verdade os 5 pinos GPIO da Raspberry Pi (usando
// protocolo_serial_gpio.s) e imprime a telemetria que a Tang Nano 4K
// realmente devolveu.
//
// Pinagem usada (numeracao BCM, pinos fisicos do conector de 40 vias):
//   SCLK -> GPIO5  (pino fisico 29)
//   CS_N -> GPIO6  (pino fisico 31)
//   MOSI -> GPIO13 (pino fisico 33)
//   MISO -> GPIO19 (pino fisico 35)
//   (nao usamos "busy" aqui -- ver aviso em protocolo_serial_gpio.s sobre
//   por que o pulso de 1 ciclo de "busy" nao e' confiavel de ler via
//   polling em software)
// No lado da Tang Nano 4K, os pinos ja estao fixados em
// constraints/tangnano4k.cst: sclk=39 cs_n=40 mosi=41 miso=42 busy=43
// (numeros do chip Gowin -- confira o pinout oficial da Sipeed para saber
// a qual furo fisico da placa cada numero corresponde antes de ligar
// qualquer fio). Ambas as placas trabalham em 3,3V, entao a ligacao e'
// direta, sem conversor de nivel -- MAS LEMBRE-SE de ligar tambem o GND
// da Raspberry Pi ao GND da Tang Nano 4K (referencia comum obrigatoria).
//
// A cada poll (1 por segundo, via nanosleep -- tempo real, nao simulado),
// este programa envia o comando "OP_TEMPO_MIN=10" (0x0A): reafirma o
// tempo minimo de verde padrao, ou seja, e' inocuo/idempotente -- nao
// muda nada no estado da FPGA, serve so' para ter um byte valido pra
// clockar e assim receber a telemetria de volta por miso. Roda um numero
// fixo de polls (ver N_POLLS) e termina sozinho.
//

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

PINO_SCLK    = 5
PINO_CS_N    = 6
PINO_MOSI    = 13
PINO_MISO    = 19
CMD_KEEPALIVE = 0x0A      // OP_TEMPO_MIN(00) | valor=10 (reafirma o padrao, inocuo)
N_POLLS      = 20

msg_titulo: .ascii "=== Monitor REAL do semaforo (GPIO bit-banged, Raspberry Pi <-> Tang Nano 4K) ===\n"
len_titulo = . - msg_titulo

msg_pinagem: .ascii "Pinos (BCM): SCLK=GPIO5 CS_N=GPIO6 MOSI=GPIO13 MISO=GPIO19 -- confira a ligacao antes de continuar!\n"
len_pinagem = . - msg_pinagem

msg_prefixo_t: .ascii "[t="
len_prefixo_t = . - msg_prefixo_t

msg_carro_vermelho: .ascii "s] telemetria real: CARROS=VERMELHO(ou pedestre atravessando) contagem="
len_carro_vermelho = . - msg_carro_vermelho

msg_carro_amarelo: .ascii "s] telemetria real: CARROS=AMARELO contagem="
len_carro_amarelo = . - msg_carro_amarelo

msg_carro_verde: .ascii "s] telemetria real: CARROS=VERDE contagem="
len_carro_verde = . - msg_carro_verde

msg_sufixo: .ascii "\n"
len_sufixo = . - msg_sufixo

msg_fim: .ascii "=== fim do monitor real -- programa encerrado normalmente ===\n"
len_fim = . - msg_fim

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

    mov     x21, #N_POLLS            // x21 = polls restantes

.Lpoll_loop:
    cbz     x21, .Lpoll_fim

    mov     x0, x19
    mov     w1, #PINO_SCLK
    mov     w2, #PINO_CS_N
    mov     w3, #PINO_MOSI
    mov     w4, #PINO_MISO
    mov     w5, #CMD_KEEPALIVE
    bl      protocolo_serial_transfere   // w0 = byte de telemetria real

    lsr     x12, x0, #6
    and     x12, x12, #3             // fase lida (temporario)
    and     x22, x0, #63             // x22 = contagem lida (seguro entre chamadas)

    cmp     x12, #2
    b.eq    .Llabel_verde
    cmp     x12, #1
    b.eq    .Llabel_amarelo
    adrp    x23, msg_carro_vermelho
    add     x23, x23, :lo12:msg_carro_vermelho
    mov     x24, #len_carro_vermelho
    b       .Limprime
.Llabel_verde:
    adrp    x23, msg_carro_verde
    add     x23, x23, :lo12:msg_carro_verde
    mov     x24, #len_carro_verde
    b       .Limprime
.Llabel_amarelo:
    adrp    x23, msg_carro_amarelo
    add     x23, x23, :lo12:msg_carro_amarelo
    mov     x24, #len_carro_amarelo

.Limprime:
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

    mov     x1, x23
    mov     x2, x24
    mov     x0, #1
    bl      escreve_fd

    mov     x0, x22
    adrp    x1, numbuf
    add     x1, x1, :lo12:numbuf
    bl      uint_to_dec
    mov     x2, x0
    adrp    x1, numbuf
    add     x1, x1, :lo12:numbuf
    mov     x0, #1
    bl      escreve_fd

    adrp    x1, msg_sufixo
    add     x1, x1, :lo12:msg_sufixo
    mov     x0, #1
    mov     x2, #len_sufixo
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

    sub     x21, x21, #1
    b       .Lpoll_loop

.Lpoll_fim:
    adrp    x1, msg_fim
    add     x1, x1, :lo12:msg_fim
    mov     x0, #1
    mov     x2, #len_fim
    bl      escreve_fd

    mov     x0, #0
    mov     x8, #93                  // exit
    svc     #0
