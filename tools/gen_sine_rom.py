"""Gera src/sine_lut.v: a tabela do seno (256 pontos, 16 bits com sinal) como um 'case' em Verilog.

Por que um script: escrever 256 valores a mao seria lento e facil de errar. Se um dia a
tabela mudar (mais pontos, outra amplitude), basta mudar aqui e rodar de novo.
Por isso o sine_lut.v NAO deve ser editado a mao: a proxima geracao apagaria a mudanca.

Uso (na raiz do projeto): python3 tools/gen_sine_rom.py
"""
import math

N = 256  # pontos por ciclo; precisa ser 2^8 porque o endereco no Verilog tem 8 bits (phase[23:16])

# Cabecalho do arquivo gerado (comentarios em Verilog explicando a tabela)
CABECALHO = """\
// =====================================================================================
// sine_lut.v - TABELA DO SENO: 1 ciclo do seno em 256 pontos, 16 bits com sinal
// =====================================================================================
// GERADO por tools/gen_sine_rom.py - nao edite a mao (a proxima geracao apagaria a mudanca).
//
// Calcular seno em hardware e caro; guardar os valores prontos numa tabela e barato.
// O endereco (addr) e a posicao dentro do ciclo: 0 = 0 graus, 64 = 90 graus (pico),
// 128 = 180 graus (zero, descendo), 192 = 270 graus (vale). O wave_gen usa os 8 bits
// mais altos da fase como endereco.
//
//   value = round(32767 * sin(2 * pi * addr / 256))
//
// 32767 e o maior valor de 16 bits com sinal, entao o seno ocupa a escala toda.
// E combinacional (always @*): o Quartus transforma o case numa memoria so de leitura (ROM).
// =====================================================================================
"""

with open("src/sine_lut.v", "w") as f:
    f.write(CABECALHO)
    f.write("module sine_lut (input wire [7:0] addr, output reg signed [15:0] value);\n")
    f.write("    always @* begin\n        case (addr)\n")
    for i in range(N):
        v = round(32767 * math.sin(2 * math.pi * i / N))
        # Verilog nao aceita "16'sd-804": o sinal de menos vai na frente do numero (-16'sd804)
        f.write("            8'd%d: value = %s16'sd%d;\n" % (i, "-" if v < 0 else "", abs(v)))
    f.write("            default: value = 16'sd0;\n        endcase\n    end\nendmodule\n")
print("src/sine_lut.v gerado")
