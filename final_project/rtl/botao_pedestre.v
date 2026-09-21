// botao_pedestre: debounce do botao de pedestre + latch de solicitacao.
// A solicitacao fica travada (mesmo apos soltar o botao) ate ser liberada
// externamente por "limpa_solicitacao" (fsm_semaforo usa esse sinal ao
// entrar na fase de pedestre verde).
module botao_pedestre #(
    parameter N_CYCLES = 8
) (
    input  wire clk,
    input  wire rst_n,
    input  wire botao_raw,
    input  wire limpa_solicitacao,
    output wire botao_estavel,
    output reg  solicitacao_pedestre
);
    wire pressionado_pulso;
    reg  estavel_ant;

    debounce #(.N_CYCLES(N_CYCLES)) u_debounce (
        .clk(clk), .rst_n(rst_n),
        .in_raw(botao_raw), .out_stable(botao_estavel)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            estavel_ant <= 1'b0;
        else
            estavel_ant <= botao_estavel;
    end

    assign pressionado_pulso = botao_estavel & ~estavel_ant;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            solicitacao_pedestre <= 1'b0;
        else if (limpa_solicitacao)
            solicitacao_pedestre <= 1'b0;
        else if (pressionado_pulso)
            solicitacao_pedestre <= 1'b1;
    end
endmodule
