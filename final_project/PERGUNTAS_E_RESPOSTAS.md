# Perguntas prováveis da banca e respostas

> Preparação para a arguição do projeto **Semáforo Inteligente ARM + FPGA**.
> As respostas são curtas para serem faladas, e cada uma cita o arquivo
> onde está a prova. A seção 8 reúne perguntas difíceis sobre limitações
> reais do projeto: é melhor conhecê-las antes que o professor as aponte.

---

## 1. Arquitetura e escolhas de projeto

**1. Por que usar FPGA e ARM juntos, e não só um dos dois?**
Porque os dois resolvem problemas diferentes. A FPGA dá **determinismo**:
a decisão de fase acontece a cada ciclo de clock (37 ns), sempre no mesmo
tempo, sem sistema operacional no meio. O ARM dá **flexibilidade**:
visualizar e registrar o estado é muito mais simples em software. Juntar os
dois deixa cada parte onde ela é melhor.

**2. Por que a lógica do semáforo fica na FPGA e não na Raspberry Pi?**
O Linux tem latência imprevisível: escalonador, interrupções, outros
processos. Um semáforo é um sistema de segurança, e a decisão "posso fechar
o verde?" não pode atrasar porque o SO resolveu fazer outra coisa. Na FPGA
a lógica está fisicamente cabeada e não compete com nada.

**3. O que acontece se a Raspberry Pi travar ou for desligada?**
Nada muda. Os tempos e limiares são parâmetros fixos de `top_semaforo.v`,
a FSM decide tudo internamente, e o link serial só **envia** telemetria. O
monitor passa a mostrar `QUADRO INVALIDO` ou para de imprimir, e só isso. Essa
é a regra **ONF-08**.

**4. O que é a ONF-08?**
É o requisito de segurança do projeto: (a) nunca interromper o trânsito sem
pedido de pedestre, (b) um estado inválido sempre força vermelho e (c) o
funcionamento nunca depende do ARM. Aparece em `fsm_semaforo.v` (só sai do
verde com pedido; pedestre verde só com carro vermelho), em
`estado_basico_decoder.v` (código `11` acende vermelho) e na própria
arquitetura.

**5. O ARM consegue mandar abrir o sinal para o pedestre, ou mudar os tempos?**
Não, e isso é proposital. O link é **só de leitura**: não existe `mosi` nem
registrador configurável. `sclk` e `cs_n` só dizem à FPGA quando enviar o
quadro. Nem um bug no software consegue mudar o semáforo.

**6. Por que o sensor e o botão estão ligados na FPGA e não no ARM?**
Porque quem decide é a FPGA. Se o botão passasse pelo ARM, a segurança
voltaria a depender do Linux, o que contradiz a arquitetura.

**7. Quais são as entradas e saídas do sistema?**
Entradas: `clk` (27 MHz), `rst_n` (botão S2), `botao_raw` (botão S1),
`sensor_raw` e, do ARM, `sclk` e `cs_n`. Saídas: 5 LEDs (3 do carro, 2 do
pedestre) e `miso` (telemetria).

---

## 2. Hardware (Verilog)

**8. Explique a máquina de estados.**
São três estados: `CARRO_VERDE` → `CARRO_AMARELO` → `PEDESTRE_VERDE` → de
volta ao verde. A saída do verde exige **duas** condições: tempo de verde
esgotado **e** pedido pendente. Quando chega um pedido novo, o contador é
recarregado com o tempo de verde (se faltava menos), então o pedestre espera
pelo menos esse tempo a partir do aperto. Amarelo e pedestre saem só pelo tempo. Ao
sair do verde do pedestre, a FSM pulsa `limpa_solicitacao` para zerar o
pedido.

**9. A FSM é Moore ou Mealy? Por quê?**
**Moore**: as saídas (LEDs) dependem só do estado atual. Isso evita
glitches nos LEDs quando uma entrada muda no meio do ciclo, e deixa as
saídas estáveis durante toda a fase.

**10. Como a FSM mede o tempo de cada fase?**
Com o submódulo `contador_tempo.v`, um contador decrescente. Na troca de
fase ele é carregado com a duração da **próxima** fase (`prox_estado`), e
não da atual, para não carregar o valor errado no ciclo de transição. Ele
só decrementa quando chega o `tick` do prescaler.

**11. Para que serve o prescaler?**
O clock é de 27 MHz. Sem divisor, uma fase de "10" duraria 10 ciclos,
cerca de 370 ns, invisível a olho nu. O `prescaler.v` gera um pulso a cada
27.000.000 ciclos, ou seja, **1 tick por segundo**, e a FSM conta ticks.
Nos testbenches o divisor é reduzido para simular rápido.

**12. Por que usar debounce?**
Botões mecânicos "repicam" (várias transições em poucos milissegundos) e
sensores têm ruído. Sem filtro, um aperto contaria como vários pedidos, e
um carro contaria como vários veículos. O `debounce.v` só aceita um novo
nível depois de N ciclos seguidos estáveis: 20 ms no botão (540 000 ciclos)
e 5 ms no sensor.

**13. Por que há dois flip-flops antes do debounce?**
É um **sincronizador**. Sensor e botão são sinais assíncronos ao clock; se
mudarem perto da borda, o flip-flop pode entrar em **metaestabilidade**.
Dois registradores em série dão um ciclo inteiro para o valor se resolver.
O mesmo vale para `sclk` e `cs_n` e para a saída do reset.

**14. Por que o pedido do pedestre fica "travado"?**
O pedestre aperta e solta o botão em menos de um segundo, mas o pedido
precisa valer até a FSM atendê-lo. O `botao_pedestre.v` tem um **latch** que
só zera quando a FSM entra na fase do pedestre.

**15. Como o tempo de verde se adapta ao trânsito?**
O sensor gera um pulso por veículo. O topo conta os pulsos numa janela de
10 s; essa contagem vira uma amostra e é gravada na BRAM. O filtro faz a
média das últimas 5 amostras (cerca de 50 s) e classifica o fluxo: baixo
(média ≤ 1 por janela, ou seja, 0 a 7 carros em 50 s), médio (8 a 17) ou alto
(18 ou mais). O tempo de verde é **5, 10 ou 20 s**.

**16. De onde vêm esses números?**
São parâmetros de `top_semaforo.v`, escolhidos para um cruzamento de
demonstração. O mínimo de 5 s garante que o verde nunca seja curto demais
para os carros, e 20 s mantém a espera do pedestre aceitável. O máximo
possível é 63 s (contador de 6 bits).

**17. Reset síncrono ou assíncrono? Por quê?**
Assíncrono na entrada e síncrono na saída: apertar S2 (`rst_n`) leva o
sistema na hora ao estado seguro, mesmo sem clock, e a liberação passa por
2 flip-flops para todos os registradores saírem do reset no mesmo ciclo.
O estado de reset é o seguro: carros no verde, pedestre no vermelho.

**18. O que é lógica combinacional e onde ela aparece?**
É a lógica cuja saída depende só das entradas do momento, sem memória.
O exemplo puro é o `estado_basico_decoder.v` (cor → LEDs). Também é
combinacional a escolha do tempo de verde no topo.

---

## 3. Recursos da FPGA (BRAM, DSP, PLL)

**19. O que é BRAM e por que usar?**
São blocos de memória prontos dentro da FPGA. Uma memória de 256 × 8 feita
com flip-flops gastaria 2048 registradores; em BRAM ela usa um bloco
dedicado. O `bram_historico.v` tem escrita e leitura **síncronas** com
portas separadas e memória sem reset, o padrão reconhecido como BRAM. Ela
guarda a contagem de cada janela, e o filtro lê dela a amostra que sai da
média. O place & route confirma: 1 BSRAM usada.

**20. Como funciona o buffer circular da BRAM?**
O ponteiro de escrita tem 8 bits. Ao passar de 255 ele volta a 0 sozinho
(overflow natural), então o buffer é circular sem nenhuma lógica extra.

**21. O que é o bloco DSP e por que usá-lo?**
É um multiplicador dedicado. Dividir por 5 em hardware é caro (divisor
sequencial ou muita lógica). Em vez disso, o `media_movel_dsp.v`
**multiplica pelo recíproco**: `soma × 13107 >> 16`, já que
13107 / 65536 ≈ 1/5. A multiplicação vai para o DSP (1 MULT18X18
no relatório de place & route).

**22. O que é ponto fixo Q16?**
É representar frações com inteiros: o número é guardado multiplicado por
2¹⁶. Então 1/5 vira 13107. Depois de multiplicar, desloca 16 bits para a
direita para voltar à escala normal.

**23. Essa aproximação dá erro?**
É desprezível. 13107/65536 = 0,199997. Somando meio LSB (32768) antes do
deslocamento, o resultado é arredondado, e não truncado. No pior caso
(soma 1275) o resultado é 255, exatamente 1275/5.

**24. Por que a soma é incremental?**
Em vez de somar as 5 amostras a cada vez, faz `soma − mais_antiga + nova`,
com a mais antiga lida da BRAM. É uma subtração e uma soma por amostra.
Depois do reset, enquanto a janela enche, nada é subtraído (a BRAM não é
zerada).

**25. Por que não usar PLL?**
O PLL gera clocks com outras frequências, mas nenhuma parte do projeto
precisa disso. A lógica mais exigente (debounce, detecção das bordas do
`sclk`) roda folgada a 27 MHz (o place & route chega a 198 MHz), e o
protocolo serial opera na ordem de 10 kHz. Para chegar a 1 s, um contador (prescaler) é mais
simples que um PLL, que nem gera frequências tão baixas. Um PLL só traria
complexidade e consumo.

**26. Qual é a "banda" necessária na comunicação?**
Mínima: um quadro de 16 bits por segundo. Mesmo a 10 kHz, um quadro
leva poucos milissegundos. A banda sobra em várias ordens de grandeza.

---

## 4. Protocolo de comunicação

**27. Como funciona o protocolo serial?**
É no estilo **SPI modo 0** (CPOL=0, CPHA=0): 16 bits, MSB primeiro, **só
de leitura**. O ARM é mestre e gera `sclk` e `cs_n`; a FPGA só responde em
`miso`.

**28. Como o quadro é delimitado?**
Pelo `cs_n`. Com `cs_n = 1`, a FPGA copia o quadro atual a cada ciclo e o
bit 15 já fica em `miso`. Quando `cs_n` desce, o quadro é **congelado**
(todos os campos do mesmo instante); a cada subida de `sclk` vem o próximo
bit. Quando `cs_n` sobe, o quadro acabou.

**29. Como o ARM sabe que o quadro é válido?**
Os 4 bits mais altos são sempre `1010`. Além disso, o ARM rejeita cor ou
fluxo `11` e pedestre verde com carro fora do vermelho. Fio solto ou GND
ausente fazem ler só zeros ou só uns, que são rejeitados.

**30. Por que trocar o protocolo paralelo do TP3 pelo serial?**
O paralelo usava 8 fios de dados + strobe + ack (10 pinos). O serial usa
3 fios + GND e segue um padrão conhecido.

**31. O que vai no quadro de telemetria?**
`[15:12]` marcador `1010`, `[11:10]` cor dos carros (`00` vermelho, `01`
amarelo, `10` verde), `[9]` pedestre verde, `[8]` pedido pendente, `[7:6]`
nível de fluxo e `[5:0]` segundos restantes da fase atual.

**32. O `sclk` vem de outro clock. Como a FPGA lida com isso?**
A FPGA não usa o `sclk` como clock. Ela o passa por **2 flip-flops de
sincronização**, amostrando com o clock de 27 MHz, e detecta a borda de
subida comparando com o valor anterior. O mesmo vale para `cs_n`. Tudo
continua num único domínio de clock.

**33. Por que tirar o `mosi` e o `busy`?**
Porque a Raspberry passou a ser só monitor: não há o que enviar para a
FPGA. O `busy` durava 37 ns e nunca foi usado pelo software.

**34. Por que fazer bit-bang em vez de usar o periférico SPI da Raspberry Pi?**
Por três motivos: (a) o projeto é em Assembly sem libc, e o SPI de hardware
exigiria o driver `spidev` e `ioctl` do kernel; (b) controlando cada pino
na mão, garantimos o timing exato que a FPGA espera (ler `miso` **antes** de
subir `sclk`), e o `miso` fica livre para qualquer GPIO; (c) é didático, porque mostra o protocolo de verdade. Como
só há 1 transferência por segundo, a velocidade do bit-bang não importa.

---

## 5. Software (Assembly ARM64)

**35. Por que Assembly e sem libc?**
É requisito da disciplina e mostra o controle total do processador:
registradores, convenção de chamada, syscalls. Sem libc, toda E/S é feita
direto com o kernel via `svc #0` (`write`, `openat`, `mmap`, `close`,
`clock_gettime`, `nanosleep`, `exit`).

**36. Como o programa acessa os GPIOs?**
Abre `/dev/gpiomem` e faz `mmap` dos registradores do BCM2710 para a
memória do processo. A partir daí, `LDR`/`STR` leem e escrevem direto no
hardware: `GPFSELn` configura entrada ou saída, `GPSET0` e `GPCLR0` põem o
pino em 1 ou 0 (escrevendo só a máscara do pino, sem ler antes), `GPLEV0`
lê o nível.

**37. O que acontece se `/dev/gpiomem` não abrir?**
O `gpio_map_init` devolve 0 e o monitor termina com uma mensagem de erro e
código 1. Não há modo simulado: o programa só mostra dados lidos da FPGA.

**38. O que é a AAPCS64 e por que importa?**
É a convenção de chamada do ARM64: parâmetros em `x0`–`x7`, retorno em
`x0`, e `x19`–`x28` preservados por quem é chamado. Seguir a convenção é o
que permite separar o código em bibliotecas (`gpio_lib`, `telemetria`,
`strings_lib`, `protocolo_serial_gpio`) e juntá-las em `libembarcado.a`.

**39. Como o monitor transforma o quadro em texto?**
`telemetria.s` extrai cada campo com `ubfx` e usa o valor como índice em
tabelas de ponteiros para texto (`tab_cor_carro[cor]`, `tab_fluxo[nivel]`).
Foi conferido nos 65 536 quadros possíveis contra uma referência em Python.

**40. Os programas dos TPs (NEON, benchmark, jump table) estão no projeto final?**
Não. Eles não fazem parte do sistema que roda na placa e continuam nas
pastas `../TP1` a `../TP5`.

---

## 6. Validação

**41. Como vocês garantiram que o hardware funciona?**
Com 10 testbenches **auto-verificáveis** no Icarus Verilog: cada caso
compara o resultado com o esperado e imprime `[OK]` ou `[FALHA]`. Todos
passam sem warnings, e a síntese com place & route também sai sem warnings.
Os logs estão em `docs/evidencias/`.

**42. O teste de integração testa o quê?**
O `tb_top_semaforo.v` só mexe nos pinos reais (botão, sensor, `sclk`/`cs_n`)
e observa LEDs e `miso`: estado inicial, espera de ~5 s com fluxo baixo
contra ~20 s com fluxo alto (gerado passando veículos no sensor), telemetria
em cada fase e, em todo ciclo, LEDs coerentes e nunca pedestre verde sem carro
vermelho.

**43. Por que usar veículos "reais" no teste?**
Porque o teste não força o valor de `nivel_fluxo`. Ele gera pulsos de
sensor de verdade e deixa o caminho completo (debounce, janela, BRAM, média,
classificação) produzir o resultado. Foi assim que apareceu o bug da média
que nunca saía de "baixo".

**44. Que bugs reais vocês encontraram?**
- A média nunca saía de "baixo": a amostra era fixa em 1 por veículo.
  Passou a ser a contagem de veículos por janela.
- `uint_to_dec` corrompia o endereço de retorno: escrevia os dígitos em
  cima do `x30` salvo na pilha e truncava em 32 bits.
- A placa não avançava: o `clk` estava no pino 27, e o oscilador real é o
  pino 45.
- As fases duravam ~370 ns: faltava o prescaler.
- A BRAM era removida na síntese (gravava sempre `1` e ninguém lia).
- Sensor e LEDs estavam no banco de 2,5 V (pinos do HDMI).

**45. Foi testado no hardware físico?**
O roteiro está na seção 7 do `GUIA_MONTAGEM_HARDWARE.md`. *(Ajuste esta
resposta ao que vocês realmente demonstraram na bancada.)*

---

## 7. Conceitos rápidos (respostas de uma frase)

| Pergunta | Resposta |
|---|---|
| O que é uma FPGA? | Um chip de lógica reconfigurável que vira o próprio circuito; tudo roda em paralelo. |
| Diferença entre FPGA e microcontrolador? | O microcontrolador executa instruções em sequência; a FPGA é o circuito, com lógica em paralelo e tempo fixo. |
| O que é RTL? | Descrever o hardware como registradores e a lógica entre eles. |
| O que é síntese? | Converter o Verilog em portas, flip-flops e blocos da FPGA. |
| O que é o `.cst`? | O arquivo que liga cada sinal do Verilog a um pino físico e define o padrão elétrico. |
| O que é LUT? | Pequena tabela que implementa qualquer função lógica de poucas entradas. |
| O que é metaestabilidade? | Um flip-flop num valor indefinido quando a entrada muda perto da borda do clock. |
| O que é telemetria? | O envio periódico do estado interno para monitoramento remoto. |
| Pull-up e pull-down? | Resistores que mantêm o pino em 1 ou 0 quando nada o comanda. |
| Por que só GND comum entre as placas? | Os sinais precisam da mesma referência de 0 V; cada placa tem sua própria alimentação. |
| Por que não precisa de conversor de nível? | As entradas da FPGA ficam no banco de 3,3 V; o `miso` sai a 2,5 V, que a Raspberry lê como 1. |
| Buffer circular? | Um vetor cujo índice volta ao início, sempre com os dados mais recentes (a BRAM). |

---

## 8. Perguntas difíceis: limitações reais e como responder

**46. O debounce é suficiente?**
Sim para o hardware usado: 20 ms no botão e 5 ms no sensor, acima do repique
mecânico típico (1–10 ms). A versão anterior usava 8 ciclos (~300 ns), o que
foi corrigido.

**47. A BRAM é realmente usada?**
Sim. Ela guarda a contagem de cada janela, e o filtro lê dela a amostra que
sai da média. O place & route mostra 1 BSRAM usada; na versão anterior ela
gravava sempre `1`, ninguém lia, e a síntese a removia.

**48. Vocês garantem que a multiplicação foi para o DSP?**
No fluxo aberto (Yosys/nextpnr), sim: 1 MULT18X18. No Gowin EDA, confira o
relatório de utilização; o atributo `syn_dspstyle = "dsp"` pede o bloco DSP.

**49. Se o trânsito mudar durante o verde, o tempo muda?**
Em parte. O tempo vale ao entrar no verde e é reaplicado quando chega um
pedido novo, com o fluxo daquele instante. Depois do pedido, a espera não é
mais recalculada, para o tempo restante não "pular".

**50. Por que o `miso` está num banco de 2,5 V?**
Os bancos de 3,3 V livres da Tang Nano 4K têm só 8 pinos, e o projeto usa 9
sinais de 3,3 V. As entradas vindas de fora precisam de 3,3 V; o `miso` é
saída, e 2,5 V é lido como nível alto pela Raspberry. Precisa ser confirmado
na bancada.

**51. Os limiares de fluxo são realistas?**
São para uma demonstração de bancada: com janela de 10 s, "alto" é uma média
de 4 ou mais veículos por janela. Num cruzamento real seriam calibrados com
contagens de campo, alterando os parâmetros de `top_semaforo.v`.

**52. O que vocês fariam diferente numa próxima versão?**
- Um bit de verificação (paridade/CRC) no quadro, além do marcador.
- Placa com mais pinos de 3,3 V livres, para não precisar do banco de 2,5 V.
- Calibrar os limiares com dados de tráfego reais.

---

## Dicas para a arguição

- Responda primeiro com a **ideia**, depois com o **arquivo** onde está a
  prova ("isso está em `fsm_semaforo.v`, na condição de saída do verde").
- Se não souber algo, diga como verificaria (relatório de síntese,
  testbench, forma de onda).
- A frase que amarra tudo: **"A FPGA decide e age; a Raspberry Pi só
  observa."**
