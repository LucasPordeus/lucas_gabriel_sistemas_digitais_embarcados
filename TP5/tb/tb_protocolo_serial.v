`timescale 1ns/1ps
module tb_protocolo_serial;
    reg clk, rst_n, sclk, cs_n, mosi;
    reg [1:0] fase_carro_atual;
    reg [5:0] contagem_regressiva;
    wire miso, busy;
    wire [7:0] comando_recebido;
    wire comando_valido;
    integer erros;

    protocolo_serial dut (
        .clk(clk), .rst_n(rst_n), .sclk(sclk), .cs_n(cs_n), .mosi(mosi),
        .fase_carro_atual(fase_carro_atual), .contagem_regressiva(contagem_regressiva),
        .miso(miso), .busy(busy),
        .comando_recebido(comando_recebido), .comando_valido(comando_valido)
    );

    always #5 clk = ~clk;   // clock interno da FPGA: periodo 10ns (rapido)

    task espera_clk(input integer n);
        integer j;
        begin
            for (j = 0; j < n; j = j + 1) begin
                @(posedge clk);
                #1;
            end
        end
    endtask

    // gera 1 pulso de sclk (0->1->0), com varios ciclos de "clk" internos
    // entre as bordas, simulando um sclk bem mais lento que o clock interno
    task pulso_sclk(input valor_mosi);
        begin
            mosi = valor_mosi;
            espera_clk(2);
            sclk = 1'b1;
            espera_clk(2);   // da tempo para o clk interno amostrar a borda de subida
            sclk = 1'b0;
            espera_clk(2);
        end
    endtask

    integer k;
    reg [7:0] comando_enviado;
    reg [7:0] telemetria_esperada;

    initial begin
        clk = 0; rst_n = 0; sclk = 0; cs_n = 1; mosi = 0;
        fase_carro_atual = 2'b01; contagem_regressiva = 6'b101010; // 42
        erros = 0;
        $dumpfile("tb_protocolo_serial.vcd");
        $dumpvars(0, tb_protocolo_serial);

        espera_clk(2); rst_n = 1; espera_clk(2);

        // ---- Caso 1: MISO em alta impedancia fora do quadro (cs_n=1) ----
        if (miso !== 1'bz) begin
            erros = erros + 1;
            $display("[FALHA] miso nao esta em alta impedancia com cs_n=1 (miso=%b)", miso);
        end else $display("[OK]    miso em alta impedancia (Hi-Z) fora do quadro");

        // ---- inicia o quadro (handshake: cs_n desce) ----
        cs_n = 0;
        espera_clk(2);

        telemetria_esperada = {fase_carro_atual, contagem_regressiva}; // 0b01101010

        if (miso !== telemetria_esperada[7]) begin
            erros = erros + 1;
            $display("[FALHA] MSB da telemetria incorreto logo apos cs_n=0 (miso=%b esperado=%b)",
                      miso, telemetria_esperada[7]);
        end else $display("[OK]    MISO ja apresenta o MSB da telemetria ao iniciar o quadro (handshake)");

        // ---- envia o comando (opcode=10 valor=000101 -> 0x85) ----
        comando_enviado = 8'b10000101;
        for (k = 7; k >= 0; k = k - 1)
            pulso_sclk(comando_enviado[k]);

        espera_clk(1);

        if (comando_recebido !== comando_enviado) begin
            erros = erros + 1;
            $display("[FALHA] comando_recebido=0x%h, esperado 0x%h", comando_recebido, comando_enviado);
        end else $display("[OK]    comando_recebido=0x%h corretamente apos 8 pulsos de sclk", comando_recebido);

        // ---- fim do quadro (handshake: cs_n sobe) ----
        cs_n = 1;
        espera_clk(1);
        if (miso !== 1'bz) begin
            erros = erros + 1;
            $display("[FALHA] miso nao voltou a alta impedancia ao fim do quadro");
        end else $display("[OK]    miso volta a alta impedancia ao fim do quadro (handshake completo)");

        if (erros == 0)
            $display("RESULTADO: TODOS OS CASOS PASSARAM (4/4)");
        else
            $display("RESULTADO: %0d CASO(S) FALHARAM", erros);
        $finish;
    end
endmodule
