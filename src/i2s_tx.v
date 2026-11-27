// =====================================================================================
// i2s_tx.v - TRANSMISSOR DE AUDIO para o codec WM8731 (formato left-justified, 16 bits)
// =====================================================================================
//
// O QUE FAZ: pega uma amostra de 16 bits e manda para o codec um bit por vez, pelo fio
// dacdat, no ritmo dos relogios que o PROPRIO CODEC gera (ele esta em modo mestre).
//
// OS SINAIS DO CODEC:
//   bclk (relogio de bit, 3,125 MHz): o codec le um bit de dacdat a cada SUBIDA de bclk.
//   lrck (relogio de canal, 48828,125 Hz): muda a cada canal. No formato left-justified com
//   LRP = 0 (como o i2c_config configura), 1 = canal esquerdo e 0 = canal direito
//   (folha de dados do WM8731, bit LRP do registrador R7; no I2S da Philips e o contrario).
//   Cada canal dura 32 pulsos de bclk; so os 16 primeiros carregam a amostra.
//
//   lrck  ___________________________________|""""""""""""""""""""""""""""""""""
//   bclk  _|"|_|"|_|"|_|"|_ ... (32 pulsos)    _|"|_|"|_|"|_ ...
//   dados  [b15][b14][b13] ... [b0] 0 0 0 ...   [b15][b14] ...   (direito | esquerdo)
//
// REGRA DO WM8731 (left-justified): o bit mais significativo (b15) ja precisa estar no fio
// na 1a subida de bclk depois que lrck muda; depois, um bit novo por subida.
// Para isso, este modulo poe o bit novo na DESCIDA de bclk: quando vem a subida seguinte,
// o bit ja esta estavel ha meio periodo.
//
// O fpga nao usa bclk e lrck como relogio: eles sao amostrados com o relogio de 50 MHz,
// e as bordas sao detectadas comparando o valor atual com o anterior. 50 MHz e 16 vezes
// mais rapido que bclk, entao nenhuma borda se perde.
//
// sample_tick: pulso de 1 ciclo quando lrck desce para 0 (1 por amostra; pela folha de dados,
// e o inicio do canal direito).
// O synth_poly_core usa esse pulso para pedir ao poly_gen a proxima amostra, que ficara
// pronta bem antes do proximo quadro (a amostra enviada e sempre a calculada no quadro anterior).
// =====================================================================================
module i2s_tx (
    input  wire               clk,        // 50 MHz
    input  wire               reset,      // ativo em 1
    input  wire               bclk,       // relogio de bit, vindo do codec
    input  wire               lrck,       // relogio de canal, vindo do codec (1 esquerdo, 0 direito)
    input  wire signed [15:0] sample_l,   // amostra enviada com lrck = 0 (nome herdado do I2S; e o canal direito)
    input  wire signed [15:0] sample_r,   // amostra enviada com lrck = 1 (nome herdado do I2S; e o canal esquerdo)
    output reg                dacdat,     // bit atual do audio, para o codec
    output wire               sample_tick // pulso: lrck desceu, comecou um quadro novo
);
    // ---------------------------------------------------------------------------------
    // SINCRONIZACAO E DETECCAO DE BORDAS
    // bs e ls sao registradores de deslocamento de 3 bits. A cada ciclo entra o valor novo
    // na posicao 0. bs[0] e bs[1] formam o sincronizador de 2 flip-flops (contra
    // metaestabilidade); bs[2] e o valor de bs[1] no ciclo anterior, usado para ver bordas.
    // ---------------------------------------------------------------------------------
    reg [2:0] bs, ls;
    always @(posedge clk) begin
        bs <= {bs[1:0], bclk};
        ls <= {ls[1:0], lrck};
    end
    wire b_rise    = bs[1] & ~bs[2];      // bclk era 0 e agora e 1: subida
    wire b_fall    = ~bs[1] & bs[2];      // bclk era 1 e agora e 0: descida
    wire lrck_edge = ls[1] ^ ls[2];       // lrck mudou (qualquer direcao): comecou um canal
    assign sample_tick = lrck_edge & ~ls[1];  // mudou e agora vale 0: 1 pulso por amostra
    // (sample_l e sample_r recebem a mesma amostra, entao a troca de nomes nao muda o som)

    reg  [15:0] word;                      // amostra sendo enviada neste canal
    reg  [5:0]  cnt;                       // quantas subidas de bclk desde a mudanca de lrck (para em 63)
    wire [15:0] next_word = ls[1] ? sample_r : sample_l;   // qual canal comeca agora

    always @(posedge clk) begin
        if (reset) begin
            word <= 16'd0; cnt <= 6'd63; dacdat <= 1'b0;   // cnt=63: "fora da amostra", manda zeros
        end else if (lrck_edge) begin
            // Comecou um canal: carrega a amostra e ja poe o b15 no fio,
            // para ele estar valido na 1a subida de bclk.
            word   <= next_word;
            cnt    <= 6'd0;
            dacdat <= next_word[15];
        end else if (b_rise) begin
            // Subida: o codec acabou de ler o bit atual. Conta mais um (sem passar de 63).
            if (cnt != 6'd63) cnt <= cnt + 6'd1;
        end else if (b_fall) begin
            // Descida: prepara o proximo bit. Depois de cnt subidas, o proximo e o b(15-cnt).
            // Passados os 16 bits, manda 0 ate o fim do canal.
            dacdat <= (cnt < 6'd16) ? word[15 - cnt] : 1'b0;
        end
    end
endmodule
