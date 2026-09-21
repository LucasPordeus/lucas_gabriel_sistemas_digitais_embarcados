# Entrega Final — Semáforo Inteligente com Botão de Pedestre (ARM–FPGA)


## Objetivo do projeto consolidado

Um sistema embarcado híbrido ARM (Raspberry Pi Zero 2W) + FPGA (Tang Nano
4K) que controla um cruzamento com travessia de pedestres sob demanda: lê
um sensor de veículos e um botão de pedestre, ajusta dinamicamente o
tempo de verde dos veículos com base no fluxo recente (histórico em BRAM
+ filtro de média móvel em DSP), e comunica-se com o ARM via um protocolo
serial síncrono com handshaking e telemetria. O ARM cuida da configuração
de parâmetros, pré-processamento numérico (incluindo NEON SIMD) e testes
de desempenho; a FPGA garante o determinismo temporal crítico de
segurança do cruzamento (o tempo mínimo de verde dos veículos nunca cai
abaixo de um piso de segurança, mesmo com pedestre esperando e trânsito
baixo).

## Tempo de verde dinâmico (extensão)

Antes desta extensão, `nivel_fluxo` (baixo/médio/alto, calculado por
`bram_historico.v` + `media_movel_dsp.v`) era medido e enviado por
telemetria ao ARM, mas nenhum tempo da FSM reagia a ele — os tempos de
fase eram fixos até serem trocados manualmente via protocolo serial.
Agora `top_semaforo.v` ajusta o tempo mínimo de verde sozinho, sem
depender de nenhum comando do ARM:

| Nível de fluxo medido | Tempo de verde efetivo | Efeito |
|---|---|---|
| Baixo (padrão, sem veículos) | metade do valor de referência (`tempo_min_reg`), com piso de 3 ciclos | pedestre é liberado mais rápido |
| Médio | igual ao valor de referência | comportamento padrão |
| Alto | dobro do valor de referência, com teto de 63 ciclos | veículos escoam mais, pedestre espera mais |

Com o valor de referência padrão (`tempo_min_reg = 10`), isso dá: baixo
= 5, médio = 10, alto = 20 ciclos. Validado em `tb_top_semaforo.v` com um
burst real de 50 veículos (não um valor forçado) até `nivel_fluxo`
realmente virar "alto", comparando o tempo até a liberação do pedestre
nos dois cenários (casos 4 e 5, dentro dos 12/12 do testbench completo,
incluindo a comparação direta trânsito alto > trânsito baixo). Também
foi corrigido, junto com essa extensão, um problema real do TP4/TP5: a
amostra enviada ao filtro de média móvel estava fixa em 1 por veículo, o
que fazia a média nunca sair de "baixo" na integração real — agora ela é
a contagem de veículos numa janela de tempo (`JANELA_AMOSTRAGEM`
ciclos), refletindo a taxa de trânsito de verdade.


## Log em tempo real do countdown (extensão)

A telemetria enviada pela FPGA via `miso` (`protocolo_serial.v`) passou a
carregar a fase atual do semáforo + a contagem regressiva real da fase
corrente, em vez de `nivel_fluxo` + um ponteiro da BRAM (que continuam
funcionais e testados internamente, só não são mais duplicados na
telemetria). O novo programa `asm/monitor_semaforo.s` lê essa telemetria
(simulando o link serial via o buffer circular de `buffer_lib.s`, mesma
metodologia de `main_tp5.s`) e imprime, a cada segundo real
(`nanosleep`), uma linha do tipo:

```
[t=42s] Sinal dos CARROS: VERDE   -> fecha em 1s (fase+contagem decodificados do byte de telemetria via miso)
```

demonstrando os cenários de trânsito baixo (verde fecha em 5s) e alto
(verde fecha em 20s). Validado tanto no Verilog (`tb_top_semaforo.v`,
caso 6, lendo o byte real via `sclk`/`mosi`/`miso`) quanto na execução
real do binário ARM64 diretamente na Raspberry Pi — log completo em
`docs/evidencias/final_project_monitor_semaforo_run.txt`. Detalhes
completos (incluindo o bug real de `strings_lib.s` encontrado e corrigido
ao implementar isso) estão em
`CONTEXTO_PROJETO_SEMAFORO_INTELIGENTE.md`, seção 6.

## Estrutura de pastas

```
final_project/
├── rtl/           -> todos os módulos Verilog do projeto (TP1 a TP5, consolidado)
├── tb/            -> todos os testbenches (11 conjuntos, 100% dos casos passando)
├── constraints/   -> tangnano4k.cst definitivo (protocolo serial de 5 fios)
├── asm/
│   ├── lib/        -> libembarcado.a (gpio_lib, strings_lib, buffer_lib)
│   ├── main_tp5.s   -> programa final ARM (reaproveitado como programa principal)
│   ├── monitor_semaforo.s -> log em tempo real do countdown (extensao pos-TP5)
│   └── (demais programas de cada etapa, mantidos como registro incremental)
├── Makefile
├── README.md (este arquivo)
└── docs/evidencias/         -> todos os logs reais de simulação/execução do TP1 ao TP5
```

O módulo de topo final é `rtl/top_semaforo.v`, e o programa ARM principal
é `asm/main_tp5.s` (usando `libembarcado.a`). Os artefatos dos TPs
anteriores (`estado_basico_decoder.v`, `protocolo_paralelo.v`,
`tp1_fluxo_basico.s` etc.) são mantidos na pasta como registro do
desenvolvimento incremental exigido pelo enunciado, mas não fazem mais
parte do caminho de execução final.
