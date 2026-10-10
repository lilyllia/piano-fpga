
`timescale 1ns/1ps

module tb_note_generator;

    reg clk = 0;
    reg reset = 1;
    reg enable = 0;
    reg [2:0] note = 0;

    wire audio_out;

    always #5 clk = ~clk;

    // clock mais rápido que o que devemos usar na placa
    note_generator #(
        .CLOCK_HZ(8000)
    ) dut (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .note(note),
        .audio_out(audio_out)
    );

    initial begin
        $dumpfile("piano.vcd");
        $dumpvars(0, tb_note_generator);

        #20;
        reset = 0;
        enable = 1;

        // Testa Dó 4.
        note = 3'd0;
        #2000;

        // Testa Lá 4.
        note = 3'd5;
        #2000;

        enable = 0;
        #100;

        $finish;
    end

endmodule
