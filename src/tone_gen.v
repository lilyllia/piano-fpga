// =====================================================================================
// tone_gen.v - GERADOR DE UMA VOZ com acumulador de fase (DDS)            [LEGADO]
// =====================================================================================
//
// SITUACAO: usado pela versao monofonica (synth_core) e pelo tb_melody/tools/tocar.py.
// A versao atual faz o mesmo calculo dentro do poly_gen, para 8 vozes.
//
// DDS (sintese digital direta) em uma frase: um contador de 24 bits (a fase) soma
// phase_inc a cada amostra; quando passa de 2^24 ele "da a volta", e cada volta e um ciclo
// da onda. Logo:
//   frequencia = phase_inc * fs / 2^24
// Ex.: phase_inc = 151183 -> 151183 * 48828,125 / 16777216 = 440,0 Hz (La).
//
// A saida e atenuada por ATT_SHIFT bits (3 = dividir por 8, cerca de -18 dB) para nao
// sair alto demais no fone.
// =====================================================================================
module tone_gen #(
    parameter ATT_SHIFT = 3
) (
    input  wire               clk,        // 50 MHz
    input  wire               reset,      // ativo em 1
    input  wire               sample_en,  // pulso: avance uma amostra
    input  wire        [23:0] phase_inc,  // quanto a fase anda por amostra (vem da note_rom)
    input  wire        [1:0]  wave,       // forma de onda
    output reg  signed [15:0] sample      // amostra atenuada
);
    // Acumulador de fase: soma o incremento uma vez por amostra.
    // A soma estoura naturalmente em 2^24 e volta ao inicio: e exatamente o "dar a volta".
    reg [23:0] phase;
    always @(posedge clk) begin
        if (reset)          phase <= 24'd0;
        else if (sample_en) phase <= phase + phase_inc;
    end

    // Fase -> valor da onda (seno, quadrada, serra ou triangular)
    wire signed [15:0] raw;
    wave_gen u_wave (.phase(phase), .wave(wave), .raw(raw));

    // Atenua: >>> e o deslocamento aritmetico, que divide preservando o sinal
    always @(posedge clk) sample <= raw >>> ATT_SHIFT;
endmodule
