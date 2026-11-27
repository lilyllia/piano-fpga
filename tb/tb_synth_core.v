`timescale 1ns/1ps
// =====================================================================================
// tb_synth_core.v - TESTBENCH do synth_core com um codec falso             [LEGADO]
// =====================================================================================
//
// Testa a versao monofonica do caminho completo de audio, incluindo o envio bit a bit.
// O testbench faz o papel do WM8731 em modo mestre:
//   - gera BCLK e DACLRCK (como o codec faria);
//   - "escuta" DACDAT exatamente como o codec, montando cada amostra de 16 bits;
//   - grava o quadro com lrck = 0 em sim/samples.txt (um numero com sinal por linha);
//     o som e mono, entao os dois canais tem a mesma amostra.
// Depois, tools/analisa_audio.py mede a frequencia de cada trecho e gera um .wav.
//
// BCLK = 3,125 MHz (50 MHz / 16), LRCK = BCLK/64  =>  fs = 48828,125 Hz, igual a placa.
// Toca 4 trechos de 30 ms: La seno, Do5 seno, La quadrada, La triangular.
// =====================================================================================
module tb_synth_core;
    reg clk = 0, reset = 1, enable = 0;
    reg [2:0] note = 3'd5;
    reg [1:0] wave = 2'd0;
    always #10 clk = ~clk;                 // 50 MHz (periodo de 20 ns)

    // --- "codec": gerador de BCLK e LRCK ---
    reg bclk = 0, lrck = 1;
    integer bdiv = 0, bcnt = 0;
    always @(posedge clk) begin            // BCLK: alterna a cada 8 ciclos de clk (periodo = 16 ciclos)
        bdiv <= bdiv + 1;
        if (bdiv == 7) begin
            bdiv <= 0;
            bclk <= ~bclk;
            if (bclk) begin                // era 1 -> vai a 0: borda de descida
                bcnt <= bcnt + 1;
                if (bcnt == 31) begin bcnt <= 0; lrck <= ~lrck; end  // LRCK muda na descida, a cada 32 pulsos
            end
        end
    end

    wire dacdat;
    synth_core dut (.clk(clk), .reset(reset), .enable(enable), .note(note), .wave(wave),
                    .bclk(bclk), .lrck(lrck), .dacdat(dacdat));

    // --- "codec": receptor ---
    // Amostra DACDAT a cada subida de BCLK; o MSB vem na 1a subida apos a transicao do LRCK.
    // Junta 16 bits e, se for o quadro com lrck = 0, grava a amostra.
    reg lrck_prev = 1;
    integer nrise = 0, fd;
    reg [15:0] sh = 0;                     // registrador de deslocamento que monta a amostra
    always @(posedge bclk) begin
        if (lrck !== lrck_prev) begin nrise = 0; lrck_prev = lrck; end   // comecou um canal
        if (nrise < 16) sh = {sh[14:0], dacdat};                        // empurra o bit novo
        nrise = nrise + 1;
        if (nrise == 16 && lrck == 0) $fwrite(fd, "%0d\n", $signed(sh));
    end

    // Toca a nota n com a onda w por ms milissegundos
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
