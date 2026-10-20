// tone_gen.v - gerador de tom com acumulador de fase (DDS), uma voz.
// A cada sample_en (uma vez por amostra de audio) a fase avanca phase_inc.
// frequencia = phase_inc * fs / 2^24.  A saida e atenuada por ATT_SHIFT bits (3 = -18 dB).
module tone_gen #(
    parameter ATT_SHIFT = 3
) (
    input  wire               clk,
    input  wire               reset,
    input  wire               sample_en,
    input  wire        [23:0] phase_inc,
    input  wire        [1:0]  wave,
    output reg  signed [15:0] sample
);
    reg [23:0] phase;
    always @(posedge clk) begin
        if (reset)          phase <= 24'd0;
        else if (sample_en) phase <= phase + phase_inc;
    end

    wire signed [15:0] raw;
    wave_gen u_wave (.phase(phase), .wave(wave), .raw(raw));

    always @(posedge clk) sample <= raw >>> ATT_SHIFT;
endmodule
