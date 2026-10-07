// tb_fsm_semaforo: verifica a maquina de estados com tick a cada ciclo
// (1 ciclo = 1 "segundo"):
//   - estado inicial e permanencia em verde sem pedido;
//   - pedido com o verde ja longo: o pedestre espera tempo_verde;
//   - pedido logo no inicio do verde: a espera nao soma com o verde minimo;
//   - duracao do amarelo e da travessia, e o pedido apagado no fim;
//   - durante todo o teste, nunca pedestre verde com carro fora do vermelho.
`timescale 1ns/1ps
module tb_fsm_semaforo;
    localparam integer T_VERDE    = 5;
    localparam integer T_AMARELO  = 3;
    localparam integer T_PEDESTRE = 4;

    localparam [1:0] VERMELHO = 2'b00, AMARELO = 2'b01, VERDE = 2'b10;

    reg        clk, rst_n;
    reg        solicitacao;      // modela o latch do botao_pedestre
    wire [1:0] cor_carro;
    wire       pedestre_verde, limpa_solicitacao;
    wire [5:0] contagem;
    integer    erros, violacoes, ciclos;

    fsm_semaforo #(.LARGURA_TEMPO(6)) dut (
        .clk(clk), .rst_n(rst_n), .tick(1'b1),
        .solicitacao_pedestre(solicitacao),
        .tempo_verde(T_VERDE[5:0]), .tempo_amarelo(T_AMARELO[5:0]), .tempo_pedestre(T_PEDESTRE[5:0]),
        .cor_carro(cor_carro), .pedestre_verde(pedestre_verde),
        .limpa_solicitacao(limpa_solicitacao), .contagem_atual(contagem)
    );

    always #5 clk = ~clk;

    // o pedido e' apagado pela FSM, como no botao_pedestre
    always @(posedge clk) if (limpa_solicitacao) solicitacao <= 1'b0;

    // invariante de seguranca, conferido em todo ciclo
    always @(negedge clk)
        if (rst_n && pedestre_verde && cor_carro !== VERMELHO) violacoes = violacoes + 1;

    task espera(input integer n);
        integer i;
        for (i = 0; i < n; i = i + 1) begin @(posedge clk); #1; end
    endtask

    // conta ciclos ate cor_carro mudar; termina na mudanca ou apos 200 ciclos
    task mede_fase(output integer n);
        reg [1:0] cor_inicial;
        begin
            cor_inicial = cor_carro; n = 0;
            while (cor_carro === cor_inicial && n < 200) begin espera(1); n = n + 1; end
        end
    endtask

    task confere(input ok, input [8*64-1:0] descricao);
        if (!ok) begin
            erros = erros + 1;
            $display("[FALHA] %0s (cor_carro=%b pedestre_verde=%b ciclos=%0d)",
                     descricao, cor_carro, pedestre_verde, ciclos);
        end else
            $display("[OK]    %0s", descricao);
    endtask

    initial begin
        $dumpfile("build/tb_fsm_semaforo.vcd");
        $dumpvars(0, tb_fsm_semaforo);
        clk = 0; rst_n = 0; solicitacao = 0; erros = 0; violacoes = 0; ciclos = 0;
        espera(2); rst_n = 1; espera(1);

        confere(cor_carro == VERDE && !pedestre_verde, "inicia com carros verdes e pedestre vermelho");

        espera(4 * T_VERDE);
        confere(cor_carro == VERDE, "sem pedido, carros continuam verdes");

        // pedido com o verde minimo ja cumprido: espera tempo_verde a partir do aperto
        solicitacao = 1;
        mede_fase(ciclos);
        confere(cor_carro == AMARELO && ciclos >= T_VERDE && ciclos <= T_VERDE + 2,
                "pedido tardio: carros ficam mais tempo_verde em verde");

        mede_fase(ciclos);
        confere(cor_carro == VERMELHO && pedestre_verde && ciclos >= T_AMARELO && ciclos <= T_AMARELO + 1,
                "amarelo dura tempo_amarelo e abre para o pedestre");

        mede_fase(ciclos);
        confere(cor_carro == VERDE && !pedestre_verde && ciclos >= T_PEDESTRE && ciclos <= T_PEDESTRE + 1,
                "travessia dura tempo_pedestre e volta ao verde");
        confere(solicitacao == 0, "pedido apagado ao fim da travessia");

        // pedido 1 ciclo apos o inicio do verde: a espera e' tempo_verde a
        // partir do aperto (+2 ciclos de latencia), e nao verde minimo + espera
        espera(1); solicitacao = 1;
        mede_fase(ciclos);
        confere(cor_carro == AMARELO && ciclos >= T_VERDE && ciclos <= T_VERDE + 2,
                "pedido no inicio do verde nao soma esperas");

        espera(T_AMARELO + T_PEDESTRE + 4);
        confere(violacoes == 0, "nunca pedestre verde com carro fora do vermelho");

        if (erros == 0) $display("RESULTADO: TODOS OS CASOS PASSARAM");
        else            $display("RESULTADO: %0d CASO(S) FALHARAM", erros);
        $finish;
    end
endmodule
