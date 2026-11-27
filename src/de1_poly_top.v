// =====================================================================================
// de1_poly_top.v - TOPO do sintetizador polifonico (o modulo que representa a placa DE1)
// =====================================================================================
//
// O QUE E UM "TOPO": e o modulo de mais alto nivel. Cada porta dele e um pino fisico da
// placa (os nomes CLOCK_50, KEY, SW... sao ligados aos pinos reais no arquivo
// quartus/de1_poly.qsf). Ele nao gera som sozinho: so instancia os blocos e liga os fios.
//
// CAMINHO DO SOM (de onde vem a nota ate sair no fone):
//
//   SW[7:0] --> notes --> synth_poly_core --> AUD_DACDAT --> codec WM8731 --> LINE OUT / fone
//                          (poly_gen gera a amostra, i2s_tx manda bit a bit)
//
//   Antes de tocar, o i2c_config configura o codec (volume, formato do audio etc.).
//
// CONTROLES NA PLACA:
//   SW[0..7] = teclas C4 D4 E4 F4 G4 A4 B4 C5 (varias podem ficar ligadas ao mesmo tempo)
//   SW[9]    = chave mestre: desligada, nada toca
//   KEY[2:1] = forma de onda, lida enquanto os botoes estao APERTADOS:
//              nenhum = seno, so KEY1 = quadrada, so KEY2 = dente de serra, os dois = triangular
//   KEY[0]   = reset (apertar reinicia tudo, inclusive a configuracao do codec)
//
// LEDS:
//   LEDR[9:0] = espelho das chaves SW (aceso = chave ligada)
//   LEDG[0]   = codec configurado (o I2C terminou)
//   LEDG[1]   = erro de ACK no I2C (o codec nao respondeu a algum byte)
//
// Os botoes KEY da DE1 valem 0 quando apertados (ativos em 0); por isso aparecem com ~.
// =====================================================================================
module de1_poly_top (
    input  wire        CLOCK_50,     // relogio de 50 MHz da placa: tudo aqui anda no ritmo dele
    input  wire [3:0]  KEY,          // 4 botoes (0 = apertado)
    input  wire [9:0]  SW,           // 10 chaves (1 = ligada, para cima)
    output wire [9:0]  LEDR,         // 10 LEDs vermelhos
    output wire [7:0]  LEDG,         // 8 LEDs verdes
    output wire        I2C_SCLK,     // I2C: relogio da configuracao do codec (nos geramos)
    inout  wire        I2C_SDAT,     // I2C: dado da configuracao (inout: o codec tambem escreve nele, no ACK)
    output wire        AUD_XCK,      // relogio mestre que mandamos para o codec (12,5 MHz)
    input  wire        AUD_BCLK,     // relogio de bit gerado PELO CODEC (ele e o mestre do audio)
    input  wire        AUD_DACLRCK,  // relogio de canal gerado pelo codec (left-justified, LRP=0: 1 = esquerdo, 0 = direito)
    output wire        AUD_DACDAT,   // bits do audio que mandamos para o conversor (DAC)
    input  wire        AUD_ADCLRCK,  // entrada de microfone: nao usada, so declarada para o pinout ficar completo
    input  wire        AUD_ADCDAT    // idem
);
    // ---------------------------------------------------------------------------------
    // RESET: KEY[0] passa por 2 flip-flops antes de ser usado (sincronizador).
    // O botao muda a qualquer instante, sem respeitar o relogio. Se um flip-flop le o sinal
    // bem na hora em que ele muda, a saida pode ficar indecisa por um tempo (metaestabilidade).
    // O segundo flip-flop da tempo para isso se resolver. ~KEY[0]: apertado vira 1.
    // ---------------------------------------------------------------------------------
    reg [1:0] rs;
    always @(posedge CLOCK_50) rs <= {rs[0], ~KEY[0]};   // empurra o valor novo: rs[0] -> rs[1]
    wire reset = rs[1];                                   // reset ativo em 1, ja sincronizado

    // ---------------------------------------------------------------------------------
    // RELOGIO DO CODEC: 50 MHz / 4 = 12,5 MHz.
    // xdiv conta 0,1,2,3,0,1...; o bit 1 dele fica 2 ciclos em 0 e 2 ciclos em 1,
    // ou seja, uma onda quadrada com 1/4 da frequencia.
    // O codec divide esse relogio por 256 para achar a taxa de amostragem:
    // fs = 12,5 MHz / 256 = 48828,125 amostras por segundo.
    // ---------------------------------------------------------------------------------
    reg [1:0] xdiv = 2'd0;
    always @(posedge CLOCK_50) xdiv <= xdiv + 2'd1;
    assign AUD_XCK = xdiv[1];

    // ---------------------------------------------------------------------------------
    // CONFIGURACAO DO CODEC: logo apos o reset, escreve 9 registradores do WM8731 por I2C.
    // done = 1 quando terminou; ack_err = 1 se o codec deixou de responder a algum byte.
    // ---------------------------------------------------------------------------------
    wire done, ack_err;
    i2c_config u_cfg (.clk(CLOCK_50), .reset(reset), .i2c_sclk(I2C_SCLK), .i2c_sdat(I2C_SDAT),
                      .done(done), .ack_err(ack_err));

    // ---------------------------------------------------------------------------------
    // QUAIS NOTAS TOCAM (o "contrato" do projeto): um vetor de 8 bits, bit i = nota i ligada.
    // So toca se a chave mestre SW9 estiver ligada E o codec ja estiver configurado (done);
    // senao, todas as notas ficam desligadas (8'b0).
    // Qualquer nova fonte de notas (ex.: teclado PS/2) so precisa entrar nesta linha.
    // ---------------------------------------------------------------------------------
    wire [7:0] notes = (SW[9] & done) ? SW[7:0] : 8'b0;

    // Forma de onda: {KEY2 apertado, KEY1 apertado} vira um numero de 0 a 3
    // (0 seno, 1 quadrada, 2 serra, 3 triangular). ~ porque o botao apertado vale 0.
    wire [1:0] wave  = {~KEY[2], ~KEY[1]};

    // ---------------------------------------------------------------------------------
    // NUCLEO DO SINTETIZADOR: gera as amostras das notas ligadas e as envia ao codec.
    // bclk e lrck vem do codec; dacdat volta para ele.
    // ---------------------------------------------------------------------------------
    synth_poly_core u_synth (.clk(CLOCK_50), .reset(reset), .notes(notes), .wave(wave),
                             .bclk(AUD_BCLK), .lrck(AUD_DACLRCK), .dacdat(AUD_DACDAT));

    // ---------------------------------------------------------------------------------
    // LEDS
    // ---------------------------------------------------------------------------------
    assign LEDR = SW;                          // cada LED vermelho acompanha a chave embaixo dele
    assign LEDG = {6'b0, ack_err, done};       // LEDG1 = erro de ACK, LEDG0 = configurado; o resto apagado
endmodule
