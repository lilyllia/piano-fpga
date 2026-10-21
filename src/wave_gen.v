// wave_gen.v - forma de onda a partir da fase (combinacional).
// wave: 0 = seno (sine_lut), 1 = quadrada, 2 = dente de serra, 3 = triangular. Saida 16 bits com sinal.
module wave_gen (
    input  wire        [23:0] phase,
    input  wire        [1:0]  wave,
    output reg  signed [15:0] raw
);
    wire signed [15:0] sine_val;
    sine_lut u_sine (.addr(phase[23:16]), .value(sine_val));
    wire [15:0] tri_u = phase[23] ? ~phase[22:7] : phase[22:7];
    always @* begin
        case (wave)
            2'd0:    raw = sine_val;
            2'd1:    raw = phase[23] ? -16'sd32767 : 16'sd32767;
            2'd2:    raw = $signed(phase[23:8] ^ 16'h8000);
            default: raw = $signed(tri_u ^ 16'h8000);
        endcase
    end
endmodule
