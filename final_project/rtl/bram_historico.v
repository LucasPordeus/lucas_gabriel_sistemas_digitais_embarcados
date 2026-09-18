// bram_historico: buffer circular de 256 amostras (inferido em BRAM pelo
// Gowin EDA, por ser uma memoria sincrona com porta de escrita e porta de
// leitura independentes e enderecos de 8 bits). Guarda a contagem de
// veiculos de cada intervalo de amostragem, para uso pelo filtro de media
// movel e por telemetria futura (TP5).
module bram_historico (
    input  wire       clk,
    input  wire       rst_n,
    input  wire        escreve,          // pulso: grava dado_escrita e avanca o ponteiro
    input  wire [7:0]  dado_escrita,
    input  wire [7:0]  endereco_leitura, // endereco livre para leitura (ex.: dump via protocolo)
    output reg  [7:0]  dado_leitura,
    output reg  [7:0]  ponteiro_escrita  // posicao da proxima escrita (util para telemetria)
);
    reg [7:0] memoria [0:255];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ponteiro_escrita <= 8'd0;
        end else if (escreve) begin
            memoria[ponteiro_escrita] <= dado_escrita;
            ponteiro_escrita <= ponteiro_escrita + 8'd1; // circular (wrap natural em 8 bits)
        end
    end

    // leitura sincrona (padrao para inferencia de BRAM real no Gowin EDA)
    always @(posedge clk) begin
        dado_leitura <= memoria[endereco_leitura];
    end
endmodule
