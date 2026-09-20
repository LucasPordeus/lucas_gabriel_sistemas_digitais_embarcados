// prescaler: gera um pulso de 1 ciclo de "clk" (tick) a cada DIVISOR
// ciclos, usado para converter os "ciclos de clock" que contador_tempo
// usa internamente em unidades de tempo perceptiveis por humanos em
// hardware real.
//
// A Tang Nano 4K roda a 27 MHz sem nenhum divisor no meio (ressalva ja
// documentada em top_semaforo.v/CONTEXTO_PROJETO): sem isso, um "tempo de
// verde = 10" dura ~370 ns -- impossivel de perceber ao vivo, mesmo
// apertando o botao de pedestre. Com DIVISOR=27_000_000 (padrao), o tick
// dispara 1 vez por segundo real, entao cada unidade de tempo_min/
// tempo_amarelo/tempo_pedestre passa a valer 1 segundo de verdade.
//
// Em testbenches, DIVISOR=1 faz o tick disparar em todo ciclo de "clk" --
// ou seja, contador_tempo decrementa exatamente como antes desta
// extensao, preservando 100% da temporizacao (e dos resultados) de todos
// os testbenches ja validados. Mesma tecnica ja usada para
// JANELA_AMOSTRAGEM em top_semaforo.v (parametro pequeno na simulacao,
// maior em hardware real).
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
