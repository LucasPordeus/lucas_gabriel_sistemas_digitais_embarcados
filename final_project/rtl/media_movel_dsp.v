// media_movel_dsp: media movel das ultimas 5 amostras de fluxo e
// classificacao do transito em baixo/medio/alto. A soma da janela e'
// mantida incrementalmente (soma + amostra nova - amostra que sai, lida
// da bram_historico) e a divisao por 5 vira uma multiplicacao pelo
// reciproco em ponto fixo, mapeada no bloco DSP (MULT18X18) da FPGA.
//
// Parametros:
//   LIMIAR_BAIXO - media <= LIMIAR_BAIXO  -> fluxo baixo
//   LIMIAR_ALTO  - media >  LIMIAR_ALTO   -> fluxo alto (entre os dois: medio)
// Portas:
//   nova_amostra   - 1 ciclo em 1: chegou a contagem de uma janela
//   amostra        - veiculos contados na janela que acabou de fechar
//   amostra_saindo - amostra de 5 janelas atras (da BRAM), que sai da media
//   media          - media arredondada das ultimas 5 amostras
//   nivel_fluxo    - 00 = baixo, 01 = medio, 10 = alto
module media_movel_dsp #(
    parameter integer LIMIAR_BAIXO = 1,
    parameter integer LIMIAR_ALTO  = 3
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       nova_amostra,
    input  wire [7:0] amostra,
    input  wire [7:0] amostra_saindo,
    output reg  [7:0] media,
    output reg  [1:0] nivel_fluxo
);
    localparam integer N_JANELA      = 5;          // amostras na media
    localparam [16:0]  RECIPROCO_Q16 = 17'd13107;  // round(65536 / 5): 1/5 em ponto fixo Q16

    reg  [2:0]  amostras_validas;  // amostras ja na janela (satura em N_JANELA)
    reg  [10:0] soma;              // soma da janela (5 x 255 = 1275 cabe em 11 bits)
    wire [7:0]  valor_saindo;      // amostra_saindo, ou 0 enquanto a janela ainda enche
    wire [10:0] soma_nova;         // soma ja com a amostra que entra e sem a que sai
    (* syn_dspstyle = "dsp" *)
    wire [27:0] produto;           // soma_nova * (1/5) em Q16 -> bloco DSP
    wire [27:0] produto_arred;     // produto + 0,5 (arredonda ao descartar a parte fracionaria)
    wire [7:0]  media_nova;        // parte inteira de produto_arred = round(soma_nova / 5)

    assign valor_saindo  = (amostras_validas == N_JANELA) ? amostra_saindo : 8'd0;
    assign soma_nova     = soma - valor_saindo + amostra;
    assign produto       = soma_nova * RECIPROCO_Q16;
    assign produto_arred = produto + 28'd32768;
    assign media_nova    = produto_arred[23:16];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            amostras_validas <= 3'd0;
            soma             <= 11'd0;
            media            <= 8'd0;
            nivel_fluxo      <= 2'b00;
        end else if (nova_amostra) begin
            if (amostras_validas != N_JANELA)
                amostras_validas <= amostras_validas + 3'd1;
            soma  <= soma_nova;
            media <= media_nova;

            if (media_nova <= LIMIAR_BAIXO)
                nivel_fluxo <= 2'b00;
            else if (media_nova <= LIMIAR_ALTO)
                nivel_fluxo <= 2'b01;
            else
                nivel_fluxo <= 2'b10;
        end
    end
endmodule
