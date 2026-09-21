// protocolo_serial: interface serial sincrona ARM<->FPGA, estilo SPI
// simplificado (CPOL=0/CPHA=0), com telemetria bidirecional por quadro
// de 8 bits.
//
// Sinais:
//   sclk  (entrada, gerado pelo ARM)  -- clock serial da transferencia
//   cs_n  (entrada, gerado pelo ARM)  -- chip-select ativo em nivel baixo;
//                                        tambem funciona como handshake de
//                                        inicio/fim de quadro (frame)
//   mosi  (entrada)                   -- ARM -> FPGA: byte de comando
//   miso  (saida, high-Z quando cs_n=1) -- FPGA -> ARM: byte de telemetria
//                                        (fase do semaforo + contagem
//                                        regressiva -- ver formato abaixo)
//   busy  (saida)                     -- pulsa por 1 ciclo de "clk" ao fim
//                                        de cada quadro completo (8 bits),
//                                        sinalizando que o comando foi
//                                        aplicado e a telemetria enviada
//
// Formato do comando (mosi, MSB primeiro): identico ao protocolo_paralelo
//   [7:6]=opcode  [5:0]=valor
// Formato da telemetria (miso, MSB primeiro) -- para o
// log de countdown em tempo real da Raspberry Pi:
//   [7:6]=fase_carro_atual (00=vermelho/pedestre-verde, 01=amarelo,
//         10=verde -- espelha "estado_carro" da fsm_semaforo)
//   [5:0]=contagem_regressiva (0-63, ciclos restantes na fase corrente,
//         vindo direto do contador da fsm_semaforo -- e' o valor que a
//         Raspberry Pi usa pra mostrar "fecha em Ns")
module protocolo_serial (
    input  wire clk,          // clock interno da FPGA (27 MHz)
    input  wire rst_n,
    input  wire sclk,         // clock serial (gerado pelo ARM, ja sincronizado a "clk")
    input  wire cs_n,
    input  wire mosi,
    input  wire [1:0] fase_carro_atual,
    input  wire [5:0] contagem_regressiva,
    output wire miso,
    output reg  busy,
    output reg  [7:0] comando_recebido,
    output reg        comando_valido    // pulsa 1 ciclo quando um novo comando chegou
);
    reg [2:0] bit_cnt;
    reg [7:0] shift_in;
    reg [7:0] shift_out;
    reg       sclk_ant;
    wire      sclk_borda_subida;
    reg       miso_reg;

    assign sclk_borda_subida = sclk & ~sclk_ant;
    // OE (output-enable) do pino MISO: so' dirige o barramento durante o
    // quadro (cs_n=0); em repouso fica em alta impedancia (Hi-Z), permitindo
    // que o mesmo pino fisico seja compartilhado com outros perifericos.
    assign miso = cs_n ? 1'bz : miso_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_ant          <= 1'b0;
            bit_cnt            <= 3'd0;
            shift_in           <= 8'd0;
            shift_out          <= 8'd0;
            miso_reg           <= 1'b0;
            busy               <= 1'b0;
            comando_recebido   <= 8'd0;
            comando_valido     <= 1'b0;
        end else begin
            sclk_ant       <= sclk;
            comando_valido <= 1'b0;
            busy           <= 1'b0;

            if (cs_n) begin
                // fora do quadro: prepara o proximo byte de telemetria a
                // ser transmitido assim que cs_n descer
                bit_cnt   <= 3'd0;
                shift_out <= {fase_carro_atual, contagem_regressiva};
                miso_reg  <= fase_carro_atual[1]; // bit mais significativo do byte de telemetria
            end else if (sclk_borda_subida) begin
                // desloca 1 bit para dentro (mosi) e 1 bit para fora (miso)
                shift_in  <= {shift_in[6:0], mosi};
                shift_out <= {shift_out[6:0], 1'b0};
                miso_reg  <= shift_out[6];
                bit_cnt   <= bit_cnt + 3'd1;

                if (bit_cnt == 3'd7) begin
                    comando_recebido <= {shift_in[6:0], mosi};
                    comando_valido   <= 1'b1;
                    busy             <= 1'b1;
                end
            end
        end
    end
endmodule
