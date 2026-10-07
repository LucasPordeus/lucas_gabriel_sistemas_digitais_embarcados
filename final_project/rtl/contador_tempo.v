// contador_tempo: temporizador decrescente usado pela fsm_semaforo para
// medir a duracao de cada fase, em ticks (segundos).
//
// Parametro:
//   LARGURA - bits do contador
// Portas:
//   carrega       - 1: copia valor_inicial para o contador (prioridade sobre habilita)
//   habilita      - 1: decrementa 1 (ligado ao tick de 1 s); para em 0
//   valor_inicial - duracao a carregar
//   valor_atual   - tempo restante da fase
//   zerou         - 1 quando valor_atual == 0 (tempo da fase esgotado)
module contador_tempo #(
    parameter integer LARGURA = 6
) (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               carrega,
    input  wire               habilita,
    input  wire [LARGURA-1:0] valor_inicial,
    output reg  [LARGURA-1:0] valor_atual,
    output wire               zerou
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
