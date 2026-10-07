// tb_protocolo_serial: le quadros de 16 bits como a Raspberry Pi faz (le
// miso antes de cada subida de sclk) e confere que o valor lido e' o
// quadro do instante em que cs_n desceu, mesmo que "quadro" mude durante
// a transferencia.
`timescale 1ns/1ps
module tb_protocolo_serial;
    reg         clk, rst_n, sclk, cs_n;
    reg  [15:0] quadro;
    wire        miso;
    reg  [15:0] lido;    // quadro recebido pelo "mestre" do testbench
    integer     erros;

    protocolo_serial dut (
        .clk(clk), .rst_n(rst_n), .sclk(sclk), .cs_n(cs_n), .quadro(quadro), .miso(miso)
    );

    always #5 clk = ~clk;

    task espera(input integer n);
        integer i;
        for (i = 0; i < n; i = i + 1) begin @(posedge clk); #1; end
    endtask

    // transferencia completa; cada nivel de sclk dura 6 ciclos de clk
    task le_quadro(output [15:0] valor);
        integer b;
        begin
            cs_n = 0; espera(6);
            // 16 bits, MSB primeiro; termina apos o bit 0
            for (b = 15; b >= 0; b = b - 1) begin
                valor[b] = miso;
                sclk = 1; espera(6);
                sclk = 0; espera(6);
            end
            cs_n = 1; espera(6);
        end
    endtask

    task confere(input [15:0] esperado, input [8*48-1:0] descricao);
        if (lido !== esperado) begin
            erros = erros + 1;
            $display("[FALHA] %0s (lido=%h esperado=%h)", descricao, lido, esperado);
        end else
            $display("[OK]    %0s (%h)", descricao, lido);
    endtask

    initial begin
        $dumpfile("build/tb_protocolo_serial.vcd");
        $dumpvars(0, tb_protocolo_serial);
        clk = 0; rst_n = 0; sclk = 0; cs_n = 1; quadro = 16'hA9C5; erros = 0;
        espera(2); rst_n = 1; espera(4);

        le_quadro(lido);
        confere(16'hA9C5, "quadro lido bit a bit");

        quadro = 16'hA001; espera(4);
        le_quadro(lido);
        confere(16'hA001, "quadro atualizado entre transferencias");

        // muda o quadro no meio da transferencia: deve valer o valor antigo
        quadro = 16'hA5A5; espera(4);
        fork
            le_quadro(lido);
            begin espera(40); quadro = 16'hAFFF; end
        join
        confere(16'hA5A5, "quadro congelado durante a transferencia");

        if (erros == 0) $display("RESULTADO: TODOS OS CASOS PASSARAM");
        else            $display("RESULTADO: %0d CASO(S) FALHARAM", erros);
        $finish;
    end
endmodule
