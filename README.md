# Semáforo Inteligente com Botão de Pedestre — Contexto e Funcionamento

> Projeto de Bloco: Sistemas Digitais Embarcados — Instituto Infnet
> Aluno: Lucas Gabriel de Oliveira Pordeus Campos | Professor: Dácio Moreira de Souza
> Desenvolvimento incremental: TP1 → TP2 → TP3 → TP4 → TP5 → Entrega Final

## 1. O que é o projeto

Um sistema embarcado híbrido que controla um cruzamento de trânsito com
travessia de pedestres sob demanda, dividido entre duas plataformas de
hardware que se comunicam entre si:

- **FPGA Tang Nano 4K** (chip GW1NSR-LV4C): executa toda a lógica com
  requisito de tempo real e segurança crítica — a máquina de estados do
  semáforo, a leitura dos sensores, o acionamento dos LEDs. Escrita em
  **Verilog**.
- **Raspberry Pi Zero 2W**: cuida da configuração de parâmetros, do
  pré-processamento numérico e da medição de desempenho da comunicação.
  Escrita em **Assembly ARM64 (AArch64)**.

A ideia central da arquitetura é: a FPGA nunca depende do ARM para
garantir segurança (o tempo mínimo de verde dos veículos nunca é
reduzido, mesmo sem nenhum comando chegar do ARM), e o ARM nunca precisa
lidar com temporização em nível de ciclo de clock — só manda comandos e
lê telemetria.

### Hardware físico usado

- FPGA Tang Nano 4K (Sipeed)
- Raspberry Pi Zero 2W
- Sensor de obstáculo reflexivo infravermelho (IR), saída digital direta
  em 3,3V — detecta veículos
- Botão de pedestre (push-button) com resistor de pull-down de 10 kΩ
- 5 LEDs com resistor de 220 Ω cada: vermelho/amarelo/verde (veículos) +
  verde/vermelho (pedestre)
- Protoboard, jumpers, cabos USB-C e micro-USB

## 2. Por que o projeto é dividido em 6 entregas

O enunciado da disciplina pede uma construção **incremental**: cada TP
(Teste de Performance) adiciona uma camada nova sobre o TP anterior, sem
apagar nada do que já existia. A Entrega Final não cria nada novo — ela
apenas revisa, corrige e consolida tudo que foi validado no TP5.

| Etapa | O que entra de novo |
|---|---|
| **TP1** | Lógica combinacional básica: decodificador de estado → LEDs |
| **TP2** | Leitura de sensores reais: debounce, detecção de borda (sensor de veículo e botão de pedestre) |
| **TP3** | A máquina de estados (FSM) do semáforo + protocolo de comunicação paralelo ARM↔FPGA |
| **TP4** | Memória (histórico de veículos em BRAM) + aritmética (filtro de média móvel em DSP) |
| **TP5** | Protocolo de comunicação **serial** definitivo (substitui o paralelo) + Assembly organizado em biblioteca estática |
| **Entrega Final** | Consolidação: revisão de documentação, checklist final de rubricas, sem código novo |

Cada pasta (`TP1/` … `final_project/`) é **autocontida**: tem todo o
código acumulado até aquele ponto, não só a parte nova. Por isso o número
de arquivos cresce a cada etapa (TP1 tem 11 arquivos, TP5 tem 49,
`final_project` tem 65 — os dois últimos já contando as extensões pós-TP5:
tempo de verde dinâmico, telemetria de countdown e o log em tempo real
`monitor_semaforo.s`).

## 3. Como a FPGA funciona por dentro (Verilog)

Módulos em `rtl/`, cada um com seu testbench correspondente em `tb/`
(11 pares no total, todos com 100% dos casos de teste passando):

- **`estado_basico_decoder.v`** — combinacional puro: recebe um código de
  2 bits e acende o LED correspondente. É a base de tudo (TP1).
- **`debounce.v`** — filtro parametrizado que só aceita uma mudança de
  sinal depois que ela se mantém estável por N ciclos de clock, evitando
  falsos disparos por ruído elétrico (bouncing).
- **`sensor_veiculo.v`** / **`botao_pedestre.v`** — usam o debounce +
  detecção de borda de subida para transformar o sinal bruto do sensor/
  botão em um pulso de 1 ciclo ("veículo detectado" / "pedestre pediu
  travessia").
- **`contador_tempo.v`** — contador regressivo parametrizável, usado para
  cronometrar cada fase do semáforo (verde, amarelo, etc.).
- **`fsm_semaforo.v`** — o coração do projeto: uma máquina de estados de
  Moore com 3 estados (CARRO_VERDE → CARRO_AMARELO → PEDESTRE_VERDE →
  volta para CARRO_VERDE). Ela usa o `contador_tempo` internamente e
  garante que o pedestre só recebe o verde depois que o tempo mínimo de
  segurança dos veículos já passou.
- **`protocolo_paralelo.v`** (TP3) — versão inicial da comunicação
  ARM→FPGA: um barramento de 8 bits (opcode + valor) com sinais de
  strobe/ack.
- **`bram_historico.v`** (TP4) — um buffer circular de 256 posições
  implementado como memória síncrona, guardando o histórico das últimas
  passagens de veículos.
- **`media_movel_dsp.v`** (TP4) — calcula a média móvel das últimas 5
  amostras de fluxo de veículos usando aritmética de ponto fixo (Q16),
  de forma que a multiplicação seja sintetizada como um bloco DSP
  dedicado do chip, em vez de lógica genérica.
- **`protocolo_serial.v`** (TP5) — substitui o barramento paralelo por um
  protocolo serial estilo SPI, com 5 fios (`sclk`, `cs_n`, `mosi`,
  `miso`, `busy`), handshaking completo e telemetria de retorno.
- **`top_semaforo.v`** — o módulo de topo que integra todos os anteriores
  em um único sistema, com valores padrão de segurança aplicados
  automaticamente no reset.

## 4. Como o Raspberry Pi funciona por dentro (Assembly ARM64)

Os programas em `asm/` evoluem de scripts avulsos (TP1-TP4) para uma
**biblioteca estática reutilizável** no TP5/final:

- **`asm/lib/gpio_lib.s`** — mapeia e manipula os registradores GPIO
  físicos (todos os sinais do projeto passam por aqui).
- **`asm/lib/strings_lib.s`** — conversão de número inteiro para texto
  decimal (para imprimir resultados) e utilitário de tamanho de string.
- **`asm/lib/buffer_lib.s`** — um FIFO circular (fila) usado para simular
  o canal de telemetria vindo da FPGA.

Essas três bibliotecas são compiladas e empacotadas em `libembarcado.a`
(um arquivo `.a`, como uma "biblioteca .lib/.so" do mundo ARM). O programa
final, **`main_tp5.s`**, usa essa biblioteca para simular 2000 transações
de comunicação com a FPGA e medir throughput e latência reais usando o
relógio do sistema (`clock_gettime`). Também há um programa de teste
dedicado (`test_lib.s`) que verifica a própria biblioteca antes de ela
ser usada, e programas que exploram recursos avançados do ARM (operações
vetoriais NEON/SIMD, aritmética de 128 bits) mantidos como registro do
aprendizado incremental.

Extensão pós-TP5: **`asm/monitor_semaforo.s`** — o programa que gera o
log em tempo real do countdown dos sinais (ver seção 6). Também usa
`libembarcado.a`, e é o motivo pelo qual um bug real foi encontrado e
corrigido em `strings_lib.s` (ver seção 7, item 5).

## 5. Como as duas plataformas se comunicam

Esse é o ponto de integração entre RTL e Assembly, e evolui em duas
versões:

- **TP3/TP4 — Protocolo paralelo**: um byte de comando de uma vez
  (opcode nos 2 bits mais altos, valor nos 6 mais baixos), com sinais
  `strobe` (ARM avisa "tenho um comando pronto") e `ack` (FPGA confirma
  "recebi").
- **TP5/Final — Protocolo serial (definitivo)**: 5 fios só, todos em
  3,3V (não precisa de conversor de nível entre as duas placas):
  - `sclk` — clock da transferência, gerado pelo ARM
  - `cs_n` — chip-select / início-fim de quadro (nível baixo = ativo)
  - `mosi` — dados de comando, ARM → FPGA
  - `miso` — dados de telemetria, FPGA → ARM (fica em alta impedância
    quando `cs_n` está em nível alto)
  - `busy` — a FPGA pulsa esse sinal por 1 ciclo ao terminar de processar
    cada quadro, confirmando ao ARM que o comando foi aplicado

Essa mudança de paralelo para serial reduz o número de fios físicos de
10 para 5 e é o motivo de a montagem de hardware do TP5/Final ser mais
simples que a do TP3/TP4 nesse ponto específico.

**Formato do byte de telemetria em `miso` (atualizado na extensão pós-TP5
do countdown, ver seção 6)**: `[7:6] = fase atual do semáforo de carros`
(00=vermelho/pedestre-verde, 01=amarelo, 10=verde) e `[5:0] = contagem
regressiva` (ciclos/segundos restantes na fase corrente). Antes dessa
extensão, esse mesmo byte carregava `nivel_fluxo` + um ponteiro da BRAM
de histórico — esses dois valores continuam existindo e sendo testados
internamente (é o que decide o tempo de verde dinâmico, seção 6), só não
são mais duplicados na telemetria, porque o countdown real é uma
informação mais útil para quem está do lado do ARM/Raspberry Pi.

## 6. Como funciona o cálculo de tempo do semáforo (sem trânsito e com trânsito)

O cálculo de tempo mora inteiro dentro de `fsm_semaforo.v`, que usa um
contador regressivo (`contador_tempo.v`): esse contador é carregado com
um valor e decrementa 1 por ciclo de clock até chegar a zero, e é esse
"chegar a zero" (`tempo_esgotado`) que dispara cada troca de fase. O
relógio de referência é o oscilador interno da própria Tang Nano 4K, de
27 MHz.

**Sem solicitação de pedestre**: o semáforo fica parado na fase
CARRO_VERDE indefinidamente. A transição para amarelo só acontece quando
**duas** condições são verdadeiras ao mesmo tempo — o tempo mínimo de
verde já esgotou *e* existe uma solicitação de pedestre pendente. Se não
há solicitação, mesmo com o contador zerado o sistema simplesmente
continua em verde. Essa é a regra de segurança (ONF-08) que a rubrica
exige: o fluxo de veículos nunca é interrompido à toa.

**Com solicitação de pedestre**: no momento em que o botão é pressionado,
e assim que o tempo mínimo de verde já tiver decorrido, a FSM avança pela
sequência CARRO_VERDE → CARRO_AMARELO → PEDESTRE_VERDE → volta pra
CARRO_VERDE, e cada uma dessas três fases tem sua própria duração
carregada no contador: o valor de verde vem do registrador
`tempo_min_reg`, o de amarelo vem de `tempo_amarelo_reg`, e o do
pedestre é fixo em 15 ciclos no código atual. Os valores padrão de
fábrica (aplicados automaticamente no reset, antes de qualquer comando
chegar do ARM) são: verde = 10 ciclos, amarelo = 3 ciclos, pedestre = 15
ciclos.

Já o trânsito de **veículos** (fluxo, não pedestre) é medido separadamente
por `bram_historico.v` + `media_movel_dsp.v`. A cada janela de tempo
(`JANELA_AMOSTRAGEM` ciclos), conta-se quantos veículos o sensor detectou
naquela janela; essa contagem entra numa janela deslizante das últimas 5
amostras, o módulo calcula a média (por multiplicação em ponto fixo, não
divisão, pra caber num bloco DSP) e compara o resultado com dois
limiares configuráveis (`limiar_baixo`=3 e `limiar_alto`=8, por padrão)
pra classificar o fluxo em baixo, médio ou alto.

### Como a FPGA sabe se o trânsito está pesado (passo a passo)

A validação passa por uma cadeia de 4 estágios, cada um implementado num
módulo Verilog diferente, e é puramente sobre **frequência de
detecções**, não velocidade ou distância — o sensor IR só diz "tem
alguma coisa passando agora" (nível alto quando o par emissor/receptor
infravermelho detecta um obstáculo refletindo o feixe), cabe ao resto da
cadeia transformar isso numa taxa:

1. **Filtragem do sinal bruto (`debounce.v`)**: o sensor IR entrega um
   sinal elétrico bruto (`sensor_raw`, já em 3,3V, sem conversor de nível)
   que pode ter ruído — uma variação rápida e espúria de tensão que não é
   um veículo de verdade. O debounce só aceita uma mudança de estado
   depois que ela se mantém estável por 8 ciclos de clock seguidos;
   qualquer "tremulação" mais curta que isso é ignorada.
2. **Detecção de evento (`sensor_veiculo.v`)**: a partir do sinal já
   filtrado, esse módulo detecta a borda de subida (o momento exato em
   que o sinal vai de "nada" pra "objeto detectado") e gera um pulso de
   exatamente 1 ciclo de clock — `veiculo_pulso`. Isso transforma "o
   sensor está vendo algo" em um evento discreto e contável: "passou 1
   veículo agora".
3. **Contagem por janela de tempo (dentro de `top_semaforo.v`, bloco
   adicionado nesta extensão)**: aqui é onde a taxa de trânsito é de
   fato medida. Existe um contador de ciclos que define uma "janela de
   amostragem" (`JANELA_AMOSTRAGEM`, 200 ciclos por padrão); durante
   essa janela, cada `veiculo_pulso` que aparece incrementa um contador
   interno. Quando a janela fecha, esse total (quantos veículos passaram
   naqueles 200 ciclos) vira uma "amostra" entregue ao próximo estágio, e
   o contador zera para começar a próxima janela. É essa contagem por
   janela — não um pulso isolado — que representa a intensidade do
   trânsito.
4. **Média móvel e classificação (`media_movel_dsp.v`)**: as últimas 5
   amostras (5 janelas) ficam guardadas numa fila; a cada nova amostra, o
   módulo soma as 5 e calcula a média (por multiplicação em ponto fixo,
   pra caber num bloco DSP em vez de fazer uma divisão cara). Essa média
   entra numa comparação simples de dois limiares configuráveis: menor
   ou igual a `limiar_baixo` (padrão 3) → baixo; entre `limiar_baixo` e
   `limiar_alto` (padrão 8) → médio; acima de `limiar_alto` → alto. O
   resultado (`nivel_fluxo`, um número de 2 bits) alimenta tanto a
   telemetria enviada pro ARM quanto o cálculo do tempo de verde
   dinâmico.

Ou seja, a "certeza" de que o trânsito está pesado não vem de um único
veículo passando rápido — vem de vários veículos serem detectados
repetidamente ao longo de várias janelas consecutivas. É por isso que,
no teste de validação, foi preciso gerar um burst real de 50 veículos ao
longo de ~5 janelas pra realmente empurrar a média pra cima do limiar de
"alto"; um ou dois veículos isolados não bastam, propositalmente, pra
evitar que um pico passageiro engane o sistema.

**Atualização: isso agora realmente muda o tempo de verde**, numa
extensão feita depois da entrega do TP5. Antes, o nível de fluxo era só
calculado e enviado por telemetria pro Raspberry Pi (`miso`), sem afetar
nenhum tempo — era o ARM quem teria que decidir mudar o tempo, e essa
decisão nunca foi implementada. Agora `top_semaforo.v` ajusta o tempo
mínimo de verde **sozinho, dentro da própria FPGA**, direto a partir do
`nivel_fluxo` medido:

| Nível de fluxo | Tempo de verde efetivo | Com o padrão (10 ciclos) |
|---|---|---|
| Baixo (sem trânsito ou trânsito leve) | metade do valor de referência, com piso de 3 ciclos | 5 ciclos |
| Médio | igual ao valor de referência | 10 ciclos |
| Alto | dobro do valor de referência, com teto de 63 ciclos | 20 ciclos |

Ou seja: sem trânsito (ou com trânsito leve), o pedestre é liberado mais
rápido; com trânsito pesado, os veículos escoam por mais tempo antes do
pedestre poder atravessar — exatamente o comportamento que faz sentido
num cruzamento real. Isso foi validado com um teste que gera um burst
real de 50 veículos (não um valor artificialmente forçado) até
`nivel_fluxo` virar "alto" de verdade, e então compara o tempo até a
liberação do pedestre nos dois cenários (`tb_top_semaforo.v`, casos 4 e
5 — trânsito baixo mede 11 ciclos até a liberação, trânsito alto mede 14,
confirmando que o alto realmente demora mais).

Um detalhe interessante descoberto ao validar isso: o contador só é
recarregado com um novo tempo no instante em que a FSM *entra* numa fase
nova, não a cada ciclo enquanto já está nela. Isso significa que o nível
de fluxo que importa é o medido no momento em que o semáforo entra em
verde — se o trânsito mudar no meio da fase, isso só afeta a duração da
*próxima* vez que o semáforo abrir para os carros, não a fase em
andamento. É um comportamento razoável (evita que o contador fique
instável reiniciando o tempo todo), mas exige um pouco de cuidado ao
testar (e ao explicar): não adianta gerar trânsito pesado e apertar o
botão na mesma fase de verde que já começou antes — o efeito só aparece
na fase seguinte.

Também foi corrigido, junto com essa extensão, um problema real herdado
do TP4/TP5: a amostra enviada ao filtro de média móvel estava fixa em 1
por veículo detectado — com uma janela de 5 amostras de no máximo 1, a
média nunca conseguia passar de ~1, então `nivel_fluxo` na prática jamais
saía de "baixo" na integração completa, não importava quantos veículos
passassem. A correção foi trocar essa amostra fixa pela contagem real de
veículos detectados dentro de cada janela de tempo, refletindo uma taxa
de trânsito de verdade em vez de um pulso constante.

Um detalhe técnico que vale registrar: como o contador decrementa direto
no clock de 27 MHz sem nenhum divisor de frequência no meio, os valores
usados (5/10/20 para o verde dinâmico, 3 para o amarelo, 15 para o
pedestre, tudo em ciclos) representam durações de fase só para fins de
simulação rápida — em nanosegundos reais, isso seria quase instantâneo.
Para uma implementação física real, com durações de verde/amarelo em
segundos, seria necessário inserir um estágio de prescaler entre o `clk`
e o `contador_tempo` para transformar "N ciclos de 27 MHz" em "N segundos
reais", e isso ainda não está no RTL atual.

### Log em tempo real do countdown na Raspberry Pi (extensão pós-TP5)

Além do tempo de verde ser dinâmico (acima), a Raspberry Pi agora também
mostra, em tempo real, quanto falta para cada sinal fechar — pra tornar
visível na prática o que a FPGA está decidindo internamente. O programa
**`asm/monitor_semaforo.s`** faz isso:

1. A cada "tick" (1 segundo real, via `nanosleep`), monta um byte no
   mesmo formato que `protocolo_serial.v` transmite por `miso` (seção 5):
   `[7:6]=fase` `[5:0]=contagem regressiva`.
2. "Transmite" esse byte através do buffer circular de `buffer_lib.s`
   (`cbuf_push`/`cbuf_pop`) — simula o link serial sclk/mosi/miso do
   mesmo jeito que `main_tp5.s` já fazia para medir desempenho, já que
   não há uma Tang Nano física conectada neste ambiente de
   desenvolvimento.
3. Decodifica o byte de volta (fase + contagem), exatamente como o
   software real faria ao receber `miso`, e imprime uma linha como:
   `[t=42s] Sinal dos CARROS: VERDE -> fecha em 1s`.
4. Dorme 1 segundo real antes do próximo tick — por isso é "tempo real"
   e não uma simulação instantânea. No fim, o tempo total decorrido é
   medido de verdade com `clock_gettime` e comparado com o esperado
   (mesma metodologia de verificação usada em `main_tp5.s`).

O programa demonstra os dois cenários já validados em `tb_top_semaforo.v`
de forma visível: primeiro um ciclo completo com trânsito BAIXO (verde
fecha em 5s, depois amarelo em 3s, depois o pedestre abre e fecha em
15s), depois um ciclo com trânsito ALTO (verde agora leva 20s pra
fechar). Ressalva importante, na mesma linha do parágrafo anterior: como
o RTL ainda não tem o prescaler que transformaria ciclos de 27 MHz em
segundos reais, esses valores (5/20/3/15) são tratados como segundos só
do lado do log em ARM, para produzir uma demonstração legível — no
Verilog simulado eles continuam sendo ciclos de clock. Log real da
execução: `docs/evidencias/*_monitor_semaforo_run.txt`.

**E a Raspberry Pi participa da decisão?** Não, e é proposital: a decisão
de quanto tempo o sinal fica aberto é tomada inteiramente dentro da FPGA
(tabela acima) — a Raspberry Pi só **lê** o resultado (fase + contagem)
pela telemetria e o exibe. Isso preserva a mesma divisão de
responsabilidades do projeto inteiro: a FPGA garante a segurança e o
tempo real (nunca depende do ARM para isso), e o ARM cuida de
configuração/visualização, nunca de temporização crítica. Se a Raspberry
Pi travar, atrasar ou for desligada, o semáforo continua funcionando
exatamente igual — só o log deixa de aparecer.

## 7. Bugs reais encontrados e corrigidos (não é só "funcionou de primeira")

Documentados nos relatórios porque mostram domínio técnico real do
sistema:

1. **TP3 — duração errada de fase na FSM**: ao trocar de estado, o
   contador era recarregado com a duração do estado *atual* em vez do
   estado *de destino*, fazendo cada fase durar um ciclo a menos que o
   configurado. Corrigido calculando o valor do contador a partir do
   *próximo* estado, com uma flag extra garantindo a primeira carga
   correta depois do reset.
2. **TP4 — atraso de 1 ciclo e arredondamento errado no filtro de média
   móvel**: o cálculo usava o valor antigo do acumulador (resolvido com
   um sinal combinacional auxiliar) e truncava sempre para baixo em vez
   de arredondar (resolvido somando meio bit de correção antes do
   deslocamento final).
3. **TP5 — falso negativo de metodologia de teste**: o testbench de
   integração esperava 200 ciclos antes de checar o LED de pedestre, mas
   com os tempos de teste usados a fase inteira de pedestre durava só
   ~16 ciclos — ou seja, o sistema já tinha completado o ciclo todo e
   voltado sozinho para carro verde (comportamento correto!) quando o
   teste finalmente checava. Não era bug de hardware, era o teste que
   estava mal calibrado. Corrigido ajustando o tempo de espera do
   próprio testbench.
4. **Pós-TP5 — amostra de tráfego fixa mascarava o nível de fluxo real**:
   ao implementar o tempo de verde dinâmico, ficou evidente que a
   integração enviava sempre "1" como amostra para o filtro de média
   móvel a cada veículo, herdado do TP4. Com uma janela de 5 amostras de
   no máximo 1, a média nunca ultrapassava ~1, então `nivel_fluxo` jamais
   saía de "baixo" na prática, não importava quanto trânsito houvesse —
   um bug silencioso que não tinha sido percebido porque, até então,
   nada dependia de fato do valor de `nivel_fluxo`. Corrigido substituindo
   a amostra fixa pela contagem real de veículos detectados dentro de
   cada janela de tempo.
5. **Pós-TP5 — `uint_to_dec` corrompia o próprio endereço de retorno para
   números grandes**: ao imprimir o tempo real total decorrido no log de
   countdown (um número de 11 dígitos, ~61 bilhões de nanossegundos), o
   programa simplesmente saía do trilho depois de imprimir a primeira
   linha. Investigando: `uint_to_dec` (em `strings_lib.s`) tinha dois
   problemas nunca antes expostos porque nenhuma chamada anterior
   imprimia um número tão grande. Primeiro, ela truncava o valor de
   entrada para 32 bits (usava `w0`/`w2` em vez de `x0`/`x2`) — qualquer
   valor acima de ~4,29 bilhões já vinha errado. Segundo, e mais grave: a
   pilha local de dígitos era escrita a partir de `[sp+0]`, exatamente o
   mesmo endereço onde a função tinha acabado de salvar seu próprio
   `x30` (endereço de retorno) em `[sp+8..+15]` — qualquer número com 9
   dígitos ou mais sobrescrevia esses bytes, e o `ret` no final da função
   saltava para um endereço de lixo (por coincidência, um endereço válido
   o suficiente pra continuar executando código, só que a partir do meio
   de `roda_fase` com registradores igualmente corrompidos, o que
   explicava o log continuar imprimindo linhas sem sentido em vez de
   travar direto). Corrigido usando registradores de 64 bits inteiros na
   função e deslocando a pilha de dígitos para `[sp+16]`, bem longe da
   área onde `x29`/`x30` ficam salvos. Como `strings_lib.s` é parte de
   `libembarcado.a`, usada também por `main_tp5.s`, o teste de regressão
   completo (`test_lib`, `main_tp5`, `monitor_semaforo`) foi refeito após
   a correção para confirmar que nada quebrou.

## 8. Verificação real

Todo o código foi de fato compilado/simulado e executado neste ambiente,
não apenas escrito:

- **Verilog**: simulado com **Icarus Verilog** (`iverilog`/`vvp`), com
  formas de onda (`.vcd`) geradas e analisáveis em **GTKWave**.
- **Assembly ARM64**: montado, linkado e executado diretamente na
  Raspberry Pi (toolchain nativo `as`/`ld`/`objdump`/`ar`/`gdb`, sem
  necessidade de emulador — o binário compilado para AArch64 já é o
  binário que roda na placa).
- Todos os logs dessas execuções estão salvos em
  `docs/evidencias/` dentro de cada pasta, e crescem a cada etapa (9
  arquivos no TP5, 25 no `final_project`, porque acumula tudo — incluindo
  a evidência real do teste de tempo de verde dinâmico e da telemetria de
  countdown, e o log real de execução do `monitor_semaforo.s`, todos
  adicionados depois do TP5).

## 9. Estrutura de cada pasta de entrega

```
TPn/ (ou final_project/)
├── rtl/                    -> módulos Verilog (acumulados até esta etapa)
├── tb/                     -> testbenches correspondentes
├── asm/                    -> programas Assembly ARM64 (e lib/ a partir do TP5)
├── constraints/            -> arquivo .cst com o mapeamento de pinos da Tang Nano 4K
├── docs/evidencias/        -> logs reais de simulação/execução + waveforms .vcd
├── Makefile                -> automatiza simulação, compilação e execução
├── README.md               -> objetivo da etapa + como rodar tudo
├── Checklist_Rubricas.md   -> cada critério da rubrica ligado ao arquivo/seção que o atende
```

## 10. Como rodar o projeto

Dentro de qualquer pasta `TPn/` ou `final_project/`:

```bash
make sim        # roda todos os testbenches Verilog (Icarus Verilog)
make lib        # monta a biblioteca libembarcado.a (a partir do TP5)
make asm        # monta os programas Assembly
make run-asm    # executa os binários nativamente na Raspberry Pi
```

Para gravar de fato na FPGA física, o fluxo é: abrir o **Gowin EDA**,
criar um projeto para o device `GW1NSR-LV4C QFN48P`, adicionar todos os
arquivos de `rtl/` (o Gowin resolve a hierarquia sozinho a partir de
`top_semaforo.v`), adicionar o `constraints/tangnano4k.cst`, e rodar
Synthesize → Place & Route → Program Device.

## 11. Onde acompanhar/validar cada critério de nota

O arquivo `Checklist_Rubricas.md` de cada pasta é o mapa direto entre
"o que o professor vai avaliar" e "onde isso está implementado" — vale a
pena abrir ele primeiro ao revisar qualquer etapa, porque cada item da
rubrica está com o caminho exato do arquivo (ou seção do relatório) que o
comprova.
