// synth_poly_core.v - nucleo polifonico: 8 notas simultaneas -> serializador I2S.
module synth_poly_core #(
    parameter VOICE_SHIFT = 3       // cada voz /8 antes de somar: 8 vozes no maximo = 8*4096 = 32768, cabe em 16 bits (era 4, baixo demais na placa)
) (
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] notes,        // bit i = nota i ligada (0 = C4 ... 7 = C5)
    input  wire [1:0] wave,
    input  wire       bclk,
    input  wire       lrck,
    output wire       dacdat
);
    wire sample_tick;
    wire signed [15:0] mix;
    poly_gen #(.VOICE_SHIFT(VOICE_SHIFT)) u_poly (
        .clk(clk), .reset(reset), .sample_en(sample_tick), .active(notes), .wave(wave), .sample(mix));
    i2s_tx u_tx (
        .clk(clk), .reset(reset), .bclk(bclk), .lrck(lrck),
        .sample_l(mix), .sample_r(mix), .dacdat(dacdat), .sample_tick(sample_tick));
endmodule
