// Testbench do media_movel_dsp: preenche a janela de 5 amostras, confere
// a media calculada e a classificacao de nivel_fluxo contra os limiares.
`timescale 1ns/1ps
module tb_media_movel_dsp;
    reg clk, rst_n, nova_amostra;
    reg [7:0] amostra;
    reg [5:0] limiar_baixo, limiar_alto;
    wire [7:0] media;
    wire [1:0] nivel_fluxo;
    integer erros;

    media_movel_dsp dut (
        .clk(clk), .rst_n(rst_n), .nova_amostra(nova_amostra), .amostra(amostra),
        .limiar_baixo(limiar_baixo), .limiar_alto(limiar_alto),
        .media(media), .nivel_fluxo(nivel_fluxo)
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

    task envia_amostra(input [7:0] v);
        begin
            amostra = v;
            nova_amostra = 1;
            espera_ciclos(1);
            nova_amostra = 0;
            espera_ciclos(1);
        end
    endtask

    initial begin
        clk = 0; rst_n = 0; nova_amostra = 0; amostra = 0; erros = 0;
        limiar_baixo = 15; limiar_alto = 25;
        $dumpfile("tb_media_movel_dsp.vcd");
        $dumpvars(0, tb_media_movel_dsp);

        espera_ciclos(2); rst_n = 1; espera_ciclos(1);

        // preenche a janela com 5 amostras de valor 10 -> media esperada = 10
        envia_amostra(10); envia_amostra(10); envia_amostra(10);
        envia_amostra(10); envia_amostra(10);

        if (media !== 8'd10) begin
            erros = erros + 1;
            $display("[FALHA] media=%0d, esperado 10 (janela de 5x10)", media);
        end else $display("[OK]    media=10 com janela de 5 amostras iguais a 10");

        if (nivel_fluxo !== 2'b00) begin
            erros = erros + 1;
            $display("[FALHA] nivel_fluxo=%b, esperado BAIXO (00) com media=10<=15", nivel_fluxo);
        end else $display("[OK]    nivel_fluxo=BAIXO conforme limiar_baixo=15");

        // entra uma amostra alta (60), saindo o 10 mais antigo -> soma=100, media=20
        envia_amostra(60);
        if (media !== 8'd20) begin
            erros = erros + 1;
            $display("[FALHA] media=%0d, esperado 20 apos nova amostra 60", media);
        end else $display("[OK]    media=20 apos deslizar a janela com nova amostra 60");

        if (nivel_fluxo !== 2'b01) begin
            erros = erros + 1;
            $display("[FALHA] nivel_fluxo=%b, esperado MEDIO (01) com 15<media=20<=25", nivel_fluxo);
        end else $display("[OK]    nivel_fluxo=MEDIO conforme limiares");

        if (erros == 0)
            $display("RESULTADO: TODOS OS CASOS PASSARAM (4/4)");
        else
            $display("RESULTADO: %0d CASO(S) FALHARAM", erros);
        $finish;
    end
endmodule
