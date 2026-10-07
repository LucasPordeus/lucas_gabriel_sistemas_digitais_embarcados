// bram_historico: historico circular de 256 amostras de fluxo (veiculos
// contados por janela de medicao), mapeado em um bloco BSRAM da Tang Nano
// 4K. top_semaforo grava cada amostra nova e le a amostra que esta saindo
// da janela da media movel (media_movel_dsp).
//
// A memoria nao tem reset (requisito para virar BSRAM); quem garante que
// conteudo antigo nao entra na media e' o contador de amostras validas
// do media_movel_dsp.
//
// Portas:
//   escreve          - 1 ciclo em 1: grava dado_escrita e avanca o ponteiro
//   dado_escrita     - amostra a gravar
//   endereco_leitura - posicao a ler
//   dado_leitura     - conteudo de endereco_leitura (leitura sincrona: 1 ciclo de atraso)
//   ponteiro_escrita - posicao onde a proxima amostra sera gravada (volta a 0 apos 255)
module bram_historico (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       escreve,
    input  wire [7:0] dado_escrita,
    input  wire [7:0] endereco_leitura,
    output reg  [7:0] dado_leitura,
    output reg  [7:0] ponteiro_escrita
);
    (* ram_style = "block", syn_ramstyle = "block_ram" *)
    reg [7:0] memoria [0:255];   // 256 amostras de 8 bits

    always @(posedge clk) begin
        if (escreve)
            memoria[ponteiro_escrita] <= dado_escrita;
        dado_leitura <= memoria[endereco_leitura];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ponteiro_escrita <= 8'd0;
        else if (escreve)
            ponteiro_escrita <= ponteiro_escrita + 8'd1;
    end
endmodule
