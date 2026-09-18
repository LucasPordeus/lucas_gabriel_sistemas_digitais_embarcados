// Testbench do estado_basico_decoder: percorre as 4 combinacoes possiveis
// de "estado" e confere led_vermelho/led_amarelo/led_verde.
`timescale 1ns/1ps

module tb_estado_basico_decoder;
    reg  [1:0] estado;
    wire       led_vermelho, led_amarelo, led_verde;
    integer    erros;

    estado_basico_decoder dut (
        .estado(estado),
        .led_vermelho(led_vermelho),
        .led_amarelo(led_amarelo),
        .led_verde(led_verde)
    );

    task check(input [1:0] est, input v, a, g);
    begin
        estado = est;
        #5;
        if (led_vermelho !== v || led_amarelo !== a || led_verde !== g) begin
            erros = erros + 1;
            $display("[FALHA] estado=%b -> V=%b A=%b G=%b (esperado V=%b A=%b G=%b)",
                      est, led_vermelho, led_amarelo, led_verde, v, a, g);
        end else begin
            $display("[OK]    estado=%b -> V=%b A=%b G=%b", est, led_vermelho, led_amarelo, led_verde);
        end
    end
    endtask

    initial begin
        erros = 0;
        $dumpfile("tb_estado_basico_decoder.vcd");
        $dumpvars(0, tb_estado_basico_decoder);

        check(2'b00, 1, 0, 0); // vermelho
        check(2'b01, 0, 1, 0); // amarelo
        check(2'b10, 0, 0, 1); // verde
        check(2'b11, 1, 0, 0); // invalido -> vermelho (seguranca)

        if (erros == 0)
            $display("RESULTADO: TODOS OS CASOS PASSARAM (4/4)");
        else
            $display("RESULTADO: %0d CASO(S) FALHARAM", erros);

        $finish;
    end
endmodule
