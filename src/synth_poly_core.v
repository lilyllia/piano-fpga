// =====================================================================================
// synth_poly_core.v - NUCLEO do sintetizador polifonico
// =====================================================================================
//
// Junta os dois blocos que fazem o som:
//
//   notes, wave --> poly_gen --(mix: 1 amostra de 16 bits)--> i2s_tx --> dacdat (para o codec)
//                      ^                                          |
//                      +-------------- sample_tick ---------------+
//
// sample_tick e o "pedido de amostra": o i2s_tx avisa (1 pulso por amostra, 48828 vezes
// por segundo) e o poly_gen calcula a proxima. Assim quem dita o ritmo e o codec.
//
// O som e mono: a mesma amostra vai para o canal esquerdo e para o direito.
// =====================================================================================
module synth_poly_core #(
    // Atenuacao de cada voz antes de somar: cada voz e dividida por 2^VOICE_SHIFT = 8.
    // Pior caso: 8 vozes no volume maximo = 8 * 4096 = 32768, que ainda cabe em 16 bits com sinal.
    // Com 4 (dividir por 16) o som ficava baixo demais na placa; por isso 3.
    // Este valor SOBRESCREVE o padrao (4) declarado dentro do poly_gen.
    parameter VOICE_SHIFT = 3
) (
    input  wire       clk,          // 50 MHz
    input  wire       reset,        // ativo em 1
    input  wire [7:0] notes,        // bit i = nota i ligada (0 = C4 ... 7 = C5)
    input  wire [1:0] wave,         // 0 seno, 1 quadrada, 2 serra, 3 triangular
    input  wire       bclk,         // relogio de bit, vindo do codec
    input  wire       lrck,         // relogio de canal, vindo do codec
    output wire       dacdat        // bits do audio, indo para o codec
);
    wire sample_tick;               // pulso de 1 ciclo: "preciso de uma amostra nova"
    wire signed [15:0] mix;         // a amostra: soma de todas as notas ligadas

    // Gera a amostra a partir das notas ligadas (8 vozes, com envelope ADSR)
    poly_gen #(.VOICE_SHIFT(VOICE_SHIFT)) u_poly (
        .clk(clk), .reset(reset), .sample_en(sample_tick), .active(notes), .wave(wave), .sample(mix));

    // Envia a amostra ao codec, bit a bit, no ritmo do bclk/lrck (mesma amostra nos dois canais)
    i2s_tx u_tx (
        .clk(clk), .reset(reset), .bclk(bclk), .lrck(lrck),
        .sample_l(mix), .sample_r(mix), .dacdat(dacdat), .sample_tick(sample_tick));
endmodule
