`timescale 1ns/1ps
module tb_contador_tempo;
    localparam W = 8;
    reg clk, rst_n, carrega, habilita;
    reg [W-1:0] valor_inicial;
    wire [W-1:0] valor_atual;
    wire zerou;
    integer erros;

    contador_tempo #(.LARGURA(W)) dut (
        .clk(clk), .rst_n(rst_n), .carrega(carrega), .habilita(habilita),
        .valor_inicial(valor_inicial), .valor_atual(valor_atual), .zerou(zerou)
    );

    always #5 clk = ~clk;

    task espera_ciclos(input integer n);
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) @(posedge clk);
        end
    endtask

    initial begin
        clk = 0; rst_n = 0; carrega = 0; habilita = 0; valor_inicial = 0; erros = 0;
        $dumpfile("tb_contador_tempo.vcd");
        $dumpvars(0, tb_contador_tempo);

        espera_ciclos(2); rst_n = 1; espera_ciclos(1);

        valor_inicial = 5; carrega = 1; espera_ciclos(1); carrega = 0;
        if (valor_atual !== 5) begin
            erros = erros + 1;
            $display("[FALHA] carga nao funcionou: valor_atual=%0d (esperado 5)", valor_atual);
        end else $display("[OK]    carga do valor inicial (5) funcionou");

        habilita = 1;
        espera_ciclos(5);
        if (zerou !== 1'b1) begin
            erros = erros + 1;
            $display("[FALHA] contador nao zerou apos 5 ciclos habilitado (valor_atual=%0d)", valor_atual);
        end else $display("[OK]    contador zerou apos 5 ciclos, como esperado");

        espera_ciclos(3);
        if (valor_atual !== 0) begin
            erros = erros + 1;
            $display("[FALHA] contador nao deveria decrementar abaixo de zero (valor_atual=%0d)", valor_atual);
        end else $display("[OK]    contador satura em zero corretamente");

        if (erros == 0)
            $display("RESULTADO: TODOS OS CASOS PASSARAM (3/3)");
        else
            $display("RESULTADO: %0d CASO(S) FALHARAM", erros);
        $finish;
    end
endmodule
