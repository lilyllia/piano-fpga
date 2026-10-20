// de1_poly_top.v - topo POLIFONICO para a DE1: cada switch e uma tecla.
// SW[0..7] = C4 D4 E4 F4 G4 A4 B4 C5 (podem ser ligadas varias ao mesmo tempo)
// SW[9]    = liga o som (mestre)
// KEY[2:1] = onda, lida enquanto pressionados {KEY2,KEY1}: solto = seno; KEY1 = quadrada; KEY2 = serra; os dois = triangular
// KEY[0]   = reset
// LEDG[0] = configuracao do codec concluida  LEDG[1] = erro de ACK no I2C
module de1_poly_top (
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,
    input  wire [9:0]  SW,
    output wire [9:0]  LEDR,
    output wire [7:0]  LEDG,
    output wire        I2C_SCLK,
    inout  wire        I2C_SDAT,
    output wire        AUD_XCK,
    input  wire        AUD_BCLK,
    input  wire        AUD_DACLRCK,
    output wire        AUD_DACDAT,
    input  wire        AUD_ADCLRCK,
    input  wire        AUD_ADCDAT
);
    reg [1:0] rs;
    always @(posedge CLOCK_50) rs <= {rs[0], ~KEY[0]};
    wire reset = rs[1];

    reg [1:0] xdiv = 2'd0;
    always @(posedge CLOCK_50) xdiv <= xdiv + 2'd1;
    assign AUD_XCK = xdiv[1];

    wire done, ack_err;
    i2c_config u_cfg (.clk(CLOCK_50), .reset(reset), .i2c_sclk(I2C_SCLK), .i2c_sdat(I2C_SDAT),
                      .done(done), .ack_err(ack_err));

    wire [7:0] notes = (SW[9] & done) ? SW[7:0] : 8'b0;
    wire [1:0] wave  = {~KEY[2], ~KEY[1]};

    synth_poly_core u_synth (.clk(CLOCK_50), .reset(reset), .notes(notes), .wave(wave),
                             .bclk(AUD_BCLK), .lrck(AUD_DACLRCK), .dacdat(AUD_DACDAT));

    assign LEDR = SW;
    assign LEDG = {6'b0, ack_err, done};
endmodule
