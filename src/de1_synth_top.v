// =====================================================================================
// de1_synth_top.v - TOPO da versao MONOFONICA (uma nota por vez)          [LEGADO]
// =====================================================================================
//
// SITUACAO: versao anterior ao de1_poly_top.v. Nao e a que vai para a placa hoje; fica no
// projeto como referencia e porque e mais simples de estudar (sem polifonia nem envelope).
// Projeto Quartus dela: quartus/de1_synth.qsf. Testbench: tb/tb_top.v.
//
// Placa: DE1 (Cyclone II EP2C20F484C7).
// CAMINHO DO SOM:  SW[2:0] (nota) --> synth_core (note_rom + tone_gen + i2s_tx) --> codec --> fone
//
// CONTROLES:  SW[2:0] = nota (0..7 = C4..C5)   SW[3] = toca   SW[5:4] = onda (0 seno, 1 quadrada, 2 serra, 3 triangular)
//             KEY[0]  = reset (aperte para reiniciar; solto = funcionando)
// LEDS:       LEDG[0] = configuracao do codec concluida   LEDG[1] = erro de ACK no I2C
//             LEDR[9:0] = espelho de SW[9:0]
//
// Reset, relogio do codec e configuracao por I2C sao identicos ao de1_poly_top.v
// (os comentarios detalhados estao la).
// =====================================================================================
module de1_synth_top (
    input  wire        CLOCK_50,       // relogio de 50 MHz da placa
    input  wire [3:0]  KEY,            // botoes (0 = apertado)
    input  wire [9:0]  SW,             // chaves (1 = ligada)
    output wire [9:0]  LEDR,
    output wire [7:0]  LEDG,
    output wire        I2C_SCLK,       // I2C para configurar o codec
    inout  wire        I2C_SDAT,
    output wire        AUD_XCK,        // relogio mestre para o codec (12,5 MHz)
    input  wire        AUD_BCLK,       // relogio de bit, gerado pelo codec
    input  wire        AUD_DACLRCK,    // relogio de canal, gerado pelo codec
    output wire        AUD_DACDAT,     // bits do audio para o codec
    input  wire        AUD_ADCLRCK,    // nao usados, mas declarados para o pinout ficar completo
    input  wire        AUD_ADCDAT
);
    // reset: KEY[0] (ativo em 0) sincronizado por 2 flip-flops
    reg [1:0] rs;
    always @(posedge CLOCK_50) rs <= {rs[0], ~KEY[0]};
    wire reset = rs[1];

    // XCK = 50 MHz / 4 = 12.5 MHz  ->  fs = XCK/256 = 48828.125 Hz (o codec gera BCLK e LRCK a partir dele)
    reg [1:0] xdiv = 2'd0;
    always @(posedge CLOCK_50) xdiv <= xdiv + 2'd1;
    assign AUD_XCK = xdiv[1];

    // configura o codec por I2C logo apos o reset
    wire done, ack_err;
    i2c_config u_cfg (.clk(CLOCK_50), .reset(reset), .i2c_sclk(I2C_SCLK), .i2c_sdat(I2C_SDAT),
                      .done(done), .ack_err(ack_err));

    // nucleo de uma nota: so toca com SW3 ligada e o codec ja configurado
    synth_core u_synth (.clk(CLOCK_50), .reset(reset), .enable(SW[3] & done), .note(SW[2:0]),
                        .wave(SW[5:4]), .bclk(AUD_BCLK), .lrck(AUD_DACLRCK), .dacdat(AUD_DACDAT));

    assign LEDR = SW;                          // LEDs vermelhos acompanham as chaves
    assign LEDG = {6'b0, ack_err, done};       // LEDG1 = erro de ACK, LEDG0 = configurado
endmodule
