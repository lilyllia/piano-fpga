// de1_synth_top.v - topo para a placa DE1 (Cyclone II EP2C20F484C7).
// Controles:  SW[2:0] = nota (C4..C5)   SW[3] = toca   SW[5:4] = onda (0 seno, 1 quadrada, 2 serra, 3 triangular)
//             KEY[0]  = reset (aperte para reiniciar; solto = funcionando)
// LEDs verdes:  LEDG[0] = configuracao do codec concluida   LEDG[1] = erro de ACK no I2C
// LEDR[9:0]    = espelho de SW[9:0]
module de1_synth_top (
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
    input  wire        AUD_ADCLRCK,    // nao usados, mas declarados para o pinout ficar completo
    input  wire        AUD_ADCDAT
);
    // reset: KEY[0] (ativo em 0) sincronizado
    reg [1:0] rs;
    always @(posedge CLOCK_50) rs <= {rs[0], ~KEY[0]};
    wire reset = rs[1];

    // XCK = 50 MHz / 4 = 12.5 MHz  ->  fs = XCK/256 = 48828.125 Hz (o codec gera BCLK e LRCK a partir dele)
    reg [1:0] xdiv = 2'd0;
    always @(posedge CLOCK_50) xdiv <= xdiv + 2'd1;
    assign AUD_XCK = xdiv[1];

    wire done, ack_err;
    i2c_config u_cfg (.clk(CLOCK_50), .reset(reset), .i2c_sclk(I2C_SCLK), .i2c_sdat(I2C_SDAT),
                      .done(done), .ack_err(ack_err));

    synth_core u_synth (.clk(CLOCK_50), .reset(reset), .enable(SW[3] & done), .note(SW[2:0]),
                        .wave(SW[5:4]), .bclk(AUD_BCLK), .lrck(AUD_DACLRCK), .dacdat(AUD_DACDAT));

    assign LEDR = SW;
    assign LEDG = {6'b0, ack_err, done};
endmodule
