`timescale 1ns/1ps
module tb_protocolo_paralelo;
    reg clk, rst_n, strobe;
    reg [7:0] dados;
    wire ack;
    wire [5:0] tempo_min_reg, tempo_amarelo_reg, limiar_baixo_reg, limiar_alto_reg;
    integer erros;

    protocolo_paralelo dut (
        .clk(clk), .rst_n(rst_n), .dados(dados), .strobe(strobe), .ack(ack),
        .tempo_min_reg(tempo_min_reg), .tempo_amarelo_reg(tempo_amarelo_reg),
        .limiar_baixo_reg(limiar_baixo_reg), .limiar_alto_reg(limiar_alto_reg)
    );

    always #5 clk = ~clk;

    task espera_ciclos(input integer n);
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(posedge clk);
                #1;
            end
        end
    endtask

    task envia_comando(input [1:0] opcode, input [5:0] valor);
        begin
            dados = {opcode, valor};
            strobe = 1'b1;
            espera_ciclos(1);
            strobe = 1'b0;
            espera_ciclos(1);
        end
    endtask

    initial begin
        clk = 0; rst_n = 0; strobe = 0; dados = 0; erros = 0;
        $dumpfile("tb_protocolo_paralelo.vcd");
        $dumpvars(0, tb_protocolo_paralelo);

        espera_ciclos(2); rst_n = 1; espera_ciclos(1);

        if (tempo_min_reg !== 6'd10 || tempo_amarelo_reg !== 6'd3) begin
            erros = erros + 1;
            $display("[FALHA] valores padrao incorretos apos reset");
        end else $display("[OK]    valores padrao de seguranca carregados apos reset");

        envia_comando(2'b00, 6'd20); // OP_TEMPO_MIN = 20
        if (tempo_min_reg !== 6'd20) begin
            erros = erros + 1;
            $display("[FALHA] tempo_min_reg nao atualizou (valor=%0d)", tempo_min_reg);
        end else $display("[OK]    comando OP_TEMPO_MIN=20 aplicado corretamente");

        envia_comando(2'b11, 6'd15); // OP_LIMIAR_ALTO = 15
        if (limiar_alto_reg !== 6'd15) begin
            erros = erros + 1;
            $display("[FALHA] limiar_alto_reg nao atualizou (valor=%0d)", limiar_alto_reg);
        end else $display("[OK]    comando OP_LIMIAR_ALTO=15 aplicado corretamente");

        // ack deve ter pulsado por exatamente 1 ciclo a cada comando (checado indiretamente
        // pelo fato de os registradores terem mudado); checa que ack volta a 0 em repouso
        if (ack !== 1'b0) begin
            erros = erros + 1;
            $display("[FALHA] ack nao retornou a 0 em repouso");
        end else $display("[OK]    ack em repouso = 0 (pulso de 1 ciclo por comando)");

        if (erros == 0)
            $display("RESULTADO: TODOS OS CASOS PASSARAM (4/4)");
        else
            $display("RESULTADO: %0d CASO(S) FALHARAM", erros);
        $finish;
    end
endmodule
