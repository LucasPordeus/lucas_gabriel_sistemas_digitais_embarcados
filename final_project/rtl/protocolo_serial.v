// protocolo_serial: envia a telemetria do semaforo para a Raspberry Pi por
// um link serial sincrono estilo SPI (modo 0, MSB primeiro), somente
// leitura. A Raspberry e' o mestre: gera sclk e cs_n; a FPGA so' responde
// em miso. Nenhum dado vai da Raspberry para a FPGA.
//
// Quadro (16 bits, delimitado por cs_n em nivel baixo):
//   - enquanto cs_n = 1, o registrador acompanha "quadro" a cada ciclo;
//   - quando cs_n desce, o valor fica congelado (todos os campos sao do
//     mesmo instante) e miso ja mostra o bit 15;
//   - a cada borda de SUBIDA de sclk, miso avanca para o proximo bit.
//     A Raspberry le miso ANTES de cada subida (16 leituras).
// O formato dos campos e' montado em top_semaforo.
//
// sclk e cs_n vem de outra placa (assincronos ao clk): passam por 2
// flip-flops de sincronizacao. Por isso cada nivel de sclk precisa durar
// mais que ~4 ciclos de clk (150 ns); a Raspberry usa dezenas de us.
//
// Portas:
//   sclk, cs_n - clock serial e selecao de quadro, vindos da Raspberry
//   quadro     - 16 bits de telemetria do instante atual
//   miso       - bit atual do quadro para a Raspberry
module protocolo_serial (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sclk,
    input  wire        cs_n,
    input  wire [15:0] quadro,
    output wire        miso
);
    reg [2:0]  sclk_sinc;     // [1:0] sincronizam sclk; [2] guarda o valor anterior para achar a borda
    reg [1:0]  cs_n_sinc;     // cs_n sincronizado em cs_n_sinc[1]
    reg [15:0] deslocamento;  // quadro sendo enviado; o bit 15 esta em miso
    wire       sclk_subiu;    // 1 ciclo em 1 na borda de subida de sclk

    assign sclk_subiu = sclk_sinc[1] & ~sclk_sinc[2];
    assign miso       = deslocamento[15];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_sinc    <= 3'b000;
            cs_n_sinc    <= 2'b11;
            deslocamento <= 16'd0;
        end else begin
            sclk_sinc <= {sclk_sinc[1:0], sclk};
            cs_n_sinc <= {cs_n_sinc[0], cs_n};

            if (cs_n_sinc[1])
                deslocamento <= quadro;                      // fora do quadro: fotografa o estado atual
            else if (sclk_subiu)
                deslocamento <= {deslocamento[14:0], 1'b0};  // dentro do quadro: proximo bit
        end
    end
endmodule
