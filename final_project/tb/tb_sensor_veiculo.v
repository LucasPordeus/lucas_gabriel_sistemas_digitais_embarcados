// tb_sensor_veiculo: verifica que cada passagem de veiculo gera exatamente
// 1 pulso e que repiques do sensor nao geram pulsos extras.
`timescale 1ns/1ps
module tb_sensor_veiculo;
    localparam integer N = 4;

    reg  clk, rst_n, sensor_ativo;
    wire veiculo_pulso;
    integer pulsos;   // pulsos contados desde o ultimo zeramento
    integer erros;

    sensor_veiculo #(.N_CICLOS(N)) dut (
        .clk(clk), .rst_n(rst_n), .sensor_ativo(sensor_ativo), .veiculo_pulso(veiculo_pulso)
    );

    always #5 clk = ~clk;
    always @(posedge clk) if (veiculo_pulso) pulsos = pulsos + 1;

    task espera(input integer n);
        integer i;
        for (i = 0; i < n; i = i + 1) begin @(posedge clk); #1; end
    endtask

    // um veiculo: com repique na chegada, fica na frente do sensor e sai
    task passa_veiculo;
        begin
            sensor_ativo = 1; espera(1); sensor_ativo = 0; espera(1);
            sensor_ativo = 1; espera(N + 6);
            sensor_ativo = 0; espera(N + 6);
        end
    endtask

    task confere(input integer esperado, input [8*40-1:0] descricao);
        if (pulsos != esperado) begin
            erros = erros + 1;
            $display("[FALHA] %0s (pulsos=%0d, esperado=%0d)", descricao, pulsos, esperado);
        end else
            $display("[OK]    %0s (%0d pulsos)", descricao, pulsos);
    endtask

    initial begin
        $dumpfile("build/tb_sensor_veiculo.vcd");
        $dumpvars(0, tb_sensor_veiculo);
        clk = 0; rst_n = 0; sensor_ativo = 0; erros = 0; pulsos = 0;
        espera(2); rst_n = 1; espera(2);

        passa_veiculo;
        confere(1, "1 veiculo com repique = 1 pulso");

        pulsos = 0;
        repeat (3) passa_veiculo;
        confere(3, "3 veiculos = 3 pulsos");

        if (erros == 0) $display("RESULTADO: TODOS OS CASOS PASSARAM");
        else            $display("RESULTADO: %0d CASO(S) FALHARAM", erros);
        $finish;
    end
endmodule
