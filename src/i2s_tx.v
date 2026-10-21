// i2s_tx.v - transmissor de audio para o WM8731 em modo MASTER, left-justified, 16 bits.
// O codec gera BCLK e DACLRCK; aqui so olhamos para eles e colocamos os bits em dacdat.
// Regra do WM8731 (left-justified): o MSB deve estar valido na 1a subida de BCLK apos a
// transicao de DACLRCK; depois, um bit novo por BCLK. LRCK=0 -> canal esquerdo, 1 -> direito.
// sample_tick: pulso (1 ciclo de clk) uma vez por quadro, no inicio do canal esquerdo.
module i2s_tx (
    input  wire               clk,        // 50 MHz
    input  wire               reset,
    input  wire               bclk,
    input  wire               lrck,
    input  wire signed [15:0] sample_l,
    input  wire signed [15:0] sample_r,
    output reg                dacdat,
    output wire               sample_tick
);
    reg [2:0] bs, ls;                      // sincronizadores (2 FF + historico)
    always @(posedge clk) begin
        bs <= {bs[1:0], bclk};
        ls <= {ls[1:0], lrck};
    end
    wire b_rise    = bs[1] & ~bs[2];
    wire b_fall    = ~bs[1] & bs[2];
    wire lrck_edge = ls[1] ^ ls[2];
    assign sample_tick = lrck_edge & ~ls[1];

    reg  [15:0] word;
    reg  [5:0]  cnt;                       // subidas de BCLK desde a transicao do LRCK
    wire [15:0] next_word = ls[1] ? sample_r : sample_l;

    always @(posedge clk) begin
        if (reset) begin
            word <= 16'd0; cnt <= 6'd63; dacdat <= 1'b0;
        end else if (lrck_edge) begin
            word   <= next_word;
            cnt    <= 6'd0;
            dacdat <= next_word[15];
        end else if (b_rise) begin
            if (cnt != 6'd63) cnt <= cnt + 6'd1;
        end else if (b_fall) begin
            dacdat <= (cnt < 6'd16) ? word[15 - cnt] : 1'b0;
        end
    end
endmodule
