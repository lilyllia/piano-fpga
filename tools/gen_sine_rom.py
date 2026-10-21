"""Gera src/sine_lut.v: tabela do seno (256 pontos, 16 bits com sinal) como um 'case' em Verilog.
Uso (na raiz do projeto): python3 tools/gen_sine_rom.py
"""
import math
N = 256
with open("src/sine_lut.v", "w") as f:
    f.write("// GERADO por tools/gen_sine_rom.py - nao edite a mao.\n")
    f.write("// Seno de 1 ciclo em 256 pontos, 16 bits com sinal.\n")
    f.write("module sine_lut (input wire [7:0] addr, output reg signed [15:0] value);\n")
    f.write("    always @* begin\n        case (addr)\n")
    for i in range(N):
        v = round(32767 * math.sin(2 * math.pi * i / N))
        f.write("            8'd%d: value = %s16'sd%d;\n" % (i, "-" if v < 0 else "", abs(v)))
    f.write("            default: value = 16'sd0;\n        endcase\n    end\nendmodule\n")
print("src/sine_lut.v gerado")
