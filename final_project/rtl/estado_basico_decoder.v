// estado_basico_decoder: converte a cor dos carros (2 bits, vinda da
// fsm_semaforo) nos 3 LEDs do semaforo de veiculos. Puramente combinacional.
//
// Portas:
//   cor_carro    - 00 = vermelho, 01 = amarelo, 10 = verde, 11 = invalido
//   led_vermelho, led_amarelo, led_verde - 1 = LED aceso
// O codigo invalido 11 acende o vermelho (falha segura).
module estado_basico_decoder (
    input  wire [1:0] cor_carro,
    output wire       led_vermelho,
    output wire       led_amarelo,
    output wire       led_verde
);
    assign led_vermelho = (cor_carro == 2'b00) || (cor_carro == 2'b11);
    assign led_amarelo  = (cor_carro == 2'b01);
    assign led_verde    = (cor_carro == 2'b10);
endmodule
