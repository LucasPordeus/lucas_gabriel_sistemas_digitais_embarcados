// Testbench do bram_historico: escreve 4 amostras conhecidas e confere
// avanco do ponteiro circular e leitura sincrona correta de cada endereco.
`timescale 1ns/1ps
module tb_bram_historico;
    reg clk, rst_n, escreve;
    reg [7:0] dado_escrita, endereco_leitura;
    wire [7:0] dado_leitura, ponteiro_escrita;
    integer erros, i;

    bram_historico dut (
        .clk(clk), .rst_n(rst_n), .escreve(escreve),
        .dado_escrita(dado_escrita), .endereco_leitura(endereco_leitura),
        .dado_leitura(dado_leitura), .ponteiro_escrita(ponteiro_escrita)
    );

    always #5 clk = ~clk;

    task espera_ciclos(input integer n);
        integer j;
        begin
            for (j = 0; j < n; j = j + 1) begin
                @(posedge clk);
                #1;
            end
        end
    endtask

    initial begin
        clk = 0; rst_n = 0; escreve = 0; dado_escrita = 0; endereco_leitura = 0; erros = 0;
        $dumpfile("tb_bram_historico.vcd");
        $dumpvars(0, tb_bram_historico);

        espera_ciclos(2); rst_n = 1; espera_ciclos(1);

        // escreve 4 amostras conhecidas: 10, 20, 30, 40
        for (i = 0; i < 4; i = i + 1) begin
            dado_escrita = (i + 1) * 10;
            escreve = 1;
            espera_ciclos(1);
            escreve = 0;
            espera_ciclos(1);
        end

        if (ponteiro_escrita !== 8'd4) begin
            erros = erros + 1;
            $display("[FALHA] ponteiro_escrita=%0d, esperado 4", ponteiro_escrita);
        end else $display("[OK]    ponteiro_escrita avancou para 4 apos 4 escritas");

        for (i = 0; i < 4; i = i + 1) begin
            endereco_leitura = i;
            espera_ciclos(1); // leitura sincrona: 1 ciclo de latencia
            if (dado_leitura !== (i + 1) * 10) begin
                erros = erros + 1;
                $display("[FALHA] endereco %0d: lido %0d, esperado %0d", i, dado_leitura, (i+1)*10);
            end else begin
                $display("[OK]    endereco %0d: lido %0d corretamente", i, dado_leitura);
            end
        end

        if (erros == 0)
            $display("RESULTADO: TODOS OS CASOS PASSARAM (5/5)");
        else
            $display("RESULTADO: %0d CASO(S) FALHARAM", erros);
        $finish;
    end
endmodule
