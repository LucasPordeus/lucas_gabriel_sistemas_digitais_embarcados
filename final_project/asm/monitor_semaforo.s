// monitor_semaforo.s - programa da Raspberry Pi Zero 2W (AArch64, sem libc).
// Monitor somente leitura do semaforo: uma vez por segundo le um quadro de
// telemetria da Tang Nano 4K pelo link serial e imprime o estado:
//
//   [t=12s] carros=VERDE pedestres=VERMELHO restante=4s fluxo=BAIXO pedido=SIM
//
// t = segundos reais desde o inicio do programa (CLOCK_MONOTONIC).
// Nada e' enviado para a FPGA: o semaforo funciona igual com ou sem este
// programa. Roda ate Ctrl+C.
//
// Ligacao (numeracao BCM / pino fisico do header de 40 vias -> pino da Tang Nano 4K):
//   SCLK = GPIO11 / 23 -> 40     CS_N = GPIO6 / 31 -> 42
//   MISO = GPIO20 / 38 <- 33     GND  = pino 39    -- GND da Tang Nano
//
// Saida do processo: 0 nunca (laco infinito); 1 se /dev/gpiomem nao abriu.

PINO_SCLK = 11
PINO_CS_N = 6
PINO_MISO = 20

    .data
msg_titulo:  .ascii "=== Monitor do semaforo (telemetria da Tang Nano 4K, Ctrl+C encerra) ===\n"
len_titulo = . - msg_titulo
msg_erro_gpio: .ascii "ERRO: nao foi possivel mapear /dev/gpiomem (rode na Raspberry Pi com sudo)\n"
len_erro_gpio = . - msg_erro_gpio
txt_prefixo: .asciz "[t="
txt_sufixo:  .asciz "s] "

    .bss
    .align 3
linha: .space 192            // linha montada para impressao
tempo: .space 16             // struct timespec usada por clock_gettime/nanosleep

    .text
    .global _start

// le o relogio monotonico; deixa os segundos em \destino
.macro segundos_monotonicos destino
    mov     x0, #1                     // CLOCK_MONOTONIC
    adrp    x1, tempo
    add     x1, x1, :lo12:tempo
    mov     x8, #113                   // clock_gettime
    svc     #0
    adrp    x1, tempo
    ldr     \destino, [x1, :lo12:tempo]
.endm

_start:
    mov     x0, #1
    adrp    x1, msg_titulo
    add     x1, x1, :lo12:msg_titulo
    mov     x2, #len_titulo
    bl      escreve_fd

    bl      gpio_map_init
    cbz     x0, .Lerro_gpio
    mov     x19, x0                    // x19 = base dos registradores de GPIO

    mov     x0, x19
    mov     w1, #PINO_SCLK
    mov     w2, #PINO_CS_N
    mov     w3, #PINO_MISO
    bl      protocolo_serial_configura_pinos

    segundos_monotonicos x20           // x20 = segundo de inicio

    // uma leitura por volta; so' termina com Ctrl+C
.Lmonitora:
    mov     x0, x19
    mov     w1, #PINO_SCLK
    mov     w2, #PINO_CS_N
    mov     w3, #PINO_MISO
    bl      protocolo_serial_le_quadro
    mov     w21, w0                    // w21 = quadro recebido

    segundos_monotonicos x22
    sub     x22, x22, x20              // x22 = segundos desde o inicio

    // monta "[t=<s>s] " + estado decodificado em "linha"
    adrp    x23, linha
    add     x23, x23, :lo12:linha      // x23 = posicao de escrita na linha
    mov     x0, x23
    adrp    x1, txt_prefixo
    add     x1, x1, :lo12:txt_prefixo
    bl      str_copia
    mov     x23, x0
    mov     x0, x22
    mov     x1, x23
    bl      uint_to_dec
    add     x23, x23, x0
    mov     x0, x23
    adrp    x1, txt_sufixo
    add     x1, x1, :lo12:txt_sufixo
    bl      str_copia
    mov     x23, x0
    mov     w0, w21
    mov     x1, x23
    bl      telemetria_formata
    add     x23, x23, x0

    mov     x0, #1
    adrp    x1, linha
    add     x1, x1, :lo12:linha
    sub     x2, x23, x1
    bl      escreve_fd

    // espera 1 segundo
    adrp    x0, tempo
    add     x0, x0, :lo12:tempo
    mov     x1, #1
    stp     x1, xzr, [x0]              // tv_sec = 1, tv_nsec = 0
    mov     x1, #0
    mov     x8, #101                   // nanosleep
    svc     #0
    b       .Lmonitora

.Lerro_gpio:
    mov     x0, #2
    adrp    x1, msg_erro_gpio
    add     x1, x1, :lo12:msg_erro_gpio
    mov     x2, #len_erro_gpio
    bl      escreve_fd
    mov     x0, #1
    mov     x8, #93                    // exit(1)
    svc     #0
