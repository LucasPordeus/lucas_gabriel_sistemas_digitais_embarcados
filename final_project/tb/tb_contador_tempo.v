// tb_contador_tempo: verifica carga, decremento so' com habilita, parada
// em zero e prioridade de carrega sobre habilita.
`timescale 1ns/1ps
module tb_contador_tempo;
    reg        clk, rst_n, carrega, habilita;
    reg  [5:0] valor_inicial;
    wire [5:0] valor_atual;
    wire       zerou;
    integer erros;

    contador_tempo #(.LARGURA(6)) dut (
        .clk(clk), .rst_n(rst_n), .carrega(carrega), .habilita(habilita),
        .valor_inicial(valor_inicial), .valor_atual(valor_atual), .zerou(zerou)
    );

    always #5 clk = ~clk;

    task espera(input integer n);
        integer i;
        for (i = 0; i < n; i = i + 1) begin @(posedge clk); #1; end
    endtask

    task confere(input [5:0] esperado, input [8*40-1:0] descricao);
        if (valor_atual !== esperado || zerou !== (esperado == 0)) begin
            erros = erros + 1;
            $display("[FALHA] %0s (valor=%0d zerou=%b)", descricao, valor_atual, zerou);
        end else
            $display("[OK]    %0s (valor=%0d)", descricao, valor_atual);
    endtask

    initial begin
        $dumpfile("build/tb_contador_tempo.vcd");
        $dumpvars(0, tb_contador_tempo);
        clk = 0; rst_n = 0; carrega = 0; habilita = 0; valor_inicial = 6'd3; erros = 0;
        espera(2); rst_n = 1; espera(1);
        confere(6'd0, "zerado apos reset");

        carrega = 1; espera(1); carrega = 0;
        confere(6'd3, "carrega valor_inicial");

        espera(4);
        confere(6'd3, "sem habilita, nao decrementa");

        habilita = 1; espera(2);
        confere(6'd1, "decrementa 1 por ciclo habilitado");
        espera(3);
        confere(6'd0, "para em zero");

        carrega = 1; espera(1); carrega = 0; habilita = 0;
        confere(6'd3, "carrega tem prioridade sobre habilita");

        if (erros == 0) $display("RESULTADO: TODOS OS CASOS PASSARAM");
        else            $display("RESULTADO: %0d CASO(S) FALHARAM", erros);
        $finish;
    end
endmodule
