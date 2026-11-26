// =====================================================================================
// tb_note_generator.v - TESTBENCH do note_generator (primeira versao)      [LEGADO]
// =====================================================================================
//
// Liga o gerador, toca Do 4 e depois La 4 e desliga. Nao confere nada sozinho: grava as
// formas de onda em piano.vcd para olhar no GTKWave (bom exemplo para aprender a ferramenta).
//
// Rodar, na raiz do projeto:
//   iverilog -o sim/ng.vvp tb/tb_note_generator.v src/note_generator.v
//   vvp sim/ng.vvp
//   gtkwave piano.vcd
//
// Truque de escala: na placa o relogio e 50 MHz e um La tem meio periodo de 56818 ciclos;
// simular isso geraria arquivos enormes. Aqui o modulo e configurado com CLOCK_HZ = 8000,
// entao os meios periodos ficam com poucos ciclos (ex.: La = 8000 / 880 = 9 ciclos) e a
// onda quadrada aparece inteira na tela. O formato da onda e o mesmo; so a escala muda.
// =====================================================================================

`timescale 1ns/1ps

module tb_note_generator;

    reg clk = 0;
    reg reset = 1;
    reg enable = 0;
    reg [2:0] note = 0;

    wire audio_out;

    always #5 clk = ~clk;           // relogio da simulacao: inverte a cada 5 ns (periodo 10 ns)

    // clock mais rápido que o que devemos usar na placa
    // (o modulo "acha" que o relogio e de 8000 Hz; veja o truque de escala no cabecalho)
    note_generator #(
        .CLOCK_HZ(8000)
    ) dut (                         // dut = "device under test", o modulo sendo testado
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .note(note),
        .audio_out(audio_out)
    );

    initial begin
        $dumpfile("piano.vcd");                 // arquivo de ondas para o GTKWave
        $dumpvars(0, tb_note_generator);        // grava todos os sinais deste testbench e de dentro dele

        #20;                                    // espera 20 ns com reset ligado
        reset = 0;
        enable = 1;

        // Testa Dó 4.
        note = 3'd0;
        #2000;

        // Testa Lá 4.
        note = 3'd5;
        #2000;

        enable = 0;                             // desliga: a saida deve ir a 0
        #100;

        $finish;
    end

endmodule
