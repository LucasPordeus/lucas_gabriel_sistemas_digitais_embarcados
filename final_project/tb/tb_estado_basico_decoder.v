// tb_estado_basico_decoder: verifica os 4 codigos de cor_carro, inclusive
// o codigo invalido 11, que deve acender so' o vermelho.
`timescale 1ns/1ps
module tb_estado_basico_decoder;
    reg  [1:0] cor_carro;
    wire       led_vermelho, led_amarelo, led_verde;
    reg  [2:0] esperado [0:3];   // {vermelho, amarelo, verde} esperado para cada codigo
    integer    i, erros;

    estado_basico_decoder dut (
        .cor_carro(cor_carro),
        .led_vermelho(led_vermelho), .led_amarelo(led_amarelo), .led_verde(led_verde)
    );

    initial begin
        $dumpfile("build/tb_estado_basico_decoder.vcd");
        $dumpvars(0, tb_estado_basico_decoder);
        esperado[0] = 3'b100; esperado[1] = 3'b010; esperado[2] = 3'b001; esperado[3] = 3'b100;
        erros = 0;

        // percorre os 4 codigos possiveis; termina apos o codigo 11
        for (i = 0; i < 4; i = i + 1) begin
            cor_carro = i; #1;
            if ({led_vermelho, led_amarelo, led_verde} !== esperado[i]) begin
                erros = erros + 1;
                $display("[FALHA] cor_carro=%b -> LEDs %b, esperado %b",
                         cor_carro, {led_vermelho, led_amarelo, led_verde}, esperado[i]);
            end else
                $display("[OK]    cor_carro=%b -> LEDs (V,A,Vd)=%b", cor_carro, esperado[i]);
        end

        if (erros == 0) $display("RESULTADO: TODOS OS CASOS PASSARAM");
        else            $display("RESULTADO: %0d CASO(S) FALHARAM", erros);
        $finish;
    end
endmodule
