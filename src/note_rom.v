// note_rom.v - tabela nota -> phase_inc (incremento do acumulador de fase)
// phase_inc = round(f * 2^24 / 48828.125), fs = 12.5 MHz / 256
module note_rom (
    input  wire [2:0]  note,        // 0..7 = C4 D4 E4 F4 G4 A4 B4 C5
    output reg  [23:0] phase_inc
);
    always @* begin
        case (note)
            3'd0: phase_inc = 24'd89894;    // C4  261.63 Hz
            3'd1: phase_inc = 24'd100902;   // D4  293.66 Hz
            3'd2: phase_inc = 24'd113259;   // E4  329.63 Hz
            3'd3: phase_inc = 24'd119994;   // F4  349.23 Hz
            3'd4: phase_inc = 24'd134689;   // G4  392.00 Hz
            3'd5: phase_inc = 24'd151183;   // A4  440.00 Hz
            3'd6: phase_inc = 24'd169697;   // B4  493.88 Hz
            default: phase_inc = 24'd179788;// C5  523.25 Hz
        endcase
    end
endmodule
