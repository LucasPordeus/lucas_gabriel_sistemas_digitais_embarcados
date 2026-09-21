// estado_basico_decoder: decodificador combinacional puro. Mapeia um
// estado de 2 bits do semaforo de veiculos para os 3 LEDs correspondentes
// (vermelho, amarelo, verde).
module estado_basico_decoder (
    input  wire [1:0] estado,      // 00=vermelho 01=amarelo 10=verde 11=invalido
    output wire       led_vermelho,
    output wire       led_amarelo,
    output wire       led_verde
);
    // Logica puramente combinacional (sem clock, sem estado interno).
    // Estado invalido (11) forca vermelho por seguranca (ONF-08).
    assign led_vermelho = (estado == 2'b00) || (estado == 2'b11);
    assign led_amarelo  = (estado == 2'b01);
    assign led_verde    = (estado == 2'b10);
endmodule
