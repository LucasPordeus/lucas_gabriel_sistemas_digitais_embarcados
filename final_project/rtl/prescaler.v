// prescaler: divide o clock de 27 MHz e gera um pulso "tick" de 1 ciclo
// a cada DIVISOR ciclos. Com DIVISOR = 27_000_000 sai 1 tick por segundo,
// que e' a unidade de tempo da FSM e da janela de medicao de fluxo.
//
// Parametro:
//   DIVISOR - ciclos de clk entre dois ticks
// Portas:
//   tick - 1 ciclo em 1 a cada DIVISOR ciclos
module prescaler #(
    parameter integer DIVISOR = 27_000_000
) (
    input  wire clk,
    input  wire rst_n,
    output reg  tick
);
    localparam integer LARGURA = (DIVISOR > 1) ? $clog2(DIVISOR) : 1;

    reg [LARGURA-1:0] contador;   // ciclos desde o ultimo tick (0 .. DIVISOR-1)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            contador <= {LARGURA{1'b0}};
            tick     <= 1'b0;
        end else if (contador == DIVISOR - 1) begin
            contador <= {LARGURA{1'b0}};
            tick     <= 1'b1;
        end else begin
            contador <= contador + 1'b1;
            tick     <= 1'b0;
        end
    end
endmodule
