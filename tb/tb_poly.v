`timescale 1ns/1ps
// =====================================================================================
// tb_poly.v - TESTBENCH do poly_gen: transforma uma "partitura" em amostras de audio
// =====================================================================================
//
// Um testbench so existe na simulacao (nunca vai para a placa). Este aqui:
//   1. le sim/poly.txt, uma linha por trecho: "mascara_de_notas onda duracao_ms"
//      (mascara = vetor de 8 bits em decimal; ex.: 21 = 00010101 = C4 + E4 + G4)
//   2. para cada trecho, liga essas notas no poly_gen e pede o numero certo de amostras
//   3. grava cada amostra em sim/samples.txt (um numero por linha)
// O tools/poly.py escreve o poly.txt, roda este testbench e converte samples.txt em .wav,
// para OUVIR o resultado no computador.
//
// Usa o poly_gen de verdade (o mesmo arquivo da placa), mas sem o codec: em vez de esperar
// o i2s_tx, o proprio testbench da o pulso de sample_en. Isso deixa a simulacao rapida.
//
// ATENCAO: aqui o poly_gen e instanciado sem parametros, entao usa VOICE_SHIFT = 4
// (o padrao). Na placa o synth_poly_core usa 3. Resultado: o .wav sai com metade do
// volume da placa. O formato do som e o mesmo.
// =====================================================================================
module tb_poly;
    reg clk = 0, reset = 1, sample_en = 0;
    reg [7:0] active = 0; reg [1:0] wave = 0;     // entradas do poly_gen
    wire signed [15:0] s;                         // amostra que sai dele
    poly_gen u (.clk(clk), .reset(reset), .sample_en(sample_en), .active(active), .wave(wave), .sample(s));

    // Um ciclo de relogio "na mao" (10 ns). O tempo simulado nao precisa ser o real:
    // so importa a ordem dos eventos e a quantidade de amostras.
    task tick; begin #5 clk = 1; #5 clk = 0; end endtask

    integer fin, fout, r, m, w, ms, nsamp, i, j, maxbusy;
    real acc;                                     // sobra fracionaria de amostras (ver abaixo)
    initial begin
        fin = $fopen("sim/poly.txt", "r"); fout = $fopen("sim/samples.txt", "w");
        tick; tick; reset = 0; acc = 0;           // 2 ciclos com reset e solta
        while (!$feof(fin)) begin
            r = $fscanf(fin, "%d %d %d\n", m, w, ms);   // r = quantos numeros conseguiu ler
            if (r == 3) begin
                active = m[7:0]; wave = w[1:0];
                // Quantas amostras cabem em ms milissegundos: ms * 48,828125.
                // Como nao e inteiro, a parte fracionaria fica guardada em acc e entra no
                // proximo trecho; assim a duracao total nao vai atrasando.
                acc = acc + ms * 48.828125; nsamp = $rtoi(acc); acc = acc - nsamp;
                for (i = 0; i < nsamp; i = i + 1) begin
                    sample_en = 1; tick; sample_en = 0;          // pede uma amostra
                    for (j = 0; j < 36; j = j + 1) tick;      // espera a varredura (32 ciclos) + folga
                    $fwrite(fout, "%0d\n", s);                   // grava a amostra pronta
                end
            end
        end
        $fclose(fout); $finish;
    end
endmodule
