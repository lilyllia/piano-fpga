// synth_core.v - nucleo do sintetizador: seleciona nota, gera amostra e serializa para o codec.
// fs real = XCK/256 (XCK = 12.5 MHz -> 48828.125 Hz). Os phase_inc abaixo foram calculados
// para esse fs, entao as notas saem afinadas em Hz reais.
// phase_inc = round(f * 2^24 / 48828.125)
module synth_core #(
    parameter ATT_SHIFT = 3
) (
    input  wire       clk,
    input  wire       reset,
    input  wire       enable,       // 1 = toca a nota
    input  wire [2:0] note,         // 0..7 = C4 D4 E4 F4 G4 A4 B4 C5
    input  wire [1:0] wave,         // 0 seno, 1 quadrada, 2 serra, 3 triangular
    input  wire       bclk,         // vindo do codec (AUD_BCLK)
    input  wire       lrck,         // vindo do codec (AUD_DACLRCK)
    output wire       dacdat        // para o codec (AUD_DACDAT)
);
    wire [23:0] phase_inc;
    note_rom u_notes (.note(note), .phase_inc(phase_inc));

    wire sample_tick;
    wire signed [15:0] tone;
    tone_gen #(.ATT_SHIFT(ATT_SHIFT)) u_tone (
        .clk(clk), .reset(reset), .sample_en(sample_tick),
        .phase_inc(phase_inc), .wave(wave), .sample(tone)
    );

    wire signed [15:0] out = enable ? tone : 16'sd0;

    i2s_tx u_tx (
        .clk(clk), .reset(reset), .bclk(bclk), .lrck(lrck),
        .sample_l(out), .sample_r(out), .dacdat(dacdat), .sample_tick(sample_tick)
    );
endmodule
