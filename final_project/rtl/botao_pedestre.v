// botao_pedestre: le o botao de travessia, filtra com debounce e guarda o
// pedido (latch) ate a FSM atender. O pedido continua ativo mesmo depois
// que o botao e' solto, e so' e' apagado por limpa_solicitacao, que a
// fsm_semaforo gera ao fim da fase de pedestre.
//
// Parametro:
//   N_CICLOS - ciclos de estabilidade exigidos pelo debounce
// Portas:
//   botao_ativo          - botao ja convertido para ativo em ALTO (1 = apertado)
//   limpa_solicitacao    - 1 ciclo em 1: apaga o pedido (vem da FSM)
//   solicitacao_pedestre - 1 enquanto ha pedido de travessia pendente
module botao_pedestre #(
    parameter integer N_CICLOS = 540_000
) (
    input  wire clk,
    input  wire rst_n,
    input  wire botao_ativo,
    input  wire limpa_solicitacao,
    output reg  solicitacao_pedestre
);
    wire botao_estavel;      // botao filtrado (1 enquanto apertado)
    reg  estavel_ant;        // botao_estavel no ciclo anterior
    wire pressionado_pulso;  // 1 ciclo em 1 no instante em que o botao e' apertado

    debounce #(.N_CICLOS(N_CICLOS)) u_debounce (
        .clk(clk), .rst_n(rst_n),
        .entrada(botao_ativo), .saida(botao_estavel)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            estavel_ant <= 1'b0;
        else
            estavel_ant <= botao_estavel;
    end

    assign pressionado_pulso = botao_estavel & ~estavel_ant;

    // limpa tem prioridade: um aperto no mesmo ciclo do fim da fase de
    // pedestre e' descartado (a travessia acabou de acontecer)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            solicitacao_pedestre <= 1'b0;
        else if (limpa_solicitacao)
            solicitacao_pedestre <= 1'b0;
        else if (pressionado_pulso)
            solicitacao_pedestre <= 1'b1;
    end
endmodule
