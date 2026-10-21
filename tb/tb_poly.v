`timescale 1ns/1ps
// Le sim/poly.txt (linhas "mascara_de_notas onda duracao_ms") e grava sim/samples.txt.
// Usa poly_gen (o mesmo modulo da placa); entrega um sample_en por amostra e espera o termino da varredura.
module tb_poly;
    reg clk = 0, reset = 1, sample_en = 0;
    reg [7:0] active = 0; reg [1:0] wave = 0;
    wire signed [15:0] s;
    poly_gen u (.clk(clk), .reset(reset), .sample_en(sample_en), .active(active), .wave(wave), .sample(s));
    task tick; begin #5 clk = 1; #5 clk = 0; end endtask
    integer fin, fout, r, m, w, ms, nsamp, i, j, maxbusy;
    real acc;
    initial begin
        fin = $fopen("sim/poly.txt", "r"); fout = $fopen("sim/samples.txt", "w");
        tick; tick; reset = 0; acc = 0;
        while (!$feof(fin)) begin
            r = $fscanf(fin, "%d %d %d\n", m, w, ms);
            if (r == 3) begin
                active = m[7:0]; wave = w[1:0];
                acc = acc + ms * 48.828125; nsamp = $rtoi(acc); acc = acc - nsamp;
                for (i = 0; i < nsamp; i = i + 1) begin
                    sample_en = 1; tick; sample_en = 0;
                    for (j = 0; j < 36; j = j + 1) tick;      // 32 ciclos de varredura + folga
                    $fwrite(fout, "%0d\n", s);
                end
            end
        end
        $fclose(fout); $finish;
    end
endmodule
