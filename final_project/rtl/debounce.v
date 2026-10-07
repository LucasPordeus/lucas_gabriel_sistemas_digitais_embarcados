// debounce: filtra uma entrada mecanica/ruidosa (botao ou sensor IR).
// Sincroniza a entrada assincrona com 2 flip-flops (evita metaestabilidade)
// e so' muda a saida depois que a entrada fica N_CICLOS ciclos seguidos
// no novo nivel. Usado por botao_pedestre e sensor_veiculo.
//
// Parametro:
//   N_CICLOS - ciclos de clk que a entrada precisa ficar estavel
//              (ex.: 540_000 ciclos = 20 ms a 27 MHz)
// Portas:
//   entrada - sinal bruto, ativo em nivel ALTO (assincrono ao clk)
//   saida   - sinal filtrado e sincronizado ao clk (repouso = 0)
module debounce #(
    parameter integer N_CICLOS = 540_000
) (
    input  wire clk,
    input  wire rst_n,
    input  wire entrada,
    output reg  saida
);
    localparam integer LARGURA_CONT = $clog2(N_CICLOS + 1);

    reg [1:0]              sinc;      // cadeia de sincronizacao; sinc[1] = entrada ja sincronizada
    reg [LARGURA_CONT-1:0] contador;  // ciclos seguidos em que sinc[1] difere de saida

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sinc     <= 2'b00;
            contador <= {LARGURA_CONT{1'b0}};
            saida    <= 1'b0;
        end else begin
            sinc <= {sinc[0], entrada};

            if (sinc[1] == saida)
                contador <= {LARGURA_CONT{1'b0}};       // qualquer repique reinicia a contagem
            else if (contador == N_CICLOS - 1) begin
                saida    <= sinc[1];                    // estavel tempo suficiente: aceita o novo nivel
                contador <= {LARGURA_CONT{1'b0}};
            end else
                contador <= contador + 1'b1;
        end
    end
endmodule
