// fsm_semaforo: maquina de estados finitos do semaforo, hierarquica
// (instancia contador_tempo para os tempos minimos de cada fase).
// Estados: CARRO_VERDE -> CARRO_AMARELO -> PEDESTRE_VERDE -> CARRO_VERDE
// A solicitacao do pedestre so e atendida apos o tempo minimo de verde
// dos veiculos ter decorrido (ONF-08: seguranca do cruzamento).
module fsm_semaforo #(
    parameter LARGURA_TEMPO = 16
) (
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire                      solicitacao_pedestre,
    input  wire [LARGURA_TEMPO-1:0]  tempo_min_verde,
    input  wire [LARGURA_TEMPO-1:0]  tempo_amarelo,
    input  wire [LARGURA_TEMPO-1:0]  tempo_pedestre,
    output reg  [1:0]                estado_carro,     // 00=vermelho 01=amarelo 10=verde
    output reg                       verde_pedestre,
    output reg                       limpa_solicitacao
);
    localparam CARRO_VERDE    = 2'd0;
    localparam CARRO_AMARELO  = 2'd1;
    localparam PEDESTRE_VERDE = 2'd2;

    reg [1:0] estado, prox_estado;
    reg       carrega_cont;
    reg [LARGURA_TEMPO-1:0] valor_inicial_cont;
    wire [LARGURA_TEMPO-1:0] valor_atual_cont;
    wire      tempo_esgotado;
    reg       iniciou;   // forca a 1a carga do contador logo apos o reset

    contador_tempo #(.LARGURA(LARGURA_TEMPO)) u_contador (
        .clk(clk), .rst_n(rst_n),
        .carrega(carrega_cont), .habilita(1'b1),
        .valor_inicial(valor_inicial_cont),
        .valor_atual(valor_atual_cont), .zerou(tempo_esgotado)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            estado  <= CARRO_VERDE;
            iniciou <= 1'b0;
        end else begin
            estado  <= prox_estado;
            iniciou <= 1'b1;
        end
    end

    // 1) decide a transicao de estado (saidas tipo Moore, dependem so de "estado")
    always @(*) begin
        prox_estado     = estado;
        estado_carro     = 2'b00;
        verde_pedestre    = 1'b0;
        limpa_solicitacao = 1'b0;

        case (estado)
            CARRO_VERDE: begin
                estado_carro = 2'b10; // verde
                if (tempo_esgotado && solicitacao_pedestre)
                    prox_estado = CARRO_AMARELO;
            end
            CARRO_AMARELO: begin
                estado_carro = 2'b01; // amarelo
                if (tempo_esgotado)
                    prox_estado = PEDESTRE_VERDE;
            end
            PEDESTRE_VERDE: begin
                estado_carro   = 2'b00; // vermelho para os veiculos
                verde_pedestre  = 1'b1;
                if (tempo_esgotado) begin
                    prox_estado       = CARRO_VERDE;
                    limpa_solicitacao = 1'b1;
                end
            end
            default: prox_estado = CARRO_VERDE;
        endcase
    end

    // 2) valor a carregar no contador = duracao da fase que esta SENDO
    // ENTRADA (prox_estado), nao da fase atual -- evita carregar a
    // duracao errada no ciclo de transicao.
    always @(*) begin
        case (prox_estado)
            CARRO_VERDE:    valor_inicial_cont = tempo_min_verde;
            CARRO_AMARELO:  valor_inicial_cont = tempo_amarelo;
            PEDESTRE_VERDE: valor_inicial_cont = tempo_pedestre;
            default:        valor_inicial_cont = tempo_min_verde;
        endcase
        carrega_cont = (prox_estado != estado) || !iniciou;
    end
endmodule
