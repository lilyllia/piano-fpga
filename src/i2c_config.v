// i2c_config.v - configura o codec WM8731 por I2C (so escrita) logo apos o reset.
// Endereco I2C do WM8731 com CSB=0: 0011010 -> byte de escrita 0x34.
// Cada registrador e escrito com 3 bytes: 0x34, {reg[6:0], dado[8]}, dado[7:0].
// SCL ~ 20 kHz (50 MHz / 2500). done=1 ao fim; ack_err=1 se algum byte nao recebeu ACK.
module i2c_config #(
    parameter [6:0] HP_VOL = 7'h6D      // volume do fone: 7'h79 = 0 dB, cada passo = 1 dB (7'h6D = -12 dB; testados 7'h59 = -32 dB e 7'h65 = -20 dB, baixos demais em 18/10)
) (
    input  wire clk,                    // 50 MHz
    input  wire reset,                  // ativo em 1
    output reg  i2c_sclk,
    inout  wire i2c_sdat,
    output reg  done,
    output reg  ack_err
);
    localparam N = 9;
    reg [15:0] word;
    always @* begin
        case (idx)
            4'd0: word = 16'h1E00;              // R15 reset do codec
            4'd1: word = 16'h0C00;              // R6  tudo ligado
            4'd2: word = 16'h0812;              // R4  caminho analogico: DAC -> saida (DACSEL=1), sem bypass
            4'd3: word = 16'h0A00;              // R5  caminho digital: sem mute, sem de-enfase
            4'd4: word = 16'h0E41;              // R7  master, left-justified, 16 bits
            4'd5: word = 16'h1000;              // R8  modo normal, 256*fs (MCLK/256)
            4'd6: word = {7'h02, 1'b0, 1'b1, HP_VOL}; // R2  volume fone esquerdo (zero-cross ligado)
            4'd7: word = {7'h03, 1'b0, 1'b1, HP_VOL}; // R3  volume fone direito
            4'd8: word = 16'h1201;              // R9  ativa a interface digital
            default: word = 16'h1201;
        endcase
    end

    reg  [3:0]  idx;
    reg  [11:0] div;
    reg  [6:0]  step;
    reg         sda;                            // 1 = solta o fio (puxado a 1 pelo resistor), 0 = puxa pra baixo
    reg  [19:0] wait_cnt;
    wire        tick = (div == 12'd624);        // 4 ticks por bit -> 50e6/625/4 = 20 kHz
    assign i2c_sdat = sda ? 1'bz : 1'b0;

    wire [26:0] frame = {8'h34, 1'b1, word[15:8], 1'b1, word[7:0], 1'b1};
    wire [6:0]  s  = step - 7'd3;
    wire [4:0]  k  = s[6:2];                    // numero do bit (0..26)
    wire [1:0]  ph = s[1:0];
    wire        ack_slot = (k == 5'd8) || (k == 5'd17) || (k == 5'd26);

    always @(posedge clk) begin
        if (reset) begin
            div <= 0; step <= 0; idx <= 0; sda <= 1; i2c_sclk <= 1;
            done <= 0; ack_err <= 0; wait_cnt <= 0;
        end else begin
            div <= tick ? 12'd0 : div + 12'd1;
            if (wait_cnt != 20'hFFFFF) wait_cnt <= wait_cnt + 20'd1;   // espera ~21 ms apos o reset
            if (tick && wait_cnt == 20'hFFFFF && !done) begin
                if (step == 0)        begin sda <= 1; i2c_sclk <= 1; step <= 1; end
                else if (step == 1)   begin sda <= 0; step <= 2; end            // START
                else if (step == 2)   begin i2c_sclk <= 0; step <= 3; end
                else if (step < 111) begin
                    case (ph)
                        2'd0: sda <= frame[26 - k];
                        2'd1: i2c_sclk <= 1;
                        2'd2: if (ack_slot && i2c_sdat) ack_err <= 1;          // lê o ACK (0 = ok)
                        2'd3: i2c_sclk <= 0;
                    endcase
                    step <= step + 7'd1;
                end
                else if (step == 111) begin sda <= 0; step <= 112; end
                else if (step == 112) begin i2c_sclk <= 1; step <= 113; end
                else if (step == 113) begin sda <= 1; step <= 114; end          // STOP
                else begin
                    step <= 0;
                    if (idx == N - 1) done <= 1; else idx <= idx + 4'd1;
                end
            end
        end
    end
endmodule
