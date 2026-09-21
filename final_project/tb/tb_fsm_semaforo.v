// Testbench da fsm_semaforo: percorre o ciclo completo CARRO_VERDE ->
// CARRO_AMARELO -> PEDESTRE_VERDE -> CARRO_VERDE, confirmando a regra de
// seguranca (sem solicitacao, permanece em verde) e o pulso de
// limpa_solicitacao ao fim da fase de pedestre.
`timescale 1ns/1ps
module tb_fsm_semaforo;
    localparam W = 8;
    reg clk, rst_n, solicitacao;
    reg [W-1:0] t_verde, t_amarelo, t_pedestre;
    wire [1:0] estado_carro;
    wire verde_pedestre, limpa_solicitacao;
    integer erros;

    fsm_semaforo #(.LARGURA_TEMPO(W)) dut (
        .clk(clk), .rst_n(rst_n), .tick(1'b1),
        .solicitacao_pedestre(solicitacao),
        .tempo_min_verde(t_verde), .tempo_amarelo(t_amarelo), .tempo_pedestre(t_pedestre),
        .estado_carro(estado_carro), .verde_pedestre(verde_pedestre),
        .limpa_solicitacao(limpa_solicitacao)
    );

    always #5 clk = ~clk;

    task espera_ciclos(input integer n);
        integer i;
        begin
            // #1 apos cada posedge garante que os registradores (NBA) e a
            // logica combinacional ja se estabilizaram antes de checar
            // qualquer sinal (evita corrida de simulacao com o proprio clock).
            for (i = 0; i < n; i = i + 1) begin
                @(posedge clk);
                #1;
            end
        end
    endtask

    initial begin
        clk = 0; rst_n = 0; solicitacao = 0;
        t_verde = 5; t_amarelo = 3; t_pedestre = 4; erros = 0;
        $dumpfile("tb_fsm_semaforo.vcd");
        $dumpvars(0, tb_fsm_semaforo);

        espera_ciclos(2); rst_n = 1; espera_ciclos(1);

        // Caso 1: logo apos reset, deve estar em CARRO_VERDE (10)
        if (estado_carro !== 2'b10) begin
            erros = erros + 1;
            $display("[FALHA] estado inicial nao e CARRO_VERDE (estado_carro=%b)", estado_carro);
        end else $display("[OK]    estado inicial = CARRO_VERDE");

        // Caso 2: sem solicitacao, mesmo apos o tempo minimo, permanece em verde (ONF-08)
        espera_ciclos(t_verde + 3);
        if (estado_carro !== 2'b10) begin
            erros = erros + 1;
            $display("[FALHA] sem solicitacao, saiu de CARRO_VERDE indevidamente");
        end else $display("[OK]    sem solicitacao pendente, permanece em CARRO_VERDE (seguranca)");

        // Caso 3: com solicitacao pendente e tempo minimo ja decorrido, deve ir para AMARELO
        solicitacao = 1;
        espera_ciclos(1);
        if (estado_carro !== 2'b01) begin
            erros = erros + 1;
            $display("[FALHA] nao transicionou para CARRO_AMARELO com solicitacao pendente (estado_carro=%b)", estado_carro);
        end else $display("[OK]    transicionou para CARRO_AMARELO ao registrar solicitacao");

        // Caso 4: apos tempo_amarelo ciclos, deve ir para PEDESTRE_VERDE
        // (+1 ciclo: o contador zera em t_amarelo ciclos, e a FSM so
        // registra a transicao no ciclo seguinte, ao amostrar "zerou")
        espera_ciclos(t_amarelo + 1);
        if (estado_carro !== 2'b00 || verde_pedestre !== 1'b1) begin
            erros = erros + 1;
            $display("[FALHA] nao entrou em PEDESTRE_VERDE apos tempo_amarelo (estado_carro=%b verde_pedestre=%b)",
                      estado_carro, verde_pedestre);
        end else $display("[OK]    entrou em PEDESTRE_VERDE apos tempo_amarelo, com verde_pedestre=1");

        // Caso 5: apos tempo_pedestre ciclos, deve limpar a solicitacao e voltar para CARRO_VERDE
        // limpa_solicitacao e' combinacional e fica em 1 durante o ULTIMO
        // ciclo de PEDESTRE_VERDE (quando tempo_esgotado ja e' 1 mas o
        // estado registrado ainda nao mudou) -- por isso e' checado aqui,
        // ANTES do ciclo extra que efetivamente latch a transicao.
        espera_ciclos(t_pedestre);
        if (limpa_solicitacao !== 1'b1) begin
            erros = erros + 1;
            $display("[FALHA] limpa_solicitacao nao foi pulsado ao fim de PEDESTRE_VERDE");
        end else $display("[OK]    limpa_solicitacao pulsado corretamente");
        espera_ciclos(1);
        if (estado_carro !== 2'b10) begin
            erros = erros + 1;
            $display("[FALHA] nao retornou para CARRO_VERDE apos PEDESTRE_VERDE (estado_carro=%b)", estado_carro);
        end else $display("[OK]    retornou para CARRO_VERDE, ciclo completo validado");

        if (erros == 0)
            $display("RESULTADO: TODOS OS CASOS PASSARAM (5/5)");
        else
            $display("RESULTADO: %0d CASO(S) FALHARAM", erros);
        $finish;
    end
endmodule
