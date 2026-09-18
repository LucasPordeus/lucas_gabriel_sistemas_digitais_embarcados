// contador_tempo: temporizador decrescente generico, usado pela FSM do
// semaforo para os tempos minimos de cada fase. Carrega "valor_inicial"
// quando "carrega" = 1; decrementa 1 por ciclo enquanto "habilita" = 1;
// "zerou" fica em 1 quando a contagem chega a 0.
module contador_tempo #(
    parameter LARGURA = 16
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  carrega,
    input  wire                  habilita,
    input  wire [LARGURA-1:0]    valor_inicial,
    output reg  [LARGURA-1:0]    valor_atual,
    output wire                  zerou
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            valor_atual <= {LARGURA{1'b0}};
        else if (carrega)
            valor_atual <= valor_inicial;
        else if (habilita && valor_atual != 0)
            valor_atual <= valor_atual - 1'b1;
    end

    assign zerou = (valor_atual == 0);
endmodule
