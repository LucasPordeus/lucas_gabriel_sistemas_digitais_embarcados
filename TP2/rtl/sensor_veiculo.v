// sensor_veiculo: encapsula o debounce do sensor de veiculos (sensor de
// obstaculo reflexivo infravermelho -- saida digital direta, sem trigger/echo,
// compativel com 3,3V) e gera um pulso de 1 ciclo a cada deteccao (borda de
// subida do sinal filtrado), usado para contagem.
module sensor_veiculo #(
    parameter N_CYCLES = 8
) (
    input  wire clk,
    input  wire rst_n,
    input  wire sensor_raw,
    output wire sensor_estavel,
    output wire veiculo_pulso     // pulso de 1 ciclo por veiculo detectado
);
    reg estavel_ant;

    debounce #(.N_CYCLES(N_CYCLES)) u_debounce (
        .clk(clk), .rst_n(rst_n),
        .in_raw(sensor_raw), .out_stable(sensor_estavel)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            estavel_ant <= 1'b0;
        else
            estavel_ant <= sensor_estavel;
    end

    assign veiculo_pulso = sensor_estavel & ~estavel_ant; // deteccao de borda de subida
endmodule
