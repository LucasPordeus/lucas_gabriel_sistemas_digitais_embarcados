// fsm_semaforo: maquina de estados do cruzamento.
//
//   CARRO_VERDE --(pedido pendente e tempo de verde esgotado)--> CARRO_AMARELO
//   CARRO_AMARELO --(tempo_amarelo esgotado)--> PEDESTRE_VERDE
//   PEDESTRE_VERDE --(tempo_pedestre esgotado)--> CARRO_VERDE (apaga o pedido)
//
// Sem pedido, os carros ficam em verde indefinidamente. O tempo de verde
// (tempo_verde, que top_semaforo calcula a partir do fluxo medido) e'
// aplicado em dois momentos:
//   - ao entrar em CARRO_VERDE: verde minimo garantido aos carros;
//   - quando chega um pedido novo: o pedestre espera pelo menos
//     tempo_verde a partir do aperto (se ja faltava mais que isso, nada muda).
// Assim, fluxo baixo libera o pedestre mais rapido e fluxo alto o faz
// esperar mais, mesmo que o verde ja esteja aceso ha muito tempo.
//
// Seguranca: pedestre_verde so' e' 1 no estado PEDESTRE_VERDE, onde
// cor_carro e' forcada a vermelho. Estado invalido volta para CARRO_VERDE
// passando um ciclo com os dois sinais em vermelho.
//
// Parametro:
//   LARGURA_TEMPO - bits dos tempos e do contador (6 bits = ate 63 s)
// Portas:
//   tick                 - 1 pulso por segundo (prescaler)
//   solicitacao_pedestre - 1 enquanto ha pedido de travessia pendente
//   tempo_verde          - segundos de verde para os carros (depende do fluxo)
//   tempo_amarelo        - segundos de amarelo
//   tempo_pedestre       - segundos de verde para o pedestre
//   cor_carro            - cor dos carros: 00 = vermelho, 01 = amarelo, 10 = verde
//   pedestre_verde       - 1 = pedestre verde, 0 = pedestre vermelho
//   limpa_solicitacao    - 1 ciclo em 1 ao fim da travessia (apaga o pedido)
//   contagem_atual       - segundos restantes da fase corrente
module fsm_semaforo #(
    parameter integer LARGURA_TEMPO = 6
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     tick,
    input  wire                     solicitacao_pedestre,
    input  wire [LARGURA_TEMPO-1:0] tempo_verde,
    input  wire [LARGURA_TEMPO-1:0] tempo_amarelo,
    input  wire [LARGURA_TEMPO-1:0] tempo_pedestre,
    output reg  [1:0]               cor_carro,
    output reg                      pedestre_verde,
    output reg                      limpa_solicitacao,
    output wire [LARGURA_TEMPO-1:0] contagem_atual
);
    // codificacao dos estados
    localparam [1:0] CARRO_VERDE    = 2'd0;
    localparam [1:0] CARRO_AMARELO  = 2'd1;
    localparam [1:0] PEDESTRE_VERDE = 2'd2;

    // codificacao de cor_carro (a mesma usada no pacote de telemetria)
    localparam [1:0] COR_VERMELHO = 2'b00;
    localparam [1:0] COR_AMARELO  = 2'b01;
    localparam [1:0] COR_VERDE    = 2'b10;

    reg  [1:0]               estado;          // estado atual
    reg  [1:0]               prox_estado;     // estado do proximo ciclo
    reg                      iniciou;         // 0 so' no 1o ciclo apos reset: forca a 1a carga do contador
    reg                      solicitacao_ant; // solicitacao_pedestre no ciclo anterior
    wire                     pedido_novo;     // 1 no ciclo em que o pedido acabou de chegar
    reg                      carrega_cont;    // 1: recarrega o contador neste ciclo
    reg  [LARGURA_TEMPO-1:0] valor_carga;     // valor carregado quando carrega_cont = 1
    wire                     tempo_esgotado;  // contador da fase chegou a 0

    contador_tempo #(.LARGURA(LARGURA_TEMPO)) u_contador (
        .clk(clk), .rst_n(rst_n),
        .carrega(carrega_cont), .habilita(tick),
        .valor_inicial(valor_carga),
        .valor_atual(contagem_atual), .zerou(tempo_esgotado)
    );

    assign pedido_novo = solicitacao_pedestre & ~solicitacao_ant;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            estado          <= CARRO_VERDE;
            iniciou         <= 1'b0;
            solicitacao_ant <= 1'b0;
        end else begin
            estado          <= prox_estado;
            iniciou         <= 1'b1;
            solicitacao_ant <= solicitacao_pedestre;
        end
    end

    // proximo estado e saidas (Moore: as cores dependem so' de "estado")
    always @(*) begin
        prox_estado       = estado;
        cor_carro         = COR_VERMELHO;
        pedestre_verde    = 1'b0;
        limpa_solicitacao = 1'b0;

        case (estado)
            CARRO_VERDE: begin
                cor_carro = COR_VERDE;
                // pedido_novo bloqueia a troca no ciclo em que o pedido
                // chega, para dar tempo de recarregar a espera do pedestre
                if (tempo_esgotado && solicitacao_pedestre && !pedido_novo)
                    prox_estado = CARRO_AMARELO;
            end
            CARRO_AMARELO: begin
                cor_carro = COR_AMARELO;
                if (tempo_esgotado)
                    prox_estado = PEDESTRE_VERDE;
            end
            PEDESTRE_VERDE: begin
                cor_carro      = COR_VERMELHO;
                pedestre_verde = 1'b1;
                if (tempo_esgotado) begin
                    prox_estado       = CARRO_VERDE;
                    limpa_solicitacao = 1'b1;
                end
            end
            default: prox_estado = CARRO_VERDE;   // estado invalido: tudo vermelho por 1 ciclo
        endcase
    end

    // carga do contador: duracao da fase que esta COMECANDO (prox_estado),
    // ou a espera do pedestre quando um pedido novo chega durante o verde
    always @(*) begin
        case (prox_estado)
            CARRO_AMARELO:  valor_carga = tempo_amarelo;
            PEDESTRE_VERDE: valor_carga = tempo_pedestre;
            default:        valor_carga = tempo_verde;
        endcase

        carrega_cont = !iniciou
                    || (prox_estado != estado)
                    || (estado == CARRO_VERDE && pedido_novo && contagem_atual < tempo_verde);
    end
endmodule
