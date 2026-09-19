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
    parameter integer JANELA_AMOSTRAGEM = 200
) (
    input  wire clk,          // 27 MHz (oscilador onboard da Tang Nano 4K)
    input  wire rst_n,        // botao de reset onboard (ativo em nivel baixo)

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

    sensor_veiculo #(.N_CYCLES(8)) u_sensor (
        .clk(clk), .rst_n(rst_n), .sensor_raw(sensor_raw),
        .sensor_estavel(sensor_estavel), .veiculo_pulso(veiculo_pulso)
    );

    botao_pedestre #(.N_CYCLES(8)) u_botao (
        .clk(clk), .rst_n(rst_n), .botao_raw(botao_raw),
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

    // ---- amostrador de taxa de trafego (correcao pos-TP5) ----
    // No TP4/TP5, "amostra" ia fixa em 8'd1 por veiculo -- com uma janela de
    // 5 amostras de no maximo 1, a media nunca passava de ~1, entao
    // nivel_fluxo jamais saia de "baixo" na integracao real, por mais
    // veiculos que passassem. Aqui a amostra passa a ser a CONTAGEM de
    // veiculos detectados dentro de uma janela de JANELA_AMOSTRAGEM ciclos
    // de clock -- ou seja, uma taxa real de trafego, nao um pulso fixo.
    // JANELA_AMOSTRAGEM e' pequena aqui para a simulacao ser rapida; numa
    // implementacao fisica real ela seria escalada por um prescaler (mesma
    // ressalva ja documentada para os tempos da FSM).
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
            if (ciclos_janela == JANELA_AMOSTRAGEM - 1) begin
                amostra_fluxo      <= contagem_janela + (veiculo_pulso ? 8'd1 : 8'd0);
                contagem_janela    <= 8'd0;
                ciclos_janela      <= 32'd0;
                nova_amostra_fluxo <= 1'b1;
            end else begin
                ciclos_janela <= ciclos_janela + 32'd1;
                if (veiculo_pulso)
                    contagem_janela <= contagem_janela + 8'd1;
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
        .clk(clk), .rst_n(rst_n),
        .solicitacao_pedestre(solicitacao_pedestre),
        .tempo_min_verde(tempo_min_efetivo),
        .tempo_amarelo({2'b00, tempo_amarelo_reg}),
        .tempo_pedestre(8'd15),
        .estado_carro(estado_carro), .verde_pedestre(verde_pedestre),
        .limpa_solicitacao(limpa_solicitacao),
        .contagem_atual(contagem_fase_atual)
    );

    // ---- decodificacao de LEDs ----
    estado_basico_decoder u_decoder_carro (
        .estado(estado_carro),
        .led_vermelho(led_vermelho), .led_amarelo(led_amarelo), .led_verde(led_verde)
    );
    assign led_ped_verde    = verde_pedestre;
    assign led_ped_vermelho = ~verde_pedestre;

    // ---- protocolo serial final ----
    // Telemetria:
    // em vez de repetir nivel_fluxo/ponteiro da BRAM (que continuam
    // totalmente funcionais e testados internamente -- so' deixam de ser
    // duplicados aqui), o byte enviado por miso agora carrega a fase da
    // FSM + a contagem regressiva de fato, para o ARM montar um countdown
    // real de "quanto falta pro sinal fechar" em vez de so' um indicador
    // de fluxo. contagem_fase_atual e' sempre <= 63 aqui porque
    // tempo_min_reg/tempo_amarelo_reg sao registradores de 6 bits e
    // tempo_min_efetivo tem teto de 63 -- o truncamento pros 6 bits do
    // campo de telemetria nunca perde informacao.
    protocolo_serial u_protocolo (
        .clk(clk), .rst_n(rst_n),
        .sclk(sclk), .cs_n(cs_n), .mosi(mosi),
        .fase_carro_atual(estado_carro), .contagem_regressiva(contagem_fase_atual[5:0]),
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
            limiar_baixo_reg  <= 6'd3;
            limiar_alto_reg   <= 6'd8;
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
