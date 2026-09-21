`timescale 1ns/1ps
// tb_top_semaforo: testbench de integracao completa. Cada caso reseta o
// DUT para ficar deterministico. Casos 4/5 comparam o tempo ate o
// pedestre ser liberado sob trafego baixo vs alto (apos burst real de
// veiculos). Caso 6 le a telemetria de verdade via miso/sclk (fase,
// nivel_fluxo, contagem) em vez de so' inspecionar sinais internos.
module tb_top_semaforo;
    reg clk, rst_n, sensor_raw, botao_raw;
    reg sclk, cs_n, mosi;
    wire led_vermelho, led_amarelo, led_verde, led_ped_verde, led_ped_vermelho;
    wire miso, busy;
    integer erros;
    integer ciclos_baixo, ciclos_alto;
    reg [7:0] telemetria_lida;
    reg [1:0] fase_esperada;
    reg [7:0] contagem_esperada;

    // JANELA_AMOSTRAGEM=200 e DIVISOR_TICK=1: tick a cada ciclo de clock,
    // preservando a contagem em "ciclos" (o valor real de hardware,
    // 27_000_000, so' e' usado na sintese fisica -- ver rtl/prescaler.v).
    top_semaforo #(.JANELA_AMOSTRAGEM(200), .DIVISOR_TICK(1)) dut (
        .clk(clk), .rst_n(rst_n),
        .sensor_raw(sensor_raw), .botao_raw(botao_raw),
        .led_vermelho(led_vermelho), .led_amarelo(led_amarelo), .led_verde(led_verde),
        .led_ped_verde(led_ped_verde), .led_ped_vermelho(led_ped_vermelho),
        .sclk(sclk), .cs_n(cs_n), .mosi(mosi), .miso(miso), .busy(busy)
    );

    always #5 clk = ~clk;

    task espera_clk(input integer n);
        integer j;
        begin
            for (j = 0; j < n; j = j + 1) begin
                @(posedge clk);
                #1;
            end
        end
    endtask

    task reseta_dut;
        begin
            // sensor_raw/botao_raw sao ativos em nivel BAIXO (hardware
            // real, invertidos dentro de top_semaforo.v) -- repouso = 1
            rst_n = 0; sensor_raw = 1; botao_raw = 1;
            sclk = 0; cs_n = 1; mosi = 0;
            espera_clk(2);
            rst_n = 1;
            espera_clk(2);
        end
    endtask

    task pulso_sclk(input valor_mosi);
        begin
            mosi = valor_mosi;
            espera_clk(2);
            sclk = 1'b1;
            espera_clk(2);
            sclk = 1'b0;
            espera_clk(2);
        end
    endtask

    task envia_comando_serial(input [7:0] byte_cmd);
        integer k;
        begin
            cs_n = 0;
            espera_clk(2);
            for (k = 7; k >= 0; k = k - 1)
                pulso_sclk(byte_cmd[k]);
            espera_clk(1);
            cs_n = 1;
            espera_clk(2);
        end
    endtask

    // Le o byte de telemetria via miso com 7 pulsos de sclk (o MSB ja
    // fica disponivel assim que cs_n desce). Como comando_valido so'
    // pulsa apos o 8o bit, esta leitura nunca aplica um comando (no-op
    // sobre a configuracao). "esperado_*" usa as mesmas formulas de
    // fase_telemetria/tempo_ate_pedestre de top_semaforo.v, congeladas no
    // instante em que cs_n desce (mesmo instante do snapshot real feito
    // por protocolo_serial).
    task le_telemetria_serial(output [7:0] byte_lido, output [1:0] esperado_fase,
                               output [7:0] esperado_contagem);
        integer k;
        begin
            cs_n = 0;
            if (dut.estado_carro == 2'b10 && dut.solicitacao_pedestre)
                esperado_fase = 2'b11;
            else
                esperado_fase = dut.estado_carro;
            case (dut.estado_carro)
                2'b10:   esperado_contagem = dut.u_fsm.contagem_atual + {2'b00, dut.tempo_amarelo_reg};
                2'b01:   esperado_contagem = dut.u_fsm.contagem_atual;
                default: esperado_contagem = 8'd0;
            endcase
            espera_clk(2);
            byte_lido[7]     = miso;
            for (k = 6; k >= 0; k = k - 1) begin
                pulso_sclk(1'b0);
                byte_lido[k] = miso;
            end
            cs_n = 1;
            espera_clk(2);
        end
    endtask

    // gera N veiculos reais (sensor_raw sobe/desce, respeitando o
    // debounce de 8 ciclos), construindo trafego real em vez de forcar
    // sinais internos.
    task gera_veiculos(input integer n);
        integer m;
        begin
            for (m = 0; m < n; m = m + 1) begin
                sensor_raw = 0; espera_clk(10); // "passa" (ativo em baixo)
                sensor_raw = 1; espera_clk(10); // repouso
            end
        end
    endtask

    // conta ciclos ate estado_carro virar amarelo, com timeout de
    // seguranca contra travamento da simulacao
    task aguarda_amarelo(output integer ciclos);
        integer timeout;
        begin
            ciclos = 0;
            timeout = 0;
            while (dut.estado_carro !== 2'b01 && timeout < 500) begin
                @(posedge clk); #1;
                ciclos = ciclos + 1;
                timeout = timeout + 1;
            end
        end
    endtask

    initial begin
        clk = 0; erros = 0;
        $dumpfile("tb_top_semaforo.vcd");
        $dumpvars(0, tb_top_semaforo);

        // ---- Caso 1: estado inicial seguro + tempo de verde padrao ----
        reseta_dut;
        if (led_verde !== 1'b1 || led_ped_vermelho !== 1'b1) begin
            erros = erros + 1;
            $display("[FALHA] estado inicial incorreto (led_verde=%b led_ped_vermelho=%b)",
                      led_verde, led_ped_vermelho);
        end else $display("[OK]    estado inicial seguro: veiculos=VERDE, pedestre=VERMELHO");

        if (dut.nivel_fluxo !== 2'b00) begin
            erros = erros + 1;
            $display("[FALHA] nivel_fluxo=%b, esperado 00 (baixo) logo apos reset", dut.nivel_fluxo);
        end else $display("[OK]    nivel_fluxo=BAIXO por padrao (nenhum veiculo ainda)");

        if (dut.tempo_min_efetivo !== 8'd5) begin
            erros = erros + 1;
            $display("[FALHA] tempo_min_efetivo=%0d, esperado 5 (metade do padrao 10, trafego baixo)",
                      dut.tempo_min_efetivo);
        end else $display("[OK]    tempo_min_efetivo=5 (metade do padrao, trafego baixo -> pedestre liberado mais rapido)");

        // ---- Caso 2: configura tempo_min_reg=3 e tempo_amarelo=2 via protocolo serial ----
        reseta_dut;
        envia_comando_serial(8'b00_000011); // opcode=00 (OP_TEMPO_MIN), valor=3
        if (dut.tempo_min_reg !== 6'd3) begin
            erros = erros + 1;
            $display("[FALHA] tempo_min_reg=%0d, esperado 3 apos comando serial", dut.tempo_min_reg);
        end else $display("[OK]    tempo_min_reg atualizado para 3 via protocolo serial");

        envia_comando_serial(8'b01_000010); // opcode=01 (OP_TEMPO_AMARELO), valor=2
        if (dut.tempo_amarelo_reg !== 6'd2) begin
            erros = erros + 1;
            $display("[FALHA] tempo_amarelo_reg=%0d, esperado 2 apos comando serial", dut.tempo_amarelo_reg);
        end else $display("[OK]    tempo_amarelo_reg atualizado para 2 via protocolo serial");

        // ---- Caso 3: gera 3 veiculos e confirma a contagem na BRAM ----
        reseta_dut;
        gera_veiculos(3);
        if (dut.ponteiro_escrita_w !== 8'd3) begin
            erros = erros + 1;
            $display("[FALHA] ponteiro_escrita_w=%0d, esperado 3 (3 veiculos contados)", dut.ponteiro_escrita_w);
        end else $display("[OK]    3 veiculos contados corretamente (ponteiro_escrita_w=3)");

        // ---- Caso 4: trafego BAIXO -> mede o tempo ate o pedestre ser liberado ----
        reseta_dut;
        botao_raw = 0; // pressionado (ativo em baixo)
        aguarda_amarelo(ciclos_baixo);
        botao_raw = 1; // solto
        $display("[INFO]  trafego BAIXO: %0d ciclos ate o inicio do amarelo (tempo_min_efetivo=5)", ciclos_baixo);
        espera_clk(2 + 15 + 5); // deixa o ciclo terminar antes do proximo caso

        // ---- Caso 5: trafego ALTO (burst de 50 veiculos em ~5 janelas de
        // amostragem) -> mede o mesmo tempo e compara com o caso 4.
        // fsm_semaforo so' recarrega o contador ao ENTRAR numa fase nova,
        // entao um burst gerado logo apos o reset so' afeta o tempo da
        // fase seguinte, nao a que ja estava carregada. Por isso ha' um
        // 1o ciclo descartavel (usando o tempo_min_efetivo antigo) so'
        // para reentrar em CARRO_VERDE com o novo valor (alto=20) ja
        // carregado; a 2a pressao mede o tempo que importa.
        reseta_dut;
        gera_veiculos(50); // ~50*20 ciclos = 1000 ciclos = 5 janelas de 200
        if (dut.nivel_fluxo !== 2'b10) begin
            erros = erros + 1;
            $display("[FALHA] nivel_fluxo=%b apos o burst de veiculos, esperado 10 (alto)", dut.nivel_fluxo);
        end else $display("[OK]    nivel_fluxo=ALTO apos burst real de 50 veiculos em ~5 janelas");

        if (dut.tempo_min_efetivo !== 8'd20) begin
            erros = erros + 1;
            $display("[FALHA] tempo_min_efetivo=%0d, esperado 20 (dobro do padrao 10, trafego alto)",
                      dut.tempo_min_efetivo);
        end else $display("[OK]    tempo_min_efetivo=20 (dobro do padrao, trafego alto -> pedestre espera mais)");

        botao_raw = 0; // 1a pressao (descartavel, ainda com o tempo antigo)
        espera_clk(15);
        botao_raw = 1;
        espera_clk(3 + 2 + 15 + 3);
        if (dut.estado_carro !== 2'b10) begin
            erros = erros + 1;
            $display("[FALHA] nao retornou a CARRO_VERDE apos o 1o ciclo descartavel (estado_carro=%b)", dut.estado_carro);
        end

        botao_raw = 0; // 2a pressao: mede o efeito real do trafego alto
        aguarda_amarelo(ciclos_alto);
        botao_raw = 1;
        $display("[INFO]  trafego ALTO: %0d ciclos ate o inicio do amarelo (tempo_min_efetivo=20)", ciclos_alto);

        if (ciclos_alto <= ciclos_baixo) begin
            erros = erros + 1;
            $display("[FALHA] tempo sob trafego alto (%0d) nao foi maior que sob trafego baixo (%0d)",
                      ciclos_alto, ciclos_baixo);
        end else $display("[OK]    comportamento dinamico confirmado: trafego alto atrasa a liberacao do pedestre (%0d > %0d ciclos)",
                      ciclos_alto, ciclos_baixo);

        // ---- Caso 6: telemetria lida de verdade via miso/sclk ----
        reseta_dut;
        le_telemetria_serial(telemetria_lida, fase_esperada, contagem_esperada);
        if (telemetria_lida[7:6] !== fase_esperada) begin
            erros = erros + 1;
            $display("[FALHA] telemetria fase=%b, esperado estado_carro=%b (no instante do quadro)",
                      telemetria_lida[7:6], fase_esperada);
        end else $display("[OK]    telemetria de fase (%b) bate com estado_carro real",
                      telemetria_lida[7:6]);

        // aceita esperado OU esperado+1: protocolo_serial captura o valor
        // do registrador 1 ciclo "antes" do que o testbench le' depois --
        // mesma defasagem ja' vista em carrega_cont. Compara so' os 4
        // bits baixos porque a contagem e' truncada no byte de telemetria
        // (ver top_semaforo.v) para abrir espaco pro nivel_fluxo.
        if (telemetria_lida[3:0] !== contagem_esperada[3:0] &&
            telemetria_lida[3:0] !== contagem_esperada[3:0] + 4'd1) begin
            erros = erros + 1;
            $display("[FALHA] telemetria contagem=%0d, esperado %0d (ou %0d, defasagem de 1 ciclo)",
                      telemetria_lida[3:0], contagem_esperada[3:0], contagem_esperada[3:0] + 4'd1);
        end else $display("[OK]    telemetria de contagem regressiva (%0d) bate com a FSM real (referencia=%0d) -- e' o valor que alimentaria o countdown da Raspberry Pi",
                      telemetria_lida[3:0], contagem_esperada[3:0]);

        if (telemetria_lida[5:4] !== dut.nivel_fluxo) begin
            erros = erros + 1;
            $display("[FALHA] telemetria nivel_fluxo=%b, esperado %b", telemetria_lida[5:4], dut.nivel_fluxo);
        end else $display("[OK]    telemetria de nivel_fluxo (%b) bate com o real", telemetria_lida[5:4]);

        if (erros == 0)
            $display("RESULTADO: TODOS OS CASOS PASSARAM (12/12)");
        else
            $display("RESULTADO: %0d CASO(S) FALHARAM", erros);
        $finish;
    end
endmodule
