// top_semaforo: modulo de topo do semaforo inteligente na Tang Nano 4K.
//
// Fluxo dos dados:
//   botao S1 -> botao_pedestre -> pedido de travessia ----------------+
//   sensor IR -> sensor_veiculo -> contagem por janela -> bram_historico
//             -> media_movel_dsp -> nivel_fluxo -> tempo de verde -----+-> fsm_semaforo -> LEDs
//   fsm + fluxo + pedido -> quadro de telemetria -> protocolo_serial -> Raspberry Pi (so' monitora)
//
// Toda decisao e' tomada aqui; os tempos sao parametros de projeto e nao
// podem ser alterados pela Raspberry Pi.
//
// Parametros (valores padrao = hardware real a 27 MHz; os testbenches
// reduzem os tempos para simular rapido):
//   CLK_HZ            - frequencia do oscilador da placa
//   DIVISOR_TICK      - ciclos de clk por tick (1 tick = 1 segundo)
//   DEBOUNCE_BOTAO    - ciclos de estabilidade do botao (20 ms)
//   DEBOUNCE_SENSOR   - ciclos de estabilidade do sensor IR (5 ms)
//   JANELA_AMOSTRAGEM - ticks por janela de contagem de veiculos (minimo 3)
//   LIMIAR_BAIXO      - media de veiculos/janela ate a qual o fluxo e' baixo
//   LIMIAR_ALTO       - media de veiculos/janela acima da qual o fluxo e' alto
//   TEMPO_VERDE_BAIXO, TEMPO_VERDE_MEDIO, TEMPO_VERDE_ALTO
//                     - segundos de verde dos carros para cada nivel de fluxo
//   TEMPO_AMARELO     - segundos de amarelo
//   TEMPO_PEDESTRE    - segundos de verde do pedestre
//
// Portas (pinos em constraints/tangnano4k.cst):
//   clk        - oscilador de 27 MHz
//   rst_n      - botao S2 da placa (0 = apertado = reset)
//   botao_raw  - botao S1 da placa (0 = apertado = pedido de travessia)
//   sensor_raw - saida do sensor IR (0 = veiculo detectado)
//   led_*      - 1 = LED aceso
//   sclk, cs_n - clock e selecao de quadro gerados pela Raspberry Pi
//   miso       - telemetria serial para a Raspberry Pi
module top_semaforo #(
    parameter integer CLK_HZ            = 27_000_000,
    parameter integer DIVISOR_TICK      = CLK_HZ,
    parameter integer DEBOUNCE_BOTAO    = CLK_HZ / 1000 * 20,
    parameter integer DEBOUNCE_SENSOR   = CLK_HZ / 1000 * 5,
    parameter integer JANELA_AMOSTRAGEM = 10,
    parameter integer LIMIAR_BAIXO      = 1,
    parameter integer LIMIAR_ALTO       = 3,
    parameter integer TEMPO_VERDE_BAIXO = 5,
    parameter integer TEMPO_VERDE_MEDIO = 10,
    parameter integer TEMPO_VERDE_ALTO  = 20,
    parameter integer TEMPO_AMARELO     = 3,
    parameter integer TEMPO_PEDESTRE    = 15
) (
    input  wire clk,
    input  wire rst_n,
    input  wire botao_raw,
    input  wire sensor_raw,
    output wire led_vermelho,
    output wire led_amarelo,
    output wire led_verde,
    output wire led_ped_verde,
    output wire led_ped_vermelho,
    input  wire sclk,
    input  wire cs_n,
    output wire miso
);
    // ---- reset: entra na hora, sai sincronizado ao clk ----
    reg [1:0] reset_sinc;   // reset_sinc[1] = 1 dois ciclos apos soltar S2
    wire      rst_sist_n;   // reset usado por todo o sistema (ativo em 0)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            reset_sinc <= 2'b00;
        else
            reset_sinc <= {reset_sinc[0], 1'b1};
    end
    assign rst_sist_n = reset_sinc[1];

    // ---- tick de 1 segundo ----
    wire tick;   // 1 ciclo em 1 por segundo

    prescaler #(.DIVISOR(DIVISOR_TICK)) u_prescaler (
        .clk(clk), .rst_n(rst_sist_n), .tick(tick)
    );

    // ---- entradas fisicas (ativas em nivel baixo na placa, invertidas aqui) ----
    wire veiculo_pulso;          // 1 ciclo em 1 por veiculo detectado
    wire solicitacao_pedestre;   // pedido de travessia pendente
    wire limpa_solicitacao;      // FSM apaga o pedido ao fim da travessia

    sensor_veiculo #(.N_CICLOS(DEBOUNCE_SENSOR)) u_sensor (
        .clk(clk), .rst_n(rst_sist_n),
        .sensor_ativo(~sensor_raw), .veiculo_pulso(veiculo_pulso)
    );

    botao_pedestre #(.N_CICLOS(DEBOUNCE_BOTAO)) u_botao (
        .clk(clk), .rst_n(rst_sist_n),
        .botao_ativo(~botao_raw), .limpa_solicitacao(limpa_solicitacao),
        .solicitacao_pedestre(solicitacao_pedestre)
    );

    // ---- contagem de veiculos por janela de JANELA_AMOSTRAGEM segundos ----
    localparam integer LARGURA_JANELA = (JANELA_AMOSTRAGEM > 1) ? $clog2(JANELA_AMOSTRAGEM) : 1;

    reg [LARGURA_JANELA-1:0] ticks_janela;     // segundos ja passados na janela atual
    reg [7:0]                contagem_janela;  // veiculos na janela atual (satura em 255)
    reg [7:0]                amostra_fluxo;    // contagem da ultima janela fechada
    reg                      nova_amostra;     // 1 ciclo em 1 quando amostra_fluxo e' atualizada

    wire [7:0] contagem_com_pulso = (veiculo_pulso && contagem_janela != 8'hFF)
                                    ? contagem_janela + 8'd1 : contagem_janela;

    always @(posedge clk or negedge rst_sist_n) begin
        if (!rst_sist_n) begin
            ticks_janela    <= {LARGURA_JANELA{1'b0}};
            contagem_janela <= 8'd0;
            amostra_fluxo   <= 8'd0;
            nova_amostra    <= 1'b0;
        end else begin
            nova_amostra <= 1'b0;
            if (tick && ticks_janela == JANELA_AMOSTRAGEM - 1) begin
                // fecha a janela: entrega a contagem e comeca outra do zero
                amostra_fluxo   <= contagem_com_pulso;
                nova_amostra    <= 1'b1;
                contagem_janela <= 8'd0;
                ticks_janela    <= {LARGURA_JANELA{1'b0}};
            end else begin
                contagem_janela <= contagem_com_pulso;
                if (tick)
                    ticks_janela <= ticks_janela + 1'b1;
            end
        end
    end

    // ---- historico em BRAM + media movel em DSP ----
    localparam [7:0] N_JANELA_MEDIA = 8'd5;   // tamanho da janela de media_movel_dsp

    wire [7:0] ponteiro_historico;   // proxima posicao de escrita na BRAM
    wire [7:0] amostra_saindo;       // amostra gravada 5 janelas atras
    wire [7:0] media_fluxo;          // media de veiculos por janela (ultimas 5 janelas)
    wire [1:0] nivel_fluxo;          // 00 = baixo, 01 = medio, 10 = alto

    bram_historico u_historico (
        .clk(clk), .rst_n(rst_sist_n),
        .escreve(nova_amostra), .dado_escrita(amostra_fluxo),
        .endereco_leitura(ponteiro_historico - N_JANELA_MEDIA),
        .dado_leitura(amostra_saindo),
        .ponteiro_escrita(ponteiro_historico)
    );

    media_movel_dsp #(.LIMIAR_BAIXO(LIMIAR_BAIXO), .LIMIAR_ALTO(LIMIAR_ALTO)) u_media (
        .clk(clk), .rst_n(rst_sist_n),
        .nova_amostra(nova_amostra), .amostra(amostra_fluxo),
        .amostra_saindo(amostra_saindo),
        .media(media_fluxo), .nivel_fluxo(nivel_fluxo)
    );

    // ---- tempo de verde conforme o fluxo medido ----
    reg [5:0] tempo_verde;   // segundos de verde dos carros para o nivel atual

    always @(*) begin
        case (nivel_fluxo)
            2'b00:   tempo_verde = TEMPO_VERDE_BAIXO;
            2'b10:   tempo_verde = TEMPO_VERDE_ALTO;
            default: tempo_verde = TEMPO_VERDE_MEDIO;
        endcase
    end

    // ---- maquina de estados ----
    localparam [5:0] T_AMARELO  = TEMPO_AMARELO;    // tempos fixos em 6 bits, largura da FSM
    localparam [5:0] T_PEDESTRE = TEMPO_PEDESTRE;

    wire [1:0] cor_carro;        // 00 = vermelho, 01 = amarelo, 10 = verde
    wire       pedestre_verde;   // 1 = pedestre pode atravessar
    wire [5:0] contagem_fase;    // segundos restantes da fase atual

    fsm_semaforo #(.LARGURA_TEMPO(6)) u_fsm (
        .clk(clk), .rst_n(rst_sist_n), .tick(tick),
        .solicitacao_pedestre(solicitacao_pedestre),
        .tempo_verde(tempo_verde),
        .tempo_amarelo(T_AMARELO),
        .tempo_pedestre(T_PEDESTRE),
        .cor_carro(cor_carro), .pedestre_verde(pedestre_verde),
        .limpa_solicitacao(limpa_solicitacao),
        .contagem_atual(contagem_fase)
    );

    // ---- LEDs ----
    estado_basico_decoder u_leds_carro (
        .cor_carro(cor_carro),
        .led_vermelho(led_vermelho), .led_amarelo(led_amarelo), .led_verde(led_verde)
    );
    assign led_ped_verde    = pedestre_verde;
    assign led_ped_vermelho = ~pedestre_verde;

    // ---- telemetria para a Raspberry Pi ----
    // Quadro de 16 bits (MSB primeiro):
    //   [15:12] marcador fixo 1010: a Raspberry descarta quadros sem ele
    //   [11:10] cor dos carros: 00 vermelho, 01 amarelo, 10 verde
    //   [9]     pedestre: 1 verde, 0 vermelho
    //   [8]     pedido de travessia pendente
    //   [7:6]   nivel de fluxo: 00 baixo, 01 medio, 10 alto
    //   [5:0]   segundos restantes da fase atual
    localparam [3:0] MARCADOR_QUADRO = 4'b1010;

    wire [15:0] quadro_telemetria = {MARCADOR_QUADRO, cor_carro, pedestre_verde,
                                     solicitacao_pedestre, nivel_fluxo, contagem_fase};

    protocolo_serial u_telemetria (
        .clk(clk), .rst_n(rst_sist_n),
        .sclk(sclk), .cs_n(cs_n),
        .quadro(quadro_telemetria),
        .miso(miso)
    );
endmodule
