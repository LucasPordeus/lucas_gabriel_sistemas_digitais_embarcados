// tb_media_movel_dsp: liga bram_historico + media_movel_dsp do mesmo jeito
// que top_semaforo e compara, a cada amostra, a media e o nivel de fluxo
// com um modelo de referencia (media arredondada das ultimas 5 amostras).
// Antes do teste a BRAM e' suja com lixo para provar que conteudo antigo
// nao entra na media depois do reset.
`timescale 1ns/1ps
module tb_media_movel_dsp;
    localparam integer LIMIAR_BAIXO = 1;
    localparam integer LIMIAR_ALTO  = 3;
    localparam integer N_AMOSTRAS   = 14;

    reg        clk, rst_n, nova_amostra;
    reg  [7:0] amostra;
    wire [7:0] ponteiro, amostra_saindo, media;
    wire [1:0] nivel_fluxo;

    reg  [7:0] sequencia [0:N_AMOSTRAS-1];  // amostras aplicadas, em ordem
    integer    i, j, soma_ref, media_ref, nivel_ref, erros;

    bram_historico u_historico (
        .clk(clk), .rst_n(rst_n),
        .escreve(nova_amostra), .dado_escrita(amostra),
        .endereco_leitura(ponteiro - 8'd5), .dado_leitura(amostra_saindo),
        .ponteiro_escrita(ponteiro)
    );

    media_movel_dsp #(.LIMIAR_BAIXO(LIMIAR_BAIXO), .LIMIAR_ALTO(LIMIAR_ALTO)) dut (
        .clk(clk), .rst_n(rst_n),
        .nova_amostra(nova_amostra), .amostra(amostra), .amostra_saindo(amostra_saindo),
        .media(media), .nivel_fluxo(nivel_fluxo)
    );

    always #5 clk = ~clk;

    task espera(input integer n);
        integer k;
        for (k = 0; k < n; k = k + 1) begin @(posedge clk); #1; end
    endtask

    // aplica uma amostra e espera a BRAM atualizar a leitura (como no top,
    // onde as amostras chegam com segundos de intervalo)
    task aplica(input [7:0] valor);
        begin
            amostra = valor; nova_amostra = 1; espera(1);
            nova_amostra = 0; espera(3);
        end
    endtask

    initial begin
        $dumpfile("build/tb_media_movel_dsp.vcd");
        $dumpvars(0, tb_media_movel_dsp);
        clk = 0; rst_n = 0; nova_amostra = 0; amostra = 0; erros = 0;
        sequencia[0]  = 0;  sequencia[1]  = 1;  sequencia[2]  = 2;  sequencia[3]  = 3;
        sequencia[4]  = 4;  sequencia[5]  = 8;  sequencia[6]  = 8;  sequencia[7]  = 8;
        sequencia[8]  = 8;  sequencia[9]  = 0;  sequencia[10] = 0;  sequencia[11] = 0;
        sequencia[12] = 0;  sequencia[13] = 0;
        espera(2); rst_n = 1; espera(1);

        // suja as 8 primeiras posicoes da BRAM com 200 e reseta de novo
        // (o reset zera o ponteiro e a media, mas nao a memoria)
        for (i = 0; i < 8; i = i + 1) aplica(8'd200);
        rst_n = 0; espera(2); rst_n = 1; espera(1);

        // aplica cada amostra da sequencia; termina apos a ultima
        for (i = 0; i < N_AMOSTRAS; i = i + 1) begin
            aplica(sequencia[i]);

            soma_ref = 0;
            for (j = (i >= 4 ? i - 4 : 0); j <= i; j = j + 1)
                soma_ref = soma_ref + sequencia[j];
            media_ref = (2 * soma_ref + 5) / 10;   // round(soma / 5)
            nivel_ref = (media_ref <= LIMIAR_BAIXO) ? 0 : (media_ref <= LIMIAR_ALTO) ? 1 : 2;

            if (media !== media_ref || nivel_fluxo !== nivel_ref) begin
                erros = erros + 1;
                $display("[FALHA] amostra %0d=%0d: media=%0d nivel=%0d, esperado media=%0d nivel=%0d",
                         i, sequencia[i], media, nivel_fluxo, media_ref, nivel_ref);
            end else
                $display("[OK]    amostra %0d=%0d: media=%0d nivel=%0d", i, sequencia[i], media, nivel_fluxo);
        end

        if (erros == 0) $display("RESULTADO: TODOS OS CASOS PASSARAM");
        else            $display("RESULTADO: %0d CASO(S) FALHARAM", erros);
        $finish;
    end
endmodule
