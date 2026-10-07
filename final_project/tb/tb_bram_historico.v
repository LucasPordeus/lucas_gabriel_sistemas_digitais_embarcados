// tb_bram_historico: grava 6 amostras, confere o avanco do ponteiro e le
// cada posicao de volta (leitura sincrona, 1 ciclo de atraso).
`timescale 1ns/1ps
module tb_bram_historico;
    reg        clk, rst_n, escreve;
    reg  [7:0] dado_escrita, endereco_leitura;
    wire [7:0] dado_leitura, ponteiro_escrita;
    integer i, erros;

    bram_historico dut (
        .clk(clk), .rst_n(rst_n), .escreve(escreve),
        .dado_escrita(dado_escrita), .endereco_leitura(endereco_leitura),
        .dado_leitura(dado_leitura), .ponteiro_escrita(ponteiro_escrita)
    );

    always #5 clk = ~clk;

    task espera(input integer n);
        integer j;
        for (j = 0; j < n; j = j + 1) begin @(posedge clk); #1; end
    endtask

    initial begin
        $dumpfile("build/tb_bram_historico.vcd");
        $dumpvars(0, tb_bram_historico);
        clk = 0; rst_n = 0; escreve = 0; dado_escrita = 0; endereco_leitura = 0; erros = 0;
        espera(2); rst_n = 1; espera(1);

        // grava 10, 20, ..., 60 nas posicoes 0..5; termina apos a 6a escrita
        for (i = 0; i < 6; i = i + 1) begin
            dado_escrita = 10 * (i + 1); escreve = 1; espera(1);
        end
        escreve = 0;

        if (ponteiro_escrita !== 8'd6) begin
            erros = erros + 1;
            $display("[FALHA] ponteiro=%0d, esperado 6", ponteiro_escrita);
        end else
            $display("[OK]    ponteiro avancou para 6");

        // le de volta cada posicao; termina apos ler a posicao 5
        for (i = 0; i < 6; i = i + 1) begin
            endereco_leitura = i; espera(1);
            if (dado_leitura !== 10 * (i + 1)) begin
                erros = erros + 1;
                $display("[FALHA] memoria[%0d]=%0d, esperado %0d", i, dado_leitura, 10 * (i + 1));
            end else
                $display("[OK]    memoria[%0d]=%0d", i, dado_leitura);
        end

        if (erros == 0) $display("RESULTADO: TODOS OS CASOS PASSARAM");
        else            $display("RESULTADO: %0d CASO(S) FALHARAM", erros);
        $finish;
    end
endmodule
