`timescale 1ns/1ps
// =====================================================================================
// tb_top.v - TESTBENCH do topo monofonico (de1_synth_top) com um WM8731 falso  [LEGADO]
// =====================================================================================
//
// Testa a placa inteira da versao monofonica, incluindo a configuracao por I2C:
//   - escravo I2C falso: responde ACK a cada byte e imprime cada registrador recebido
//     ("I2C: dev=34 reg=7 dado=041" etc.), para conferir a configuracao;
//   - gera BCLK/LRCK a partir do AUD_XCK, como o codec de verdade;
//   - decodifica AUD_DACDAT e grava o quadro com lrck = 0 em sim/samples_top.txt (som mono);
//   - no fim (60 ms), mostra os LEDs verdes: esperado LEDG = ...01 (configurado, sem erro).
//
// Observacao: nao existe ainda um testbench equivalente para o topo atual (de1_poly_top);
// a configuracao I2C e o i2s_tx sao os mesmos, entao este teste continua valendo para eles.
//
// Chaves usadas: SW = 00_0000_1101 -> SW[2:0] = 5 (La), SW[3] = 1 (toca), SW[5:4] = 0 (seno).
// =====================================================================================
module tb_top;
    reg CLOCK_50 = 0; always #10 CLOCK_50 = ~CLOCK_50;              // 50 MHz
    reg [3:0] KEY = 4'b1111; reg [9:0] SW = 10'b00_0000_1101;   // nota 5 (A4), toca=1, seno
    wire [9:0] LEDR; wire [7:0] LEDG;
    wire I2C_SCLK, AUD_XCK, AUD_DACDAT;
    tri1 I2C_SDAT;                                  // resistor de pull-up (tri1 = fio que fica em 1 quando ninguem puxa)
    wire AUD_BCLK, AUD_DACLRCK;

    de1_synth_top dut (.CLOCK_50(CLOCK_50), .KEY(KEY), .SW(SW), .LEDR(LEDR), .LEDG(LEDG),
        .I2C_SCLK(I2C_SCLK), .I2C_SDAT(I2C_SDAT), .AUD_XCK(AUD_XCK), .AUD_BCLK(AUD_BCLK),
        .AUD_DACLRCK(AUD_DACLRCK), .AUD_DACDAT(AUD_DACDAT), .AUD_ADCLRCK(1'b0), .AUD_ADCDAT(1'b0));

    // --- escravo I2C (so ACK + grava os bytes) ---
    integer bitn = 0, nbyte = 0; reg [7:0] sh; reg ack_drive = 0; reg [7:0] b0, b1, b2;
    assign I2C_SDAT = ack_drive ? 1'b0 : 1'bz;      // o escravo so puxa o fio para 0 (dreno aberto)
    reg started = 0;
    always @(negedge I2C_SDAT) if (I2C_SCLK) begin started = 1; bitn = 0; nbyte = 0; end   // START
    always @(posedge I2C_SDAT) if (I2C_SCLK) begin started = 0; end                       // STOP
    always @(posedge I2C_SCLK) if (started) begin   // subida de SCL: le o bit
        if (bitn < 8) begin sh = {sh[6:0], I2C_SDAT}; bitn = bitn + 1; end
        else bitn = bitn + 1;                              // 9o pulso = ACK
    end
    always @(negedge I2C_SCLK) if (started) begin   // descida de SCL: hora de mexer no fio
        if (bitn == 8) ack_drive = 1;                      // puxa SDA em baixo para dar ACK
        else if (bitn == 9) begin
            ack_drive = 0; bitn = 0;                       // solta o fio depois do ACK
            // guarda o byte; no 3o byte, monta e imprime o registrador
            case (nbyte) 0: b0 = sh; 1: b1 = sh; 2: begin b2 = sh;
                $display("I2C: dev=%h reg=%0d dado=%h", b0, b1[7:1], {b1[0], b2}); end endcase
            nbyte = nbyte + 1;
        end
    end

    // --- gerador de BCLK/LRCK do "codec": BCLK = XCK/4, LRCK = BCLK/64 ---
    reg xc = 0; reg bclk = 0; integer bcnt = 0; reg lrck = 1;
    always @(posedge AUD_XCK) begin       // BCLK inverte a cada 2 XCK -> periodo = 4 XCK (3.125 MHz)
        xc <= ~xc;
        if (xc) begin
            bclk <= ~bclk;
            // a cada 32 descidas de BCLK, troca o canal (LRCK)
            if (bclk) begin bcnt <= bcnt + 1; if (bcnt == 31) begin bcnt <= 0; lrck <= ~lrck; end end
        end
    end
    assign AUD_BCLK = bclk; assign AUD_DACLRCK = lrck;

    // --- receptor: decodifica DACDAT e grava o quadro com lrck = 0 ---
    // (mesma logica do receptor do tb_synth_core: 16 bits a partir da 1a subida de BCLK no canal)
    reg lrck_prev = 1; integer nrise = 0, fd; reg [15:0] rsh = 0;
    always @(posedge bclk) begin
        if (lrck !== lrck_prev) begin nrise = 0; lrck_prev = lrck; end
        if (nrise < 16) rsh = {rsh[14:0], AUD_DACDAT};
        nrise = nrise + 1;
        if (nrise == 16 && lrck == 0) $fwrite(fd, "%0d\n", $signed(rsh));
    end

    initial begin
        fd = $fopen("sim/samples_top.txt", "w");
        #100 KEY[0] = 0; #100 KEY[0] = 1;                  // aperta e solta o reset
        #60_000_000;                                       // 60 ms: ~21 ms de espera + ~13 ms de I2C (9 x 1,44 ms) + ~26 ms de som
        $display("LEDG = %b (bit0 = config ok, bit1 = erro ACK)", LEDG);
        $fclose(fd); $finish;
    end
endmodule
