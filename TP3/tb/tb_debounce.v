// Testbench do debounce: aplica ruido (varias transicoes rapidas) e depois
// um nivel estavel, conferindo que out_stable so acompanha a entrada apos
// N_CYCLES ciclos consecutivos sem transicao.
`timescale 1ns/1ps

module tb_debounce;
    localparam N = 4;
    reg clk, rst_n, in_raw;
    wire out_stable;
    integer erros;

    debounce #(.N_CYCLES(N)) dut (
        .clk(clk), .rst_n(rst_n), .in_raw(in_raw), .out_stable(out_stable)
    );

    always #5 clk = ~clk; // periodo de 10ns

    task espera_ciclos(input integer n);
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) @(posedge clk);
        end
    endtask

    initial begin
        clk = 0; rst_n = 0; in_raw = 0; erros = 0;
        $dumpfile("tb_debounce.vcd");
        $dumpvars(0, tb_debounce);

        espera_ciclos(2);
        rst_n = 1;
        espera_ciclos(2);

        // Caso 1: ruido de "bouncing" -- varias transicoes rapidas, nao deve estabilizar
        in_raw = 1; espera_ciclos(1);
        in_raw = 0; espera_ciclos(1);
        in_raw = 1; espera_ciclos(1);
        in_raw = 0; espera_ciclos(1);
        if (out_stable !== 1'b0) begin
            erros = erros + 1;
            $display("[FALHA] ruido de bouncing produziu out_stable=1 antes da hora");
        end else begin
            $display("[OK]    ruido de bouncing ignorado (out_stable ainda em 0)");
        end

        // Caso 2: nivel estavel por N_CYCLES -> deve propagar para out_stable
        in_raw = 1;
        espera_ciclos(N + 1);
        if (out_stable !== 1'b1) begin
            erros = erros + 1;
            $display("[FALHA] nivel estavel em 1 nao propagou para out_stable");
        end else begin
            $display("[OK]    nivel estavel em 1 propagou para out_stable apos %0d ciclos", N);
        end

        // Caso 3: volta a 0 e permanece estavel -> out_stable deve acompanhar
        in_raw = 0;
        espera_ciclos(N + 1);
        if (out_stable !== 1'b0) begin
            erros = erros + 1;
            $display("[FALHA] nivel estavel em 0 nao propagou para out_stable");
        end else begin
            $display("[OK]    nivel estavel em 0 propagou para out_stable apos %0d ciclos", N);
        end

        if (erros == 0)
            $display("RESULTADO: TODOS OS CASOS PASSARAM (3/3)");
        else
            $display("RESULTADO: %0d CASO(S) FALHARAM", erros);

        $finish;
    end
endmodule
