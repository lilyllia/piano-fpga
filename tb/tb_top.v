`timescale 1ns/1ps
// Testbench do topo: modelo simples do WM8731 (escravo I2C que da ACK + gerador de BCLK/LRCK a partir do XCK).
module tb_top;
    reg CLOCK_50 = 0; always #10 CLOCK_50 = ~CLOCK_50;
    reg [3:0] KEY = 4'b1111; reg [9:0] SW = 10'b00_0000_1101;   // nota 5 (A4), toca=1, seno
    wire [9:0] LEDR; wire [7:0] LEDG;
    wire I2C_SCLK, AUD_XCK, AUD_DACDAT;
    tri1 I2C_SDAT;                                  // resistor de pull-up
    wire AUD_BCLK, AUD_DACLRCK;

    de1_synth_top dut (.CLOCK_50(CLOCK_50), .KEY(KEY), .SW(SW), .LEDR(LEDR), .LEDG(LEDG),
        .I2C_SCLK(I2C_SCLK), .I2C_SDAT(I2C_SDAT), .AUD_XCK(AUD_XCK), .AUD_BCLK(AUD_BCLK),
        .AUD_DACLRCK(AUD_DACLRCK), .AUD_DACDAT(AUD_DACDAT), .AUD_ADCLRCK(1'b0), .AUD_ADCDAT(1'b0));

    // --- escravo I2C (so ACK + grava os bytes) ---
    integer bitn = 0, nbyte = 0; reg [7:0] sh; reg ack_drive = 0; reg [7:0] b0, b1, b2;
    assign I2C_SDAT = ack_drive ? 1'b0 : 1'bz;
    reg started = 0;
    always @(negedge I2C_SDAT) if (I2C_SCLK) begin started = 1; bitn = 0; nbyte = 0; end
    always @(posedge I2C_SDAT) if (I2C_SCLK) begin started = 0; end
    always @(posedge I2C_SCLK) if (started) begin
        if (bitn < 8) begin sh = {sh[6:0], I2C_SDAT}; bitn = bitn + 1; end
        else bitn = bitn + 1;                              // 9o pulso = ACK
    end
    always @(negedge I2C_SCLK) if (started) begin
        if (bitn == 8) ack_drive = 1;                      // puxa SDA em baixo para dar ACK
        else if (bitn == 9) begin
            ack_drive = 0; bitn = 0;
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
            if (bclk) begin bcnt <= bcnt + 1; if (bcnt == 31) begin bcnt <= 0; lrck <= ~lrck; end end
        end
    end
    assign AUD_BCLK = bclk; assign AUD_DACLRCK = lrck;

    // --- receptor: decodifica DACDAT e grava o canal esquerdo ---
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
        #60_000_000;                                       // 60 ms
        $display("LEDG = %b (bit0 = config ok, bit1 = erro ACK)", LEDG);
        $fclose(fd); $finish;
    end
endmodule
