// top_semaforo: modulo de topo do semaforo inteligente com botao de
// pedestre. Integra sensor de veiculo, botao, FSM de fases, filtro de
// media movel de trafego, protocolo serial de telemetria/configuracao, e
// decodificacao de LEDs. Tempo de verde e ajustado dinamicamente pelo
// nivel_fluxo medido internamente, sem depender de comando do ARM.
module top_semaforo #(
    // duracao da janela de amostragem de trafego, em TICKS (nao em
    // ciclos de clock puro -- ver prescaler abaixo). Com DIVISOR_TICK
    // padrao (1 tick/s), cada unidade equivale a 1 segundo real.
    parameter integer JANELA_AMOSTRAGEM = 3,

    // divisor do prescaler: ciclos de "clk" por tick. Padrao =
    // 27_000_000 -> 1 tick/s real a 27 MHz. Testbenches usam
    // DIVISOR_TICK=1 (tick a cada ciclo) para simular em ciclos.
    parameter integer DIVISOR_TICK = 27_000_000
) (
    input  wire clk,          // 27 MHz (oscilador onboard da Tang Nano 4K)
    input  wire rst_n,        // reset assincrono ativo em nivel baixo; sem
                              // pino fixo no .cst (ver constraints/tangnano4k.cst)

    // sensores e atuadores fisicos
    input  wire sensor_raw,
    input  wire botao_raw,
    output wire led_vermelho,
    output wire led_amarelo,
    output wire led_verde,
    output wire led_ped_verde,
    output wire led_ped_vermelho,

    // interface serial ARM <-> FPGA
    input  wire sclk,
    input  wire cs_n,
    input  wire mosi,
    output wire miso,
    output wire busy
);

    wire sensor_estavel, veiculo_pulso;
    wire botao_estavel, solicitacao_pedestre;
    wire limpa_solicitacao;

    // sensor_raw e botao_raw sao ativos em nivel BAIXO no hardware usado
    // (sensor IR tipo FC-51 e botao onboard S1 com pull-up fisico) -- o
    // oposto da convencao de sensor_veiculo.v/botao_pedestre.v (repouso
    // baixo, evento em nivel alto). Invertidos aqui na instanciacao.
    sensor_veiculo #(.N_CYCLES(8)) u_sensor (
        .clk(clk), .rst_n(rst_n), .sensor_raw(~sensor_raw),
        .sensor_estavel(sensor_estavel), .veiculo_pulso(veiculo_pulso)
    );

    botao_pedestre #(.N_CYCLES(8)) u_botao (
        .clk(clk), .rst_n(rst_n), .botao_raw(~botao_raw),
        .limpa_solicitacao(limpa_solicitacao),
        .botao_estavel(botao_estavel), .solicitacao_pedestre(solicitacao_pedestre)
    );

    // ---- registradores de configuracao (via protocolo serial) ----
    wire [7:0] comando_recebido;
    wire       comando_valido;
    reg  [5:0] tempo_min_reg, tempo_amarelo_reg, limiar_baixo_reg, limiar_alto_reg;

    localparam OP_TEMPO_MIN     = 2'b00;
    localparam OP_TEMPO_AMARELO = 2'b01;
    localparam OP_LIMIAR_BAIXO  = 2'b10;
    localparam OP_LIMIAR_ALTO   = 2'b11;

    // ---- historico de veiculos (BRAM) ----
    wire [7:0] contagem_dummy_leitura;
    reg  [7:0] ponteiro_escrita_reg;
    wire [7:0] ponteiro_escrita_w;
    wire [7:0] media_fluxo;
    wire [1:0] nivel_fluxo;

    bram_historico u_bram (
        .clk(clk), .rst_n(rst_n),
        .escreve(veiculo_pulso), .dado_escrita(8'd1),
        .endereco_leitura(8'd0), .dado_leitura(contagem_dummy_leitura),
        .ponteiro_escrita(ponteiro_escrita_w)
    );

    // ---- prescaler: ciclos de clock -> ticks de tempo real ----
    wire tick_fsm;
    prescaler #(.DIVISOR(DIVISOR_TICK)) u_prescaler (
        .clk(clk), .rst_n(rst_n), .tick(tick_fsm)
    );

    // ---- amostrador de taxa de trafego ----
    // Conta veiculo_pulso a cada ciclo; fecha a janela (gera uma amostra
    // pra media_movel_dsp) a cada JANELA_AMOSTRAGEM ticks.
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

    // ---- tempo de verde dinamico por nivel de fluxo ----
    // tempo_min_reg = referencia para trafego MEDIO. Baixo: metade (piso
    // TEMPO_MIN_PISO). Alto: dobro (teto TEMPO_MIN_TETO, limite do
    // registrador de 6 bits do protocolo serial).
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
            2'b00:   tempo_min_efetivo = tempo_min_metade_w; // baixo
            2'b10:   tempo_min_efetivo = tempo_min_dobro_w;  // alto
            default: tempo_min_efetivo = tempo_min_base_w;   // medio
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
    // Diferente de contagem_fase_atual (reseta a cada troca de fase):
    // soma o tempo restante das fases que ainda faltam antes do pedestre
    // abrir. CARRO_VERDE: resto do verde + amarelo inteiro. CARRO_AMARELO:
    // so' o resto do amarelo. PEDESTRE_VERDE: 0 (ja aberto).
    reg [7:0] tempo_ate_pedestre;
    always @(*) begin
        case (estado_carro)
            2'b10:   tempo_ate_pedestre = contagem_fase_atual + {2'b00, tempo_amarelo_reg};
            2'b01:   tempo_ate_pedestre = contagem_fase_atual;
            default: tempo_ate_pedestre = 8'd0;
        endcase
    end

    // ---- decodificacao de LEDs ----
    estado_basico_decoder u_decoder_carro (
        .estado(estado_carro),
        .led_vermelho(led_vermelho), .led_amarelo(led_amarelo), .led_verde(led_verde)
    );
    assign led_ped_verde    = verde_pedestre;
    assign led_ped_vermelho = ~verde_pedestre;

    // ---- protocolo serial: telemetria e configuracao ----
    // fase_telemetria reaproveita o codigo 11 (nao usado por
    // estado_carro) para indicar "CARRO_VERDE com pedido de pedestre
    // pendente" -- diferencia esse caso de "CARRO_VERDE sem pedido" sem
    // gastar bit extra no byte de telemetria. Nao afeta os LEDs, que
    // continuam usando estado_carro puro.
    wire [1:0] fase_telemetria = (estado_carro == 2'b10 && solicitacao_pedestre)
                                  ? 2'b11 : estado_carro;

    // Byte de telemetria: [7:6]=fase_telemetria [5:4]=nivel_fluxo
    // [3:0]=tempo_ate_pedestre truncado para 4 bits (0-15; em trafego
    // alto o valor real pode ultrapassar 15 e saturar -- limitacao de
    // exibicao no monitor da Raspberry Pi, a FSM interna nao trunca).
    protocolo_serial u_protocolo (
        .clk(clk), .rst_n(rst_n),
        .sclk(sclk), .cs_n(cs_n), .mosi(mosi),
        .fase_carro_atual(fase_telemetria),
        .contagem_regressiva({nivel_fluxo, tempo_ate_pedestre[3:0]}),
        .miso(miso), .busy(busy),
        .comando_recebido(comando_recebido), .comando_valido(comando_valido)
    );

    // decodifica comando recebido e atualiza os registradores de
    // configuracao; valores padrao de seguranca aplicados no reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tempo_min_reg     <= 6'd10;
            tempo_amarelo_reg <= 6'd3;
            // limiares de producao seriam 3/8 (exige trafego sustentado
            // para virar "alto"); reduzidos para 0/1 para demonstracao
            // manual mais facil (~1 deteccao/janela sustentada = medio,
            // ~2+ = alto).
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
