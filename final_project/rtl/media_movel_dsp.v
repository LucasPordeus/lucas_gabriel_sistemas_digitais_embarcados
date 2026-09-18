// media_movel_dsp: filtro de media movel sobre uma janela de 5 amostras,
// usando um multiplicador (mapeado para o bloco DSP nativo da Tang Nano
// 4K pelo Gowin EDA) para calcular soma*(1/5) em ponto fixo, em vez de
// uma divisao (mais cara em FPGA). Classifica o nivel de fluxo comparando
// a media com os limiares recebidos do protocolo_paralelo.
module media_movel_dsp (
    input  wire       clk,
    input  wire       rst_n,
    input  wire        nova_amostra,     // pulso: uma nova contagem de intervalo chegou
    input  wire [7:0]  amostra,
    input  wire [5:0]  limiar_baixo,
    input  wire [5:0]  limiar_alto,
    output reg  [7:0]  media,
    output reg  [1:0]  nivel_fluxo       // 00=baixo 01=medio 10=alto
);
    localparam N_JANELA = 5;
    localparam RECIPROCO_Q16 = 17'd13107; // round(65536/5), ponto fixo Q16

    reg  [7:0]  janela [0:N_JANELA-1];
    reg  [10:0] soma;                     // 5 amostras de 8 bits: max 1275, cabe em 11 bits
    wire [10:0] soma_novo;
    wire [27:0] produto;                  // soma_novo(11) * reciproco(17) -> mapeia para DSP
    wire [27:0] produto_arred;             // produto + meio-LSB (arredondamento Q16)

    integer i;

    // soma ja incluindo a amostra que esta entrando (e removendo a mais antiga)
    assign soma_novo = soma - janela[N_JANELA-1] + amostra;
    assign produto    = soma_novo * RECIPROCO_Q16; // multiplicacao (bloco DSP)
    assign produto_arred = produto + 28'd32768;      // arredondamento (+0.5 em Q16) antes do shift

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < N_JANELA; i = i + 1)
                janela[i] <= 8'd0;
            soma        <= 11'd0;
            media       <= 8'd0;
            nivel_fluxo <= 2'b00;
        end else if (nova_amostra) begin
            for (i = N_JANELA - 1; i > 0; i = i - 1)
                janela[i] <= janela[i-1];
            janela[0] <= amostra;

            soma  <= soma_novo;
            media <= produto_arred[23:16]; // >> 16 arredondado -> soma/5 aproximado

            if (produto_arred[23:16] <= {2'b00, limiar_baixo})
                nivel_fluxo <= 2'b00; // baixo
            else if (produto_arred[23:16] <= {2'b00, limiar_alto})
                nivel_fluxo <= 2'b01; // medio
            else
                nivel_fluxo <= 2'b10; // alto
        end
    end
endmodule
