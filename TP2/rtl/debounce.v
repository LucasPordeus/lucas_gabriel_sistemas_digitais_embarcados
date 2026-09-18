// debounce: filtro anti-ruido generico e parametrizavel.
// Considera a entrada estavel somente apos N_CYCLES ciclos de clock
// consecutivos com o mesmo valor (contador que satura e reinicia a
// qualquer transicao).
module debounce #(
    parameter N_CYCLES = 8   // ciclos consecutivos estaveis exigidos
) (
    input  wire clk,
    input  wire rst_n,
    input  wire in_raw,      // entrada assincrona/ruidosa
    output reg  out_stable   // saida filtrada
);
    localparam CNT_W = $clog2(N_CYCLES + 1);

    reg [CNT_W-1:0] contador;
    reg             in_sync;   // 1 flip-flop de sincronizacao (evita metaestabilidade)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_sync    <= 1'b0;
            contador   <= {CNT_W{1'b0}};
            out_stable <= 1'b0;
        end else begin
            in_sync <= in_raw;

            if (in_sync == out_stable) begin
                contador <= {CNT_W{1'b0}};
            end else if (contador >= N_CYCLES - 1) begin
                out_stable <= in_sync;
                contador   <= {CNT_W{1'b0}};
            end else begin
                contador <= contador + 1'b1;
            end
        end
    end
endmodule
