// tb_top_semaforo: teste de integracao do sistema completo, acionando so'
// os pinos reais (botao, sensor, sclk/cs_n) e observando LEDs e miso.
// Tempos reduzidos: 1 "segundo" = 40 ciclos de clk.
//   1. estado inicial e quadro de telemetria lido pelo link serial;
//   2. fluxo baixo: tempo do aperto ate o amarelo ~ TEMPO_VERDE_BAIXO;
//   3. telemetria durante a travessia (carro vermelho, pedestre verde);
//   4. fluxo alto (veiculos reais no sensor): espera ~ TEMPO_VERDE_ALTO;
//   5. durante todo o teste: LEDs coerentes e nunca pedestre verde sem
//      carro vermelho; todo quadro lido tem o marcador 1010 e bate com a FSM.
`timescale 1ns/1ps
module tb_top_semaforo;
    localparam integer CICLOS_SEG = 40;
    localparam integer T_BAIXO = 5, T_ALTO = 20, T_AMARELO = 3, T_PEDESTRE = 15;

    reg  clk, rst_n, botao_raw, sensor_raw, sclk, cs_n;
    wire led_vermelho, led_amarelo, led_verde, led_ped_verde, led_ped_vermelho, miso;

    reg  [15:0] quadro;          // ultimo quadro lido pelo link serial
    reg  [15:0] quadro_ref;      // quadro esperado, montado dos sinais internos ao descer cs_n
    integer     erros, violacoes, segundos_baixo, segundos_alto;

    top_semaforo #(
        .DIVISOR_TICK(CICLOS_SEG), .DEBOUNCE_BOTAO(4), .DEBOUNCE_SENSOR(2), .JANELA_AMOSTRAGEM(3)
    ) dut (
        .clk(clk), .rst_n(rst_n), .botao_raw(botao_raw), .sensor_raw(sensor_raw),
        .led_vermelho(led_vermelho), .led_amarelo(led_amarelo), .led_verde(led_verde),
        .led_ped_verde(led_ped_verde), .led_ped_vermelho(led_ped_vermelho),
        .sclk(sclk), .cs_n(cs_n), .miso(miso)
    );

    always #5 clk = ~clk;

    // invariantes dos LEDs, conferidas em todo ciclo apos o reset
    always @(negedge clk)
        if (rst_n && dut.rst_sist_n) begin
            if (led_vermelho + led_amarelo + led_verde != 1) violacoes = violacoes + 1;
            if (led_ped_verde == led_ped_vermelho)           violacoes = violacoes + 1;
            if (led_ped_verde && !led_vermelho)              violacoes = violacoes + 1;
        end

    task espera(input integer n);
        integer i;
        for (i = 0; i < n; i = i + 1) begin @(posedge clk); #1; end
    endtask

    task aperta_botao;
        begin botao_raw = 0; espera(20); botao_raw = 1; espera(20); end
    endtask

    // n veiculos passando pelo sensor (ativo em 0), 5 ciclos cada nivel
    task passa_veiculos(input integer n);
        integer v;
        for (v = 0; v < n; v = v + 1) begin
            sensor_raw = 0; espera(5); sensor_raw = 1; espera(5);
        end
    endtask

    // le um quadro como a Raspberry Pi: miso antes de cada subida de sclk
    task le_quadro;
        integer b;
        begin
            cs_n = 0;
            quadro_ref = dut.quadro_telemetria;
            espera(6);
            for (b = 15; b >= 0; b = b - 1) begin
                quadro[b] = miso;
                sclk = 1; espera(6);
                sclk = 0; espera(6);
            end
            cs_n = 1; espera(6);
            // a contagem pode ter mudado 1 segundo entre a foto e o congelamento
            if (quadro[15:12] !== 4'b1010 || quadro[15:6] !== quadro_ref[15:6] ||
                (quadro[5:0] !== quadro_ref[5:0] && quadro[5:0] + 6'd1 !== quadro_ref[5:0])) begin
                erros = erros + 1;
                $display("[FALHA] quadro lido %b, esperado %b", quadro, quadro_ref);
            end
        end
    endtask

    // segundos do aperto do botao ate o amarelo; termina no amarelo ou apos 60 s
    task mede_espera_pedestre(output integer segundos);
        integer c;
        begin
            aperta_botao;
            c = 40;
            while (!led_amarelo && c < 60 * CICLOS_SEG) begin espera(1); c = c + 1; end
            segundos = c / CICLOS_SEG;
        end
    endtask

    task confere(input ok, input [8*64-1:0] descricao);
        if (!ok) begin
            erros = erros + 1;
            $display("[FALHA] %0s (quadro=%b)", descricao, quadro);
        end else
            $display("[OK]    %0s", descricao);
    endtask

    initial begin
        $dumpfile("build/tb_top_semaforo.vcd");
        $dumpvars(0, tb_top_semaforo);
        clk = 0; rst_n = 0; botao_raw = 1; sensor_raw = 1; sclk = 0; cs_n = 1;
        erros = 0; violacoes = 0;
        espera(3); rst_n = 1; espera(5);

        // 1. estado inicial
        le_quadro;
        confere(led_verde && led_ped_vermelho, "inicio: carros verdes, pedestre vermelho");
        confere(quadro[11:10] == 2'b10 && quadro[9] == 0 && quadro[8] == 0 && quadro[7:6] == 2'b00,
                "telemetria inicial: VERDE / VERMELHO / sem pedido / fluxo baixo");

        // 2. fluxo baixo; espera o verde minimo do reset passar antes do aperto
        espera((T_BAIXO + 2) * CICLOS_SEG);
        mede_espera_pedestre(segundos_baixo);
        $display("[INFO]  fluxo baixo: %0d s do aperto ao amarelo", segundos_baixo);
        confere(segundos_baixo >= T_BAIXO - 1 && segundos_baixo <= T_BAIXO + 1,
                "fluxo baixo: pedestre espera ~TEMPO_VERDE_BAIXO");

        // 3. telemetria durante amarelo e travessia
        le_quadro;
        confere(quadro[11:10] == 2'b01 && quadro[9] == 0 && quadro[8] == 1,
                "telemetria no amarelo: AMARELO / VERMELHO / pedido pendente");
        espera((T_AMARELO + 1) * CICLOS_SEG);
        le_quadro;
        confere(led_ped_verde && quadro[11:10] == 2'b00 && quadro[9] == 1,
                "telemetria na travessia: VERMELHO / pedestre VERDE");
        espera((T_PEDESTRE + 1) * CICLOS_SEG);
        le_quadro;
        confere(led_verde && quadro[11:10] == 2'b10 && quadro[8] == 0,
                "volta ao verde com o pedido apagado");

        // 4. fluxo alto: 12 veiculos por janela de 3 s, por 6 janelas
        passa_veiculos(72);
        le_quadro;
        confere(quadro[7:6] == 2'b10, "sensor real eleva o fluxo para ALTO");
        mede_espera_pedestre(segundos_alto);
        $display("[INFO]  fluxo alto: %0d s do aperto ao amarelo", segundos_alto);
        confere(segundos_alto >= T_ALTO - 1 && segundos_alto <= T_ALTO + 1,
                "fluxo alto: pedestre espera ~TEMPO_VERDE_ALTO");
        confere(segundos_alto > segundos_baixo, "fluxo alto atrasa o pedestre mais que fluxo baixo");

        // 5. sem veiculos, o fluxo volta a baixo depois de 5 janelas
        espera((T_AMARELO + T_PEDESTRE + 6 * 3) * CICLOS_SEG);
        le_quadro;
        confere(quadro[7:6] == 2'b00, "sem veiculos o fluxo volta a BAIXO");

        confere(violacoes == 0, "LEDs sempre coerentes e seguros");

        if (erros == 0) $display("RESULTADO: TODOS OS CASOS PASSARAM");
        else            $display("RESULTADO: %0d CASO(S) FALHARAM", erros);
        $finish;
    end
endmodule
