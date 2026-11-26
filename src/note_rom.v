// =====================================================================================
// note_rom.v - tabela NOTA -> INCREMENTO DE FASE
// =====================================================================================
//
// Cada nota e uma frequencia. O gerador de som (DDS) nao trabalha com Hz: ele tem um
// acumulador de fase de 24 bits que soma um "incremento" a cada amostra. Quando o
// acumulador da a volta (passa de 2^24 e recomeca), completou um ciclo da onda.
// Incremento maior = volta mais rapido = som mais agudo.
//
//   incremento = round(f * 2^24 / fs)      com fs = 12,5 MHz / 256 = 48828,125 Hz
//
// Exemplo (La 4): 440 * 16777216 / 48828,125 = 151182,7 -> 151183.
// As frequencias sao as da afinacao temperada (La = 440 Hz, cada semitom x 2^(1/12)).
// O erro de arredondamento e menor que 0,003 Hz em todas as notas.
//
// E logica combinacional pura (always @*): nao tem relogio nem memoria; a saida muda
// assim que a entrada muda. O Quartus transforma o case numa pequena tabela.
// =====================================================================================
module note_rom (
    input  wire [2:0]  note,        // 0..7 = C4 D4 E4 F4 G4 A4 B4 C5
    output reg  [23:0] phase_inc    // incremento do acumulador de fase para essa nota
);
    always @* begin
        case (note)
            3'd0: phase_inc = 24'd89894;    // C4 (Do)   261,63 Hz
            3'd1: phase_inc = 24'd100902;   // D4 (Re)   293,66 Hz
            3'd2: phase_inc = 24'd113259;   // E4 (Mi)   329,63 Hz
            3'd3: phase_inc = 24'd119994;   // F4 (Fa)   349,23 Hz
            3'd4: phase_inc = 24'd134689;   // G4 (Sol)  392,00 Hz
            3'd5: phase_inc = 24'd151183;   // A4 (La)   440,00 Hz
            3'd6: phase_inc = 24'd169697;   // B4 (Si)   493,88 Hz
            default: phase_inc = 24'd179788;// C5 (Do)   523,25 Hz (nota 7; default cobre qualquer outro valor)
        endcase
    end
endmodule
