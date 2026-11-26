// =====================================================================================
// synth_core.v - NUCLEO da versao MONOFONICA (uma nota por vez)           [LEGADO]
// =====================================================================================
//
// SITUACAO: usado so pelo de1_synth_top.v (versao antiga). A versao atual usa o
// synth_poly_core.v, que troca o tone_gen pelo poly_gen (8 vozes + envelope).
//
//   note --> note_rom --(phase_inc)--> tone_gen --(tone)--> [enable?] --> i2s_tx --> dacdat
//                                         ^                                  |
//                                         +----------- sample_tick ----------+
//
// fs real = XCK/256 (XCK = 12,5 MHz -> 48828,125 Hz). Os phase_inc da note_rom foram
// calculados para esse fs, entao as notas saem afinadas em Hz reais:
//   phase_inc = round(f * 2^24 / 48828,125)
// =====================================================================================
module synth_core #(
    parameter ATT_SHIFT = 3         // atenuacao da onda: divide por 2^3 = 8 (cerca de -18 dB)
) (
    input  wire       clk,          // 50 MHz
    input  wire       reset,        // ativo em 1
    input  wire       enable,       // 1 = toca a nota; 0 = silencio
    input  wire [2:0] note,         // 0..7 = C4 D4 E4 F4 G4 A4 B4 C5
    input  wire [1:0] wave,         // 0 seno, 1 quadrada, 2 serra, 3 triangular
    input  wire       bclk,         // vindo do codec (AUD_BCLK)
    input  wire       lrck,         // vindo do codec (AUD_DACLRCK)
    output wire       dacdat        // para o codec (AUD_DACDAT)
);
    // Nota -> incremento de fase
    wire [23:0] phase_inc;
    note_rom u_notes (.note(note), .phase_inc(phase_inc));

    // Gerador de uma voz: avanca a fase a cada pedido de amostra e devolve o valor da onda
    wire sample_tick;
    wire signed [15:0] tone;
    tone_gen #(.ATT_SHIFT(ATT_SHIFT)) u_tone (
        .clk(clk), .reset(reset), .sample_en(sample_tick),
        .phase_inc(phase_inc), .wave(wave), .sample(tone)
    );

    // Sem envelope: com enable = 0 a saida vai direto a zero (por isso da um "clique" ao soltar)
    wire signed [15:0] out = enable ? tone : 16'sd0;

    // Envia a amostra ao codec (mesma nos dois canais) e pede a proxima com sample_tick
    i2s_tx u_tx (
        .clk(clk), .reset(reset), .bclk(bclk), .lrck(lrck),
        .sample_l(out), .sample_r(out), .dacdat(dacdat), .sample_tick(sample_tick)
    );
endmodule
