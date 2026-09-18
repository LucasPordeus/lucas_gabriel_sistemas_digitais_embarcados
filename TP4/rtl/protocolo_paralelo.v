// protocolo_paralelo: interface de comunicacao ARM->FPGA via barramento
// paralelo de 8 bits + linha de strobe, com linha de ack de confirmacao.
// Formato do comando (dados[7:0]):
//   dados[7:6] = opcode  (00=tempo_min 01=tempo_amarelo 10=limiar_baixo 11=limiar_alto)
//   dados[5:0] = valor   (0-63)
// A cada borda de subida de "strobe" (ja filtrada por debounce fora deste
// modulo, pois strobe e' gerado digitalmente pela Raspberry Pi via GPIO),
// o valor e' decodificado e latched no registrador correspondente, e "ack"
// e' pulsado por 1 ciclo confirmando o recebimento.
module protocolo_paralelo (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] dados,
    input  wire       strobe,
    output reg        ack,
    output reg  [5:0] tempo_min_reg,
    output reg  [5:0] tempo_amarelo_reg,
    output reg  [5:0] limiar_baixo_reg,
    output reg  [5:0] limiar_alto_reg
);
    localparam OP_TEMPO_MIN     = 2'b00;
    localparam OP_TEMPO_AMARELO = 2'b01;
    localparam OP_LIMIAR_BAIXO  = 2'b10;
    localparam OP_LIMIAR_ALTO   = 2'b11;

    reg strobe_ant;
    wire strobe_borda;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) strobe_ant <= 1'b0;
        else        strobe_ant <= strobe;
    end
    assign strobe_borda = strobe & ~strobe_ant;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ack               <= 1'b0;
            tempo_min_reg      <= 6'd10; // valores padrao de seguranca
            tempo_amarelo_reg  <= 6'd3;
            limiar_baixo_reg   <= 6'd3;
            limiar_alto_reg    <= 6'd8;
        end else if (strobe_borda) begin
            ack <= 1'b1;
            case (dados[7:6])
                OP_TEMPO_MIN:     tempo_min_reg     <= dados[5:0];
                OP_TEMPO_AMARELO: tempo_amarelo_reg <= dados[5:0];
                OP_LIMIAR_BAIXO:  limiar_baixo_reg  <= dados[5:0];
                OP_LIMIAR_ALTO:   limiar_alto_reg   <= dados[5:0];
            endcase
        end else begin
            ack <= 1'b0;
        end
    end
endmodule
