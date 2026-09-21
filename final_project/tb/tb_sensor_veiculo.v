// Testbench do sensor_veiculo: gera ruido curto (ignorado) e dois sinais
// estaveis, confirmando exatamente 2 pulsos de deteccao.
`timescale 1ns/1ps
module tb_sensor_veiculo;
    localparam N = 4;
    reg clk, rst_n, sensor_raw;
    wire sensor_estavel, veiculo_pulso;
    integer erros, pulsos;

    sensor_veiculo #(.N_CYCLES(N)) dut (
        .clk(clk), .rst_n(rst_n), .sensor_raw(sensor_raw),
        .sensor_estavel(sensor_estavel), .veiculo_pulso(veiculo_pulso)
    );

    always #5 clk = ~clk;

    task espera_ciclos(input integer n);
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) @(posedge clk);
        end
    endtask

    always @(posedge clk)
        if (veiculo_pulso) pulsos = pulsos + 1;

    initial begin
        clk = 0; rst_n = 0; sensor_raw = 0; erros = 0; pulsos = 0;
        $dumpfile("tb_sensor_veiculo.vcd");
        $dumpvars(0, tb_sensor_veiculo);

        espera_ciclos(2); rst_n = 1; espera_ciclos(2);

        // ruido rapido, nao deve gerar pulso
        sensor_raw = 1; espera_ciclos(1);
        sensor_raw = 0; espera_ciclos(1);

        // veiculo 1: sinal estavel por N+1 ciclos
        sensor_raw = 1; espera_ciclos(N + 2);
        sensor_raw = 0; espera_ciclos(N + 2);

        // veiculo 2: outro sinal estavel
        sensor_raw = 1; espera_ciclos(N + 2);
        sensor_raw = 0; espera_ciclos(N + 2);

        if (pulsos == 2) begin
            $display("[OK]    2 veiculos detectados corretamente (pulsos=%0d)", pulsos);
        end else begin
            erros = erros + 1;
            $display("[FALHA] esperado 2 pulsos, obtido %0d", pulsos);
        end

        if (erros == 0)
            $display("RESULTADO: TODOS OS CASOS PASSARAM (1/1)");
        else
            $display("RESULTADO: %0d CASO(S) FALHARAM", erros);
        $finish;
    end
endmodule
