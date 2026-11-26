// =====================================================================================
// note_generator.v - PRIMEIRO GERADOR DE NOTAS: onda quadrada de 1 bit   [LEGADO]
// =====================================================================================
//
// SITUACAO: primeira versao do projeto. Nao e usado pela placa nem por nenhum outro
// modulo; so pelo tb/tb_note_generator.v. Serve como exemplo simples para treinar
// simulacao e GTKWave.
//
// COMO FUNCIONA: um contador conta ciclos de relogio. Ao chegar em meio periodo da nota,
// zera e inverte a saida. Inverter a cada meio periodo da uma onda quadrada na frequencia
// da nota:
//   meio periodo (em ciclos) = CLOCK_HZ / (2 * frequencia)
//   Ex.: La 440 Hz com 50 MHz -> 50.000.000 / 880 = 56818 ciclos em 1, 56818 em 0.
//
// POR QUE FOI SUBSTITUIDO: a saida e 1 bit (so "ligado/desligado"), que nao serve para o
// codec de audio da DE1 (ele espera amostras de 16 bits pelo i2s_tx); nao permite outras
// formas de onda; e as frequencias sao inteiras (262 Hz em vez de 261,63 Hz).
// A versao atual usa acumulador de fase (note_rom + wave_gen + poly_gen).
// =====================================================================================
module note_generator #(
    parameter integer CLOCK_HZ = 50_000_000     // frequencia do relogio; o testbench usa um valor menor
)(
    input  wire       clk,
    input  wire       reset,        // ativo em 1
    input  wire       enable,       // 1 = toca; 0 = silencio
    input  wire [2:0] note,         // 0..7 = C4 D4 E4 F4 G4 A4 B4 C5
    output reg        audio_out     // onda quadrada de 1 bit
);

    reg [31:0] counter;             // ciclos desde a ultima inversao
    reg [31:0] half_period;         // meio periodo da nota escolhida, em ciclos

    // Tabela nota -> meio periodo (combinacional). As divisoes sao feitas pelo
    // compilador, porque CLOCK_HZ e as frequencias sao constantes.
    always @(*) begin
        case (note)
            3'd0: half_period = CLOCK_HZ / (2 * 262); // C4
            3'd1: half_period = CLOCK_HZ / (2 * 294); // D4
            3'd2: half_period = CLOCK_HZ / (2 * 330); // E4
            3'd3: half_period = CLOCK_HZ / (2 * 349); // F4
            3'd4: half_period = CLOCK_HZ / (2 * 392); // G4
            3'd5: half_period = CLOCK_HZ / (2 * 440); // A4
            3'd6: half_period = CLOCK_HZ / (2 * 494); // B4
            3'd7: half_period = CLOCK_HZ / (2 * 523); // C5
            default: half_period = CLOCK_HZ / (2 * 262);
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin                            // reset: zera tudo
            counter   <= 0;
            audio_out <= 0;
        end
        else if (!enable) begin                     // desligado: silencio, contador parado em 0
            counter   <= 0;
            audio_out <= 0;
        end
        else if (counter >= half_period - 1) begin  // completou meio periodo: inverte a saida
            counter   <= 0;
            audio_out <= ~audio_out;
        end
        else begin                                  // senao, so conta
            counter <= counter + 1'b1;
        end
    end

endmodule
