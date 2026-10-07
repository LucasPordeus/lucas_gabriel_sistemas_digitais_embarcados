// sensor_veiculo: le o sensor IR de obstaculo (tipo FC-51) que detecta
// veiculos. Filtra o sinal com debounce e gera 1 pulso por veiculo (borda
// de subida da deteccao). Os pulsos alimentam a contagem de fluxo em
// top_semaforo.
//
// Parametro:
//   N_CICLOS - ciclos de estabilidade exigidos pelo debounce
// Portas:
//   sensor_ativo  - saida do sensor ja convertida para ativo em ALTO
//                   (1 = obstaculo na frente do sensor)
//   veiculo_pulso - 1 ciclo em 1 a cada nova deteccao de veiculo
module sensor_veiculo #(
    parameter integer N_CICLOS = 135_000
) (
    input  wire clk,
    input  wire rst_n,
    input  wire sensor_ativo,
    output wire veiculo_pulso
);
    wire sensor_estavel;   // deteccao filtrada (1 enquanto ha veiculo na frente do sensor)
    reg  estavel_ant;      // sensor_estavel no ciclo anterior, para detectar a borda

    debounce #(.N_CICLOS(N_CICLOS)) u_debounce (
        .clk(clk), .rst_n(rst_n),
        .entrada(sensor_ativo), .saida(sensor_estavel)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            estavel_ant <= 1'b0;
        else
            estavel_ant <= sensor_estavel;
    end

    assign veiculo_pulso = sensor_estavel & ~estavel_ant;
endmodule
