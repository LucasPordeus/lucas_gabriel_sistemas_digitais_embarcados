`timescale 1ns/1ps
// tb_top_semaforo: testbench de integracao completa. Cada caso comeca
// com um reset proprio para ficar determinístico e facil de depurar
// (licao aprendida no TP5: nao acumular estado implicito entre casos).
// Casos 4 e 5 validam a extensao de tempo de verde dinamico por nivel de
// fluxo: caso 4 mede o tempo ate o pedestre ser liberado sob trafego
// BAIXO (padrao, sem veiculos), caso 5 sob trafego ALTO (apos um burst
// real de veiculos), e compara os dois -- o alto precisa ser
// comprovadamente maior que o baixo. Caso 6 valida a extensao de
// telemetria de countdown (fase + contagem regressiva) lendo o byte de
// verdade via miso/sclk, em vez de so' inspecionar os sinais internos.
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

    // JANELA_AMOSTRAGEM reduzida para a simulacao rodar rapido (o valor de
    // producao, 200, so' importa para o "tamanho" relativo da janela real).
    // DIVISOR_TICK=1 mantem o tick do prescaler disparando a cada ciclo de
    // clock (equivalente a nao ter prescaler nenhum), preservando a mesma
    // contagem em "ciclos" que todos os casos abaixo ja validavam antes
    // desta extensao -- o valor real de hardware (27_000_000, 1 tick/s)
    // so' e' usado na sintese fisica (ver rtl/prescaler.v).
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
            // botao_raw agora e' ativo em nivel BAIXO (botao onboard S1,
            // invertido dentro de top_semaforo.v) -- repouso/nao-pressionado = 1
            // sensor_raw agora e' ativo em nivel BAIXO (sensor real,
            // invertido dentro de top_semaforo.v) -- repouso/sem obstaculo = 1
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

    // Le o byte de telemetria (fase + contagem regressiva) via miso. So'
    // manda 7 pulsos de sclk (nao 8) de proposito: miso_reg desloca o
    // byte de telemetria a cada borda de subida de sclk (o bit mais
    // significativo ja fica disponivel assim que cs_n desce, antes do
    // 1o pulso), entao 7 pulsos bastam pra ler os 8 bits inteiros -- e,
    // como comando_valido so' pulsa apos o 8o pulso, o "comando" enviado
    // (mosi=0 junto com cada pulso) nunca chega a ser latched, ou seja,
    // esta leitura e' garantidamente um no-op sobre a configuracao.
    // "esperado_*" congela a fase/contagem reais da FSM no exato instante
    // em que o quadro comeca (cs_n desce) -- e' o mesmo instante em que
    // protocolo_serial faz o snapshot que vai ser deslocado pelos
    // proximos ~40 ciclos de "clk" (tempo real do quadro serial). Comparar
    // contra o valor da FSM lido SO' DEPOIS do quadro inteiro terminar
    // daria falso-negativo, porque o contador da FSM continua decrementando
    // durante a leitura -- a mesma pegadinha de timing ja documentada
    // para o "carrega_cont" (o snapshot vale para o instante da captura,
    // nao para o instante em que o teste termina de ler).
    task le_telemetria_serial(output [7:0] byte_lido, output [1:0] esperado_fase,
                               output [7:0] esperado_contagem);
        integer k;
        begin
            cs_n = 0;
            // congela a referencia o mais perto possivel do instante em
            // que cs_n desce -- mesmo assim pode ficar 1 ciclo "atras" do
            // valor real capturado por protocolo_serial: dentro do MESMO
            // ciclo de clock, o RTL le o valor do registrador *antes* da
            // borda (o que "shift_out" captura) enquanto qualquer leitura
            // feita no testbench um instante depois ja' ve' o valor *pos*
            // borda (ja decrementado) -- por isso a comparacao abaixo
            // aceita esperado OU esperado+1 (ver comentario na comparacao).
            // mesma formula de "fase_telemetria" calculada em
            // top_semaforo.v -- usa o codigo 11 (livre) pra sinalizar
            // pedido de pedestre pendente durante o CARRO_VERDE.
            if (dut.estado_carro == 2'b10 && dut.solicitacao_pedestre)
                esperado_fase = 2'b11;
            else
                esperado_fase = dut.estado_carro;
            // mesma formula de "tempo_ate_pedestre" calculada em
            // top_semaforo.v -- a telemetria agora manda esse valor, nao
            // mais o contagem_atual bruto da fase corrente.
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

    // gera N veiculos reais (sensor_raw sobe/desce, respeitando o debounce
    // de 8 ciclos do sensor) -- usado para construir trafego de verdade,
    // em vez de forcar sinais internos.
    task gera_veiculos(input integer n);
        integer m;
        begin
            for (m = 0; m < n; m = m + 1) begin
                sensor_raw = 0; espera_clk(10); // "passa" (ativo em baixo)
                sensor_raw = 1; espera_clk(10); // repouso
            end
        end
    endtask

    // conta quantos ciclos de clock se passam ate estado_carro virar
    // amarelo (2'b01), com timeout de seguranca para nao travar a simulacao
    // caso algo esteja errado.
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

        // ---- Caso 1: estado inicial seguro + tempo de verde padrao (trafego
        // baixo por default, ninguem passou ainda) ----
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

        // ---- Caso 4: trafego BAIXO (nenhum veiculo) -> mede o tempo real
        // ate o pedestre ser liberado (amarelo comeca) ----
        reseta_dut;
        botao_raw = 0; // pressionado (ativo em baixo)
        aguarda_amarelo(ciclos_baixo);
        botao_raw = 1; // solto
        $display("[INFO]  trafego BAIXO: %0d ciclos ate o inicio do amarelo (tempo_min_efetivo=5)", ciclos_baixo);
        // deixa o ciclo terminar (amarelo + pedestre) antes do proximo caso
        espera_clk(2 + 15 + 5);

        // ---- Caso 5: trafego ALTO -> constroi um burst real de veiculos
        // (50 veiculos ao longo de ~5 janelas de amostragem) ate nivel_fluxo
        // virar ALTO, so' entao pressiona o botao e mede o mesmo tempo ----
        //
        // Detalhe de timing importante (descoberto rodando esta simulacao):
        // fsm_semaforo so' recarrega o contador no INSTANTE em que entra
        // numa fase nova (carrega_cont), nao a cada ciclo. Isso quer dizer
        // que o burst de veiculos gerado logo apos o reset muda nivel_fluxo
        // para ALTO enquanto o sistema ainda esta na 1a fase de verde, que
        // ja tinha sido carregada (com o valor BAIXO de entao) no proprio
        // reset -- pressionar o botao nesse momento mediria o valor antigo,
        // nao o novo. Por isso o teste faz um 1o ciclo "descartavel" (usando
        // o tempo antigo, curto) so' para reentrar em CARRO_VERDE UMA VEZ
        // DEPOIS do burst; e' nesse 2o reload que tempo_min_efetivo=20 (ja
        // ALTO) e' de fato carregado no contador, e so' entao a 2a pressao
        // do botao mede o tempo que realmente importa para este caso.
        reseta_dut;
        gera_veiculos(50); // ~50 * 20 ciclos = 1000 ciclos = 5 janelas de 200
        if (dut.nivel_fluxo !== 2'b10) begin
            erros = erros + 1;
            $display("[FALHA] nivel_fluxo=%b apos o burst de veiculos, esperado 10 (alto)", dut.nivel_fluxo);
        end else $display("[OK]    nivel_fluxo=ALTO apos burst real de 50 veiculos em ~5 janelas");

        if (dut.tempo_min_efetivo !== 8'd20) begin
            erros = erros + 1;
            $display("[FALHA] tempo_min_efetivo=%0d, esperado 20 (dobro do padrao 10, trafego alto)",
                      dut.tempo_min_efetivo);
        end else $display("[OK]    tempo_min_efetivo=20 (dobro do padrao, trafego alto -> pedestre espera mais)");

        // 1o ciclo (descartavel): ainda usa o valor carregado no reset
        // (baixo=5), so' para passar por amarelo+pedestre e voltar a
        // CARRO_VERDE -- reentrada em que o novo valor (alto=20) sera' carregado.
        botao_raw = 0; // pressionado (ativo em baixo)
        espera_clk(15); // debounce + garante que ja esta em amarelo
        botao_raw = 1; // solto
        espera_clk(3 + 2 + 15 + 3); // resto do amarelo (padrao=3) + pedestre (15) + margem
        if (dut.estado_carro !== 2'b10) begin
            erros = erros + 1;
            $display("[FALHA] nao retornou a CARRO_VERDE apos o 1o ciclo descartavel (estado_carro=%b)", dut.estado_carro);
        end

        // 2a pressao (a que de fato mede o efeito do trafego alto): o
        // contador desta fase ja foi recarregado com tempo_min_efetivo=20.
        botao_raw = 0; // pressionado (ativo em baixo)
        aguarda_amarelo(ciclos_alto);
        botao_raw = 1; // solto
        $display("[INFO]  trafego ALTO: %0d ciclos ate o inicio do amarelo (tempo_min_efetivo=20)", ciclos_alto);

        if (ciclos_alto <= ciclos_baixo) begin
            erros = erros + 1;
            $display("[FALHA] tempo sob trafego alto (%0d) nao foi maior que sob trafego baixo (%0d)",
                      ciclos_alto, ciclos_baixo);
        end else $display("[OK]    comportamento dinamico confirmado: trafego alto atrasa a liberacao do pedestre (%0d > %0d ciclos)",
                      ciclos_alto, ciclos_baixo);

        // ---- Caso 6: telemetria de countdown lida de verdade via
        // miso/sclk (nao so' inspecionada internamente) -- confirma que
        // o byte que a Raspberry Pi receberia bate com a fase e a
        // contagem regressiva reais da FSM no instante da leitura ----
        reseta_dut;
        le_telemetria_serial(telemetria_lida, fase_esperada, contagem_esperada);
        if (telemetria_lida[7:6] !== fase_esperada) begin
            erros = erros + 1;
            $display("[FALHA] telemetria fase=%b, esperado estado_carro=%b (no instante do quadro)",
                      telemetria_lida[7:6], fase_esperada);
        end else $display("[OK]    telemetria de fase (%b) bate com estado_carro real",
                      telemetria_lida[7:6]);

        // aceita esperado OU esperado+1: protocolo_serial captura o valor
        // do registrador da FSM "entrando" na borda de clock em que cs_n
        // ainda estava em 1, enquanto o testbench le' o mesmo registrador
        // um instante depois (ja' contabilizando aquela borda) -- e' o
        // mesmo tipo de defasagem de 1 ciclo entre leitura e escrita
        // registrada que ja apareceu antes neste projeto (carrega_cont).
        // Compara so' os 4 bits baixos: a contagem agora e' truncada pra
        // 4 bits no byte de telemetria (ver comentario em top_semaforo.v),
        // pra abrir espaco pro nivel_fluxo nos bits [5:4].
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
