// =====================================================================================
// i2c_config.v - CONFIGURA o codec WM8731 por I2C logo apos o reset (so escrita)
// =====================================================================================
//
// POR QUE EXISTE: o chip de audio da DE1 (WM8731) liga em silencio. Antes de tocar, e
// preciso escrever nos registradores dele: ligar o conversor, escolher o formato do audio,
// o volume etc. Isso e feito uma vez, pelo protocolo I2C, e depois este modulo fica parado
// com done = 1.
//
// O PROTOCOLO I2C EM 4 LINHAS:
//   - Dois fios: SCL (relogio, quem gera somos nos) e SDA (dado, compartilhado).
//   - Os fios sao "dreno aberto": ninguem forca 1, so puxa para 0. Para mandar 1, solta o
//     fio e um resistor na placa puxa para 1. Assim os dois lados podem usar o mesmo fio.
//   - START = SDA desce com SCL em 1; STOP = SDA sobe com SCL em 1. No resto do tempo,
//     SDA so muda com SCL em 0, e quem recebe le o bit quando SCL esta em 1.
//   - Depois de cada byte, quem recebe puxa SDA para 0 por um pulso: e o ACK ("recebi").
//
// O QUE E ENVIADO, POR REGISTRADOR (um "quadro" de 3 bytes entre START e STOP):
//   byte 1: 0x34       = endereco do WM8731 (0011010, com o pino CSB em 0) + bit 0 = escrita
//   byte 2: {reg[6:0], dado[8]}   (o registrador tem 7 bits e o dado 9)
//   byte 3: dado[7:0]
//
// VELOCIDADE: SCL de cerca de 20 kHz (50 MHz / 2500). Cada bit leva 4 "ticks".
// SAIDAS: done = 1 ao terminar os 9 registradores; ack_err = 1 se algum byte ficou sem ACK
//         (nesse caso a configuracao pode nao ter pegado: confira os pinos I2C).
// =====================================================================================
module i2c_config #(
    // Volume do fone/LINE OUT: 7'h79 = 0 dB e cada passo abaixo tira 1 dB.
    // 7'h6D = -12 dB. Em 18/10 foram testados 7'h59 (-32 dB) e 7'h65 (-20 dB): baixos demais.
    parameter [6:0] HP_VOL = 7'h6D
) (
    input  wire clk,                    // 50 MHz
    input  wire reset,                  // ativo em 1
    output reg  i2c_sclk,               // fio SCL
    inout  wire i2c_sdat,               // fio SDA (inout: nos escrevemos e lemos o ACK do codec)
    output reg  done,                   // 1 = configuracao terminada
    output reg  ack_err                 // 1 = algum byte nao recebeu ACK
);
    // ---------------------------------------------------------------------------------
    // TABELA DOS 9 REGISTRADORES (combinacional): idx escolhe qual sera enviado agora.
    // Cada palavra de 16 bits = {numero do registrador (7 bits), dado (9 bits)}.
    // Ex.: 16'h0E41 = 0000111 001000001 -> registrador 7, dado 0x041.
    // (idx e declarado mais abaixo; as ferramentas aceitam essa ordem)
    // ---------------------------------------------------------------------------------
    localparam N = 9;                   // quantos registradores escrever
    reg [15:0] word;
    always @* begin
        case (idx)
            4'd0: word = 16'h1E00;              // R15 reset: volta o codec ao estado de fabrica
            4'd1: word = 16'h0C00;              // R6  energia: todos os blocos ligados (0 = ligado)
            4'd2: word = 16'h0812;              // R4  caminho analogico: DAC -> saida (DACSEL=1), sem bypass da entrada, microfone mudo
            4'd3: word = 16'h0A00;              // R5  caminho digital: DAC sem mute, sem de-enfase
            4'd4: word = 16'h0E41;              // R7  formato: codec mestre (gera BCLK e LRCK), left-justified, 16 bits
            4'd5: word = 16'h1000;              // R8  taxa: modo normal, fs = MCLK/256 (12,5 MHz / 256 = 48828 Hz)
            4'd6: word = {7'h02, 1'b0, 1'b1, HP_VOL}; // R2  volume do fone esquerdo (bit 7 = so muda o volume quando a onda cruza o zero, sem estalo)
            4'd7: word = {7'h03, 1'b0, 1'b1, HP_VOL}; // R3  volume do fone direito
            4'd8: word = 16'h1201;              // R9  ativa a interface digital (por ultimo, como pede o manual)
            default: word = 16'h1201;
        endcase
    end

    reg  [3:0]  idx;                            // registrador atual (0 a 8)
    reg  [11:0] div;                            // divisor do relogio: conta 0..624
    reg  [6:0]  step;                           // passo dentro do quadro atual (0 a 114, veja a maquina abaixo)
    reg         sda;                            // 1 = solta o fio (o resistor puxa para 1), 0 = puxa para baixo
    reg  [19:0] wait_cnt;                       // espera inicial apos o reset
    wire        tick = (div == 12'd624);        // 1 tick a cada 625 ciclos; 4 ticks por bit -> 50e6/625/4 = 20 kHz
    assign i2c_sdat = sda ? 1'bz : 1'b0;        // dreno aberto: z = solto (le 1 pelo resistor), ou 0

    // ---------------------------------------------------------------------------------
    // O QUADRO COMO UMA FILA DE 27 BITS, na ordem de envio (frame[26] primeiro):
    //   8 bits do endereco | 1 | 8 bits | 1 | 8 bits | 1
    // Os "1" sao os espacos de ACK: soltamos o fio para o codec poder puxar para 0.
    // ---------------------------------------------------------------------------------
    wire [26:0] frame = {8'h34, 1'b1, word[15:8], 1'b1, word[7:0], 1'b1};

    // Os passos 3 a 110 enviam os 27 bits, 4 passos (fases) por bit: 27 x 4 = 108 passos.
    wire [6:0]  s  = step - 7'd3;               // passo contado a partir do primeiro bit
    wire [4:0]  k  = s[6:2];                    // numero do bit (0..26) = s / 4
    wire [1:0]  ph = s[1:0];                    // fase dentro do bit (0..3) = s % 4
    wire        ack_slot = (k == 5'd8) || (k == 5'd17) || (k == 5'd26);  // bits que sao ACK

    always @(posedge clk) begin
        if (reset) begin
            div <= 0; step <= 0; idx <= 0; sda <= 1; i2c_sclk <= 1;     // fios soltos (repouso do I2C)
            done <= 0; ack_err <= 0; wait_cnt <= 0;
        end else begin
            div <= tick ? 12'd0 : div + 12'd1;
            // Espera 2^20 ciclos (~21 ms) apos o reset antes de falar com o codec,
            // para dar tempo de ele ligar.
            if (wait_cnt != 20'hFFFFF) wait_cnt <= wait_cnt + 20'd1;
            // A maquina so anda 1 passo por tick, depois da espera e enquanto nao terminou.
            if (tick && wait_cnt == 20'hFFFFF && !done) begin
                if (step == 0)        begin sda <= 1; i2c_sclk <= 1; step <= 1; end   // repouso: os dois em 1
                else if (step == 1)   begin sda <= 0; step <= 2; end            // START: SDA desce com SCL em 1
                else if (step == 2)   begin i2c_sclk <= 0; step <= 3; end       // SCL desce: pronto para o 1o bit
                else if (step < 111) begin
                    // Envio dos 27 bits, cada um em 4 fases:
                    case (ph)
                        2'd0: sda <= frame[26 - k];                             // poe o bit no fio (SCL em 0)
                        2'd1: i2c_sclk <= 1;                                    // SCL sobe: o codec le o bit
                        2'd2: if (ack_slot && i2c_sdat) ack_err <= 1;           // se e ACK, confere: 0 = ok, 1 = sem resposta
                        2'd3: i2c_sclk <= 0;                                    // SCL desce: fim do bit
                    endcase
                    step <= step + 7'd1;
                end
                else if (step == 111) begin sda <= 0; step <= 112; end          // prepara o STOP: SDA em 0
                else if (step == 112) begin i2c_sclk <= 1; step <= 113; end     // SCL sobe
                else if (step == 113) begin sda <= 1; step <= 114; end          // STOP: SDA sobe com SCL em 1
                else begin
                    // Fim do quadro: passa para o proximo registrador, ou termina no ultimo.
                    step <= 0;
                    if (idx == N - 1) done <= 1; else idx <= idx + 4'd1;
                end
            end
        end
    end
endmodule
