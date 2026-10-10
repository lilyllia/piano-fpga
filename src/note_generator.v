
module note_generator #(
    parameter integer CLOCK_HZ = 50_000_000
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       enable,
    input  wire [2:0] note,
    output reg        audio_out
);

    reg [31:0] counter;
    reg [31:0] half_period;

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
        if (reset) begin
            counter   <= 0;
            audio_out <= 0;
        end
        else if (!enable) begin
            counter   <= 0;
            audio_out <= 0;
        end
        else if (counter >= half_period - 1) begin
            counter   <= 0;
            audio_out <= ~audio_out;
        end
        else begin
            counter <= counter + 1'b1;
        end
    end

endmodule
