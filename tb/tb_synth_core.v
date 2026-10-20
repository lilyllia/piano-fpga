`timescale 1ns/1ps
// Testbench: imita o WM8731 em modo master (gera BCLK e DACLRCK) e grava o que o codec
// receberia em sim/samples.txt (um valor inteiro com sinal por linha, canal esquerdo).
// BCLK = 3.125 MHz (50 MHz / 16), LRCK = BCLK/64  =>  fs = 48828.125 Hz.
module tb_synth_core;
    reg clk = 0, reset = 1, enable = 0;
    reg [2:0] note = 3'd5;
    reg [1:0] wave = 2'd0;
    always #10 clk = ~clk;                 // 50 MHz

    reg bclk = 0, lrck = 1;
    integer bdiv = 0, bcnt = 0;
    always @(posedge clk) begin            // BCLK: alterna a cada 8 ciclos de clk
        bdiv <= bdiv + 1;
        if (bdiv == 7) begin
            bdiv <= 0;
            bclk <= ~bclk;
            if (bclk) begin                // era 1 -> vai a 0: borda de descida
                bcnt <= bcnt + 1;
                if (bcnt == 31) begin bcnt <= 0; lrck <= ~lrck; end  // LRCK muda na descida
            end
        end
    end

    wire dacdat;
    synth_core dut (.clk(clk), .reset(reset), .enable(enable), .note(note), .wave(wave),
                    .bclk(bclk), .lrck(lrck), .dacdat(dacdat));

    // "codec": amostra DACDAT a cada subida de BCLK; MSB na 1a subida apos a transicao do LRCK
    reg lrck_prev = 1;
    integer nrise = 0, fd;
    reg [15:0] sh = 0;
    always @(posedge bclk) begin
        if (lrck !== lrck_prev) begin nrise = 0; lrck_prev = lrck; end
        if (nrise < 16) sh = {sh[14:0], dacdat};
        nrise = nrise + 1;
        if (nrise == 16 && lrck == 0) $fwrite(fd, "%0d\n", $signed(sh));
    end

    task play(input [2:0] n, input [1:0] w, input integer ms);
        begin note = n; wave = w; enable = 1; #(ms * 1000000); end
    endtask

    initial begin
        fd = $fopen("sim/samples.txt", "w");
        #200 reset = 0;
        play(3'd5, 2'd0, 30);   // A4 seno
        play(3'd7, 2'd0, 30);   // C5 seno
        play(3'd5, 2'd1, 30);   // A4 quadrada
        play(3'd5, 2'd3, 30);   // A4 triangular
        $fclose(fd);
        $finish;
    end
endmodule
