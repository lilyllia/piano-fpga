`timescale 1ns/1ps
// Testbench de melodia: le sim/melodia.txt (linhas "nota onda duracao_ms"; nota 8 = pausa)
// e grava as amostras em sim/samples.txt. Usa tone_gen + note_rom (os mesmos modulos da placa),
// mas entrega um pulso de sample_en por amostra em vez de simular o codec (rapido).
// O serializador e testado a parte em tb_synth_core / tb_top.
module tb_melody;
    reg clk = 0, reset = 1, sample_en = 0;
    reg [2:0] note = 0; reg [1:0] wave = 0; reg silent = 0;
    wire [23:0] inc; wire signed [15:0] s;
    note_rom u_n (.note(note), .phase_inc(inc));
    tone_gen u_t (.clk(clk), .reset(reset), .sample_en(sample_en), .phase_inc(inc), .wave(wave), .sample(s));

    task tick; begin #5 clk = 1; #5 clk = 0; end endtask

    integer fin, fout, r, n, w, ms, nsamp, i;
    real acc;                         // acumulador para manter fs = 48828.125 Hz exato em amostras
    initial begin
        fin  = $fopen("sim/melodia.txt", "r");
        fout = $fopen("sim/samples.txt", "w");
        tick; tick; reset = 0; acc = 0;
        while (!$feof(fin)) begin
            r = $fscanf(fin, "%d %d %d\n", n, w, ms);
            if (r == 3) begin
                silent = (n == 8); note = n[2:0]; wave = w[1:0];
                acc = acc + ms * 48.828125; nsamp = $rtoi(acc); acc = acc - nsamp;
                for (i = 0; i < nsamp; i = i + 1) begin
                    sample_en = 1; tick; sample_en = 0; tick;
                    if (silent) $fwrite(fout, "0\n"); else $fwrite(fout, "%0d\n", s);
                end
            end
        end
        $fclose(fout); $finish;
    end
endmodule
