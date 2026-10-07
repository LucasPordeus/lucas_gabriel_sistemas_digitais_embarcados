// tb_botao_pedestre: verifica que o pedido fica guardado depois que o
// botao e' solto, que limpa_solicitacao o apaga e que repique nao gera pedido.
`timescale 1ns/1ps
module tb_botao_pedestre;
    localparam integer N = 4;

    reg  clk, rst_n, botao_ativo, limpa;
    wire solicitacao;
    integer erros;

    botao_pedestre #(.N_CICLOS(N)) dut (
        .clk(clk), .rst_n(rst_n), .botao_ativo(botao_ativo),
        .limpa_solicitacao(limpa), .solicitacao_pedestre(solicitacao)
    );

    always #5 clk = ~clk;

    task espera(input integer n);
        integer i;
        for (i = 0; i < n; i = i + 1) begin @(posedge clk); #1; end
    endtask

    task confere(input esperado, input [8*48-1:0] descricao);
        if (solicitacao !== esperado) begin
            erros = erros + 1;
            $display("[FALHA] %0s (solicitacao=%b)", descricao, solicitacao);
        end else
            $display("[OK]    %0s", descricao);
    endtask

    initial begin
        $dumpfile("build/tb_botao_pedestre.vcd");
        $dumpvars(0, tb_botao_pedestre);
        clk = 0; rst_n = 0; botao_ativo = 0; limpa = 0; erros = 0;
        espera(2); rst_n = 1; espera(2);

        botao_ativo = 1; espera(1); botao_ativo = 0; espera(N + 4);
        confere(1'b0, "toque curto (repique) nao gera pedido");

        botao_ativo = 1; espera(N + 4); botao_ativo = 0; espera(N + 4);
        confere(1'b1, "pedido continua ativo apos soltar o botao");

        limpa = 1; espera(1); limpa = 0; espera(1);
        confere(1'b0, "limpa_solicitacao apaga o pedido");

        if (erros == 0) $display("RESULTADO: TODOS OS CASOS PASSARAM");
        else            $display("RESULTADO: %0d CASO(S) FALHARAM", erros);
        $finish;
    end
endmodule
