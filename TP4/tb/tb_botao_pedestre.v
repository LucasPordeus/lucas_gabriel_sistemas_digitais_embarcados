`timescale 1ns/1ps
module tb_botao_pedestre;
    localparam N = 4;
    reg clk, rst_n, botao_raw, limpa;
    wire botao_estavel, solicitacao;
    integer erros;

    botao_pedestre #(.N_CYCLES(N)) dut (
        .clk(clk), .rst_n(rst_n), .botao_raw(botao_raw),
        .limpa_solicitacao(limpa),
        .botao_estavel(botao_estavel), .solicitacao_pedestre(solicitacao)
    );

    always #5 clk = ~clk;

    task espera_ciclos(input integer n);
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) @(posedge clk);
        end
    endtask

    initial begin
        clk = 0; rst_n = 0; botao_raw = 0; limpa = 0; erros = 0;
        $dumpfile("tb_botao_pedestre.vcd");
        $dumpvars(0, tb_botao_pedestre);

        espera_ciclos(2); rst_n = 1; espera_ciclos(2);

        // pressiona rapido e solta -- deve travar a solicitacao (latch)
        botao_raw = 1; espera_ciclos(N + 2);
        botao_raw = 0; espera_ciclos(N + 2);

        if (solicitacao !== 1'b1) begin
            erros = erros + 1;
            $display("[FALHA] solicitacao nao foi travada apos pressionar o botao");
        end else begin
            $display("[OK]    solicitacao travada mesmo apos soltar o botao");
        end

        // limpa a solicitacao (simula FSM entrando na fase pedestre verde)
        limpa = 1; espera_ciclos(1); limpa = 0;

        if (solicitacao !== 1'b0) begin
            erros = erros + 1;
            $display("[FALHA] solicitacao nao foi limpa por limpa_solicitacao");
        end else begin
            $display("[OK]    solicitacao limpa corretamente");
        end

        if (erros == 0)
            $display("RESULTADO: TODOS OS CASOS PASSARAM (2/2)");
        else
            $display("RESULTADO: %0d CASO(S) FALHARAM", erros);
        $finish;
    end
endmodule
