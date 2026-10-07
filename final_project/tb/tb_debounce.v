// tb_debounce: verifica que repiques curtos sao ignorados e que um nivel
// estavel por N_CICLOS ciclos chega a saida (nos dois sentidos).
`timescale 1ns/1ps
module tb_debounce;
    localparam integer N = 4;   // ciclos de estabilidade usados no teste

    reg  clk, rst_n, entrada;
    wire saida;
    integer erros;              // casos que falharam

    debounce #(.N_CICLOS(N)) dut (.clk(clk), .rst_n(rst_n), .entrada(entrada), .saida(saida));

    always #5 clk = ~clk;

    // espera n bordas de subida de clk (e 1 ns para os registradores assentarem)
    task espera(input integer n);
        integer i;
        for (i = 0; i < n; i = i + 1) begin @(posedge clk); #1; end
    endtask

    task confere(input esperado, input [8*48-1:0] descricao);
        if (saida !== esperado) begin
            erros = erros + 1;
            $display("[FALHA] %0s (saida=%b)", descricao, saida);
        end else
            $display("[OK]    %0s", descricao);
    endtask

    initial begin
        $dumpfile("build/tb_debounce.vcd");
        $dumpvars(0, tb_debounce);
        clk = 0; rst_n = 0; entrada = 0; erros = 0;
        espera(2); rst_n = 1; espera(2);

        // repique: alterna a cada ciclo, nunca fica estavel N ciclos
        entrada = 1; espera(1); entrada = 0; espera(1);
        entrada = 1; espera(2); entrada = 0; espera(1);
        espera(N + 3);
        confere(1'b0, "repique ignorado");

        // nivel estavel: chega a saida apos 2 (sincronizador) + N ciclos
        entrada = 1; espera(N + 1);
        confere(1'b0, "saida ainda nao muda antes de N + 2 ciclos");
        espera(2);
        confere(1'b1, "nivel 1 estavel chega a saida");

        entrada = 0; espera(N + 3);
        confere(1'b0, "nivel 0 estavel chega a saida");

        if (erros == 0) $display("RESULTADO: TODOS OS CASOS PASSARAM");
        else            $display("RESULTADO: %0d CASO(S) FALHARAM", erros);
        $finish;
    end
endmodule
