// prescaler: gera um pulso de 1 ciclo (tick) a cada DIVISOR ciclos de
// clk. Converte os ciclos de clock que contador_tempo usa em unidades de
// tempo real (DIVISOR=27_000_000 -> 1 tick/s a 27 MHz). DIVISOR=1 faz o
// tick disparar todo ciclo, usado em testbenches para simular em ciclos.
module prescaler #(
    parameter integer DIVISOR = 27_000_000
) (
    input  wire clk,
    input  wire rst_n,
    output wire tick
);
    reg [31:0] contador;
    reg        tick_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            contador <= 32'd0;
            tick_reg <= 1'b0;
        end else if (contador == DIVISOR - 1) begin
            contador <= 32'd0;
            tick_reg <= 1'b1;
        end else begin
            contador <= contador + 32'd1;
            tick_reg <= 1'b0;
        end
    end

    assign tick = tick_reg;
endmodule
