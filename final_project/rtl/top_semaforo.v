// top_semaforo: modulo de topo do Semaforo Inteligente com Botao de
// Pedestre, integrando todos os blocos desenvolvidos do TP1 ao TP5.
// Trata os casos de borda finais: reset assíncrono global, estado
// invalido da FSM (tratado internamente por fsm_semaforo/estado_basico_decoder)
// e a configuracao de OE do pino MISO (tratada dentro de protocolo_serial).
// O tempo de verde dos veiculos e' ajustado dinamicamente pelo
// proprio nivel_fluxo medido internamente (BRAM+DSP), sem depender de
// nenhum comando vindo do ARM -- trafego baixo libera o pedestre mais
// rapido, trafego alto atrasa a liberacao (ver bloco "tempo de verde
// dinamico" abaixo).
// A telemetria enviada por miso agora carrega a fase da FSM
// e a contagem regressiva real da fase corrente (em vez de nivel_fluxo +
// ponteiro da BRAM), permitindo que a Raspberry Pi monte um log em tempo
// real com o countdown de quanto falta pro sinal dos carros/pedestre
// fechar (ver instanciacao de protocolo_serial abaixo).
module top_semaforo #(
    // ciclos de "clk" por janela de amostragem de trafego (ver bloco
    // "amostrador de taxa de trafego" abaixo). Parametrizado para permitir
    // que testbenches usem uma janela menor e simulem mais rapido; o valor
    // real para hardware fisico depende de um prescaler externo ao clock
    // de 27 MHz (mesma ressalva dos tempos da FSM).
    // agora contada em TICKS (ver prescaler abaixo), nao em ciclos de clock
    // puro -- com DIVISOR_TICK=27_000_000 (padrao/hardware real), cada
    // unidade de JANELA_AMOSTRAGEM vale 1 segundo real. Testbenches usam
    // DIVISOR_TICK=1 (tick a cada ciclo), preservando a contagem em
    // "ciclos" que ja validavam antes desta correcao.
    parameter integer JANELA_AMOSTRAGEM = 3,

    // divisor do prescaler que converte "ciclos de clock" (o que
    // tempo_min/tempo_amarelo/tempo_pedestre contam) em unidades de tempo
    // perceptiveis por humanos. Padrao = 27_000_000 -> 1 tick por segundo
    // real na Tang Nano 4K (27 MHz), fazendo tempo_min_reg=10 durar 10s de
    // verdade em vez de ~370 ns. Testbenches usam DIVISOR_TICK=1 (tick a
    // cada ciclo) para manter a simulacao rapida -- ver rtl/prescaler.v.
    parameter integer DIVISOR_TICK = 27_000_000
) (
    input  wire clk,          // 27 MHz (oscilador onboard da Tang Nano 4K)
    input  wire rst_n,        // reset assincrono, ativo em nivel baixo -- SEM
                              // botao onboard dedicado nessa placa (S1/S2 sao
                              // botoes de uso geral, ver constraints/tangnano4k.cst);
                              // fica em repouso via pull-up interno, sem fio
                              // externo nenhum, a menos que se monte um botao
                              // manual (ver README/CONTEXTO_PROJETO)

    // sensores e atuadores fisicos
    input  wire sensor_raw,
    input  wire botao_raw,
    output wire led_vermelho,
    output wire led_amarelo,
    output wire led_verde,
    output wire led_ped_verde,
    output wire led_ped_vermelho,

    // interface serial final ARM <-> FPGA (substitui o barramento paralelo)
    input  wire sclk,
    input  wire cs_n,
    input  wire mosi,
    output wire miso,
    output wire busy
);
    
    wire sensor_estavel, veiculo_pulso;
    wire botao_estavel, solicitacao_pedestre;
    wire limpa_solicitacao;

    // sensor_raw e' ATIVO EM NIVEL BAIXO na pratica: o modulo sensor IR
    // usado (tipo FC-51) mantem OUT em alto quando nao ha obstaculo e desce
    // pra baixo ao detectar -- confirmado testando no hardware real (o
    // oposto do que sensor_veiculo.v assume: repouso baixo, deteccao alta,
    // borda de SUBIDA = evento). A inversao aqui adapta a polaridade fisica
    // do sensor pra logica interna, sem mexer em sensor_veiculo.v.
    sensor_veiculo #(.N_CYCLES(8)) u_sensor (
        .clk(clk), .rst_n(rst_n), .sensor_raw(~sensor_raw),
        .sensor_estavel(sensor_estavel), .veiculo_pulso(veiculo_pulso)
    );

    // botao_raw vem do botao onboard S1 (pino 14, rede KEY1), ativo em
    // nivel BAIXO (pull-up fisico ja soldado na placa, ver .cst) -- o
    // oposto da convencao usada por botao_pedestre.v (repouso baixo,
    // pressionado alto). A inversao aqui adapta a polaridade fisica do
    // botao onboard para a logica interna, sem mexer em botao_pedestre.v.
    botao_pedestre #(.N_CYCLES(8)) u_botao (
        .clk(clk), .rst_n(rst_n), .botao_raw(~botao_raw),
        .limpa_solicitacao(limpa_solicitacao),
        .botao_estavel(botao_estavel), .solicitacao_pedestre(solicitacao_pedestre)
    );

    // ---- comunicacao final ARM->FPGA  ----
    wire [7:0] comando_recebido;
    wire       comando_valido;
    reg  [5:0] tempo_min_reg, tempo_amarelo_reg, limiar_baixo_reg, limiar_alto_reg;

    localparam OP_TEMPO_MIN     = 2'b00;
    localparam OP_TEMPO_AMARELO = 2'b01;
    localparam OP_LIMIAR_BAIXO  = 2'b10;
    localparam OP_LIMIAR_ALTO   = 2'b11;

    // ---- BRAM/DSP : historico e nivel de fluxo ----
    wire [7:0] contagem_dummy_leitura;
    reg  [7:0] ponteiro_escrita_reg;
    wire [7:0] ponteiro_escrita_w;
    wire [7:0] media_fluxo;
    wire [1:0] nivel_fluxo;

    bram_historico u_bram (
        .clk(clk), .rst_n(rst_n),
        .escreve(veiculo_pulso), .dado_escrita(8'd1), // incrementa 1 "evento" por veiculo (simplificado)
        .endereco_leitura(8'd0), .dado_leitura(contagem_dummy_leitura),
        .ponteiro_escrita(ponteiro_escrita_w)
    );

    // ---- prescaler: converte ciclos de clock em ticks de tempo real ----
    // (movido pra antes do amostrador de trafego, que agora tambem usa
    // tick_fsm para fechar a janela em unidades de tempo real, nao em
    // ciclos de clock puro -- ver correcao abaixo)
    wire tick_fsm;
    prescaler #(.DIVISOR(DIVISOR_TICK)) u_prescaler (
        .clk(clk), .rst_n(rst_n), .tick(tick_fsm)
    );

    // ---- amostrador de taxa de trafego (correcao pos-TP5) ----
    // No TP4/TP5, "amostra" ia fixa em 8'd1 por veiculo -- com uma janela de
    // 5 amostras de no maximo 1, a media nunca passava de ~1, entao
    // nivel_fluxo jamais saia de "baixo" na integracao real, por mais
    // veiculos que passassem. Aqui a amostra passa a ser a CONTAGEM de
    // veiculos detectados dentro de uma janela de JANELA_AMOSTRAGEM ciclos
    // de clock -- ou seja, uma taxa real de trafego, nao um pulso fixo.
    // Correcao (pos deteccao real em hardware): a janela fechava a cada
    // JANELA_AMOSTRAGEM ciclos de CLOCK PURO (200 ciclos a 27 MHz = ~7,4
    // microssegundos) -- impossivel sincronizar um veiculo/mao passando
    // na frente do sensor com uma janela tao curta; na pratica a media
    // sempre convergia pra "baixo", nao importava quanto trafego passasse.
    // Agora o fechamento da janela e' contado em TICKS (tick_fsm, mesmo
    // prescaler usado pelos tempos da FSM), entao com o padrao de hardware
    // (1 tick/segundo) cada janela dura JANELA_AMOSTRAGEM segundos reais.
    // A contagem de veiculos em si (contagem_janela) continua incrementando
    // a cada ciclo real que um veiculo_pulso aparece, independente do tick
    // -- so' a decisao de FECHAR a janela e' que agora espera o tick.
    reg [31:0] ciclos_janela;
    reg [7:0]  contagem_janela;
    reg [7:0]  amostra_fluxo;
    reg        nova_amostra_fluxo;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ciclos_janela      <= 32'd0;
            contagem_janela    <= 8'd0;
            amostra_fluxo      <= 8'd0;
            nova_amostra_fluxo <= 1'b0;
        end else begin
            nova_amostra_fluxo <= 1'b0;

            if (veiculo_pulso)
                contagem_janela <= contagem_janela + 8'd1;

            if (tick_fsm) begin
                if (ciclos_janela == JANELA_AMOSTRAGEM - 1) begin
                    amostra_fluxo      <= contagem_janela + (veiculo_pulso ? 8'd1 : 8'd0);
                    contagem_janela    <= 8'd0;
                    ciclos_janela      <= 32'd0;
                    nova_amostra_fluxo <= 1'b1;
                end else begin
                    ciclos_janela <= ciclos_janela + 32'd1;
                end
            end
        end
    end

    media_movel_dsp u_media (
        .clk(clk), .rst_n(rst_n),
        .nova_amostra(nova_amostra_fluxo), .amostra(amostra_fluxo),
        .limiar_baixo(limiar_baixo_reg), .limiar_alto(limiar_alto_reg),
        .media(media_fluxo), .nivel_fluxo(nivel_fluxo)
    );

    // ---- tempo de verde dinamico por nivel de fluxo  ----
    // tempo_min_reg (configuravel via protocolo serial) passa a representar
    // o tempo de verde de referencia para trafego MEDIO. Para BAIXO trafego
    // o tempo efetivo cai pela metade (pedestre e' liberado mais rapido);
    // para ALTO trafego ele dobra (pedestre espera mais, veiculos escoam
    // primeiro). Um piso e um teto absolutos evitam que o ajuste viole o
    // limite de seguranca minimo (ONF-08) ou estoure a largura do registrador
    // usado pelo protocolo serial (6 bits, max 63).
    localparam [7:0] TEMPO_MIN_PISO = 8'd3;
    localparam [7:0] TEMPO_MIN_TETO = 8'd63;

    wire [7:0] tempo_min_base_w   = {2'b00, tempo_min_reg};
    wire [7:0] tempo_min_metade_w = (tempo_min_base_w >> 1 < TEMPO_MIN_PISO)
                                     ? TEMPO_MIN_PISO : (tempo_min_base_w >> 1);
    wire [7:0] tempo_min_dobro_w  = (tempo_min_base_w <<< 1 > TEMPO_MIN_TETO)
                                     ? TEMPO_MIN_TETO : (tempo_min_base_w <<< 1);

    reg [7:0] tempo_min_efetivo;
    always @(*) begin
        case (nivel_fluxo)
            2'b00:   tempo_min_efetivo = tempo_min_metade_w; // trafego baixo  -> abre mais rapido pro pedestre
            2'b10:   tempo_min_efetivo = tempo_min_dobro_w;  // trafego alto   -> demora mais pra abrir
            default: tempo_min_efetivo = tempo_min_base_w;   // trafego medio  -> tempo de referencia
        endcase
    end

    // ---- FSM do semaforo ----
    wire [1:0] estado_carro;
    wire       verde_pedestre;
    wire [7:0] contagem_fase_atual; // ciclos restantes na fase corrente

    fsm_semaforo #(.LARGURA_TEMPO(8)) u_fsm (
        .clk(clk), .rst_n(rst_n), .tick(tick_fsm),
        .solicitacao_pedestre(solicitacao_pedestre),
        .tempo_min_verde(tempo_min_efetivo),
        .tempo_amarelo({2'b00, tempo_amarelo_reg}),
        .tempo_pedestre(8'd15),
        .estado_carro(estado_carro), .verde_pedestre(verde_pedestre),
        .limpa_solicitacao(limpa_solicitacao),
        .contagem_atual(contagem_fase_atual)
    );

    // ---- tempo ate o pedestre poder atravessar ----
    // Diferente de "contagem_fase_atual" (tempo restante SO' na fase
    // corrente, que reseta a cada troca de fase), isso calcula quanto
    // falta de verdade ate o sinal do pedestre abrir:
    //   CARRO_VERDE:    falta o resto do verde + o amarelo INTEIRO (essa
    //                   fase ainda nem comecou a contar)
    //   CARRO_AMARELO:  falta so' o resto do amarelo (pedestre abre logo
    //                   depois que o amarelo zerar)
    //   PEDESTRE_VERDE: 0 (ja esta aberto)
    reg [7:0] tempo_ate_pedestre;
    always @(*) begin
        case (estado_carro)
            2'b10:   tempo_ate_pedestre = contagem_fase_atual + {2'b00, tempo_amarelo_reg}; // CARRO_VERDE
            2'b01:   tempo_ate_pedestre = contagem_fase_atual;                              // CARRO_AMARELO
            default: tempo_ate_pedestre = 8'd0;                                             // PEDESTRE_VERDE
        endcase
    end

    // ---- decodificacao de LEDs ----
    estado_basico_decoder u_decoder_carro (
        .estado(estado_carro),
        .led_vermelho(led_vermelho), .led_amarelo(led_amarelo), .led_verde(led_verde)
    );
    assign led_ped_verde    = verde_pedestre;
    assign led_ped_vermelho = ~verde_pedestre;

    // ---- protocolo serial final ----
    // fase_telemetria: o campo "fase" so' usa 3 dos 4 valores possiveis
    // (00/01/10); aproveitamos o codigo livre (11) pra diferenciar, so'
    // dentro de CARRO_VERDE, se ja existe um pedido de pedestre pendente
    // (esperando o tempo minimo passar) ou nao -- sem gastar nenhum bit
    // a mais no byte de telemetria. Nas outras fases (amarelo/pedestre-
    // verde) um pedido SEMPRE esta pendente (e' o que fez a FSM sair do
    // verde), entao nao precisa de codigo especial ali.
    wire [1:0] fase_telemetria = (estado_carro == 2'b10 && solicitacao_pedestre)
                                  ? 2'b11 : estado_carro;

    // Telemetria (formato atualizado, pra incluir o nivel de trafego e o
    // pedido de pedestre pendente):
    //   [7:6] = fase_telemetria -- 00=pedestre verde/carro vermelho,
    //           01=carro amarelo, 10=carro verde SEM pedido pendente,
    //           11=carro verde COM pedido pendente
    //   [5:4] = nivel_fluxo (00=baixo 01=medio 10=alto)
    //   [3:0] = tempo_ate_pedestre, TRUNCADO para 4 bits (0-15) -- quanto
    //           falta de verdade pro pedestre poder atravessar (nao so' o
    //           tempo restante na fase atual, ver bloco acima)
    // Contrapartida aceita: em trafego alto (verde=20 + amarelo), o valor
    // pode passar de 15 e truncar -- e' so' uma limitacao de EXIBICAO no
    // monitor da Raspberry Pi, a FSM interna da FPGA conta certo por
    // dentro, sem nenhum truncamento -- e' so' o byte de telemetria que
    // satura essa faixa. Os LEDs (estado_basico_decoder) continuam usando
    // "estado_carro" puro, nao "fase_telemetria" -- essa distincao e' so'
    // pra informar a Raspberry Pi, nao afeta o semaforo fisico.
    protocolo_serial u_protocolo (
        .clk(clk), .rst_n(rst_n),
        .sclk(sclk), .cs_n(cs_n), .mosi(mosi),
        .fase_carro_atual(fase_telemetria),
        .contagem_regressiva({nivel_fluxo, tempo_ate_pedestre[3:0]}),
        .miso(miso), .busy(busy),
        .comando_recebido(comando_recebido), .comando_valido(comando_valido)
    );

    // decodifica comandos recebidos e atualiza os registradores de
    // configuracao (mesma logica de protocolo_paralelo.v, adaptada para a
    // interface serial) -- valores padrao de seguranca no reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tempo_min_reg     <= 6'd10;
            tempo_amarelo_reg <= 6'd3;
            // valores padrao (producao): limiar_baixo=3, limiar_alto=8 --
            // exige trafego sustentado (~8+ deteccoes/janela em media ao
            // longo das ultimas 5 janelas) pra virar "alto".
            // limiar_baixo_reg  <= 6'd3;
            // limiar_alto_reg   <= 6'd8;

            // TESTE: limiares bem mais sensiveis, so' pra facilitar
            // demonstrar na mao. Com media_movel_dsp.v fazendo media das
            // ultimas 5 janelas, isso significa: ~1 deteccao por janela
            // SUSTENTADA ao longo de todo o periodo de media (nao um
            // unico carro isolado) -> medio; ~2 ou mais por janela
            // sustentado -> alto.
            limiar_baixo_reg  <= 6'd0;
            limiar_alto_reg   <= 6'd1;
        end else if (comando_valido) begin
            case (comando_recebido[7:6])
                OP_TEMPO_MIN:     tempo_min_reg     <= comando_recebido[5:0];
                OP_TEMPO_AMARELO: tempo_amarelo_reg <= comando_recebido[5:0];
                OP_LIMIAR_BAIXO:  limiar_baixo_reg  <= comando_recebido[5:0];
                OP_LIMIAR_ALTO:   limiar_alto_reg   <= comando_recebido[5:0];
            endcase
        end
    end
endmodule
