// =====================================================================================
// wave_gen.v - FORMA DE ONDA a partir da fase (combinacional)
// =====================================================================================
//
// Recebe a fase (onde estamos dentro de um ciclo da onda, de 0 a 2^24-1) e devolve o
// valor da onda naquele ponto, em 16 bits com sinal (-32768 a 32767).
// Pense na fase como um ponteiro de relogio dando voltas: phase[23] diz em qual metade
// da volta estamos, phase[23:16] em qual dos 256 pedacos, e assim por diante.
//
//   wave = 0  seno        : busca o valor numa tabela de 256 pontos (sine_lut)
//   wave = 1  quadrada    : primeira metade +maximo, segunda metade -maximo
//   wave = 2  dente serra : sobe em linha reta durante toda a volta e despenca no fim
//   wave = 3  triangular  : sobe na primeira metade, desce na segunda
//
// O mesmo acumulador de fase serve para as 4 ondas: so muda o jeito de "ler" a fase.
// Timbres diferentes vem dos harmonicos de cada forma (o seno nao tem nenhum; a serra tem todos).
// =====================================================================================
module wave_gen (
    input  wire        [23:0] phase,   // fase atual: 0 = inicio do ciclo, 2^24-1 = fim
    input  wire        [1:0]  wave,    // qual forma de onda
    output reg  signed [15:0] raw      // valor da onda, sem envelope nem volume
);
    // Seno: os 8 bits mais altos da fase escolhem um dos 256 pontos da tabela.
    wire signed [15:0] sine_val;
    sine_lut u_sine (.addr(phase[23:16]), .value(sine_val));

    // Triangular (sem sinal, 0 a 65535): na primeira metade (phase[23]=0) usa os 16 bits
    // seguintes da fase, que crescem; na segunda metade inverte esses bits (~), que entao
    // decrescem. Resultado: sobe e desce, como um triangulo.
    wire [15:0] tri_u = phase[23] ? ~phase[22:7] : phase[22:7];

    always @* begin
        case (wave)
            2'd0:    raw = sine_val;                                // seno
            2'd1:    raw = phase[23] ? -16'sd32767 : 16'sd32767;    // quadrada: so olha a metade do ciclo
            // Serra: os 16 bits altos da fase vao de 0 a 65535 (sem sinal). Inverter o bit 15
            // (^ 16'h8000) desloca para -32768 a 32767 (com sinal), centrando a onda no zero.
            2'd2:    raw = $signed(phase[23:8] ^ 16'h8000);
            default: raw = $signed(tri_u ^ 16'h8000);               // triangular, com o mesmo truque de centrar
        endcase
    end
endmodule
