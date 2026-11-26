`timescale 1ns/1ps
// tb_display_7seg.v - passa pelos digitos 0 a 15 e desenha o display na tela (# = segmento aceso).
module tb_display_7seg;
    reg  [3:0] digito;
    wire [6:0] seg;
    integer i;

    display_7seg dut (.digito(digito), .seg(seg));

    // lembrete: aceso = 0
    function [7:0] s(input on); s = on ? "#" : " "; endfunction

    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            digito = i; #10;
            $display("digito %0d (seg = %b)", i, seg);
            $display("  %s%s%s ", s(!seg[0]), s(!seg[0]), s(!seg[0]));
            $display(" %s   %s", s(!seg[5]), s(!seg[1]));
            $display("  %s%s%s ", s(!seg[6]), s(!seg[6]), s(!seg[6]));
            $display(" %s   %s", s(!seg[4]), s(!seg[2]));
            $display("  %s%s%s ", s(!seg[3]), s(!seg[3]), s(!seg[3]));
        end
        $finish;
    end
endmodule
