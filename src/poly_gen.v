// poly_gen.v - polifonia com envelope ADSR, usando UM unico caminho de dados compartilhado.
// 8 vozes (uma por nota C4..C5). A cada amostra (sample_en) o modulo percorre as 8 vozes,
// 4 ciclos de clock por voz: (0) avanca a fase, (1) calcula a onda e o proximo passo do envelope,
// (2) multiplica onda * envelope, (3) acumula. Total: 8*4 = 32 ciclos por amostra, de 1024 disponiveis (50 MHz / 48828,125 Hz) = 3,1%.
//
// ENVELOPE (por voz, atualizado 1x por amostra):
//   IDLE -> ATTACK (tecla apertada: sobe ate o maximo em ATK_MS)
//        -> DECAY  (desce ate SUS_PCT % em DEC_MS)
//        -> SUSTAIN (fica em SUS_PCT % enquanto a tecla estiver apertada)
//        -> RELEASE (tecla solta: desce a zero em ~REL_MS) -> IDLE
// Mixagem: cada voz e atenuada por VOICE_SHIFT bits antes de somar (>=3 nunca estoura com 8 vozes).
module poly_gen #(
    parameter VOICE_SHIFT = 4,
    parameter ATK_MS      = 10,
    parameter DEC_MS      = 150,
    parameter SUS_PCT     = 70,
    parameter REL_MS      = 200
) (
    input  wire               clk,
    input  wire               reset,
    input  wire               sample_en,
    input  wire        [7:0]  active,     // bit i = tecla da nota i apertada (0 = C4 ... 7 = C5)
    input  wire        [1:0]  wave,
    output reg  signed [15:0] sample
);
    // Taxas por amostra num nivel de 24 bits (fundo de escala = 2^24-1). 343597 = 2^24-1 * 1000 / 48828
    localparam [23:0] FULL     = 24'hFFFFFF;
    localparam [23:0] SUS_LVL  = (24'hFFFFFF / 100) * SUS_PCT;
    localparam [23:0] ATK_RATE = 343597 / ATK_MS;
    localparam [23:0] DEC_RATE = ((343597 / 100) * (100 - SUS_PCT)) / DEC_MS;
    localparam [23:0] REL_RATE = ((343597 / 100) * SUS_PCT) / REL_MS;

    localparam [2:0] IDLE = 3'd0, ATTACK = 3'd1, DECAY = 3'd2, SUSTAIN = 3'd3, RELEASE = 3'd4;

    reg [23:0] phase_mem [0:7];
    reg [23:0] env_lvl   [0:7];
    reg [2:0]  env_st    [0:7];

    reg [2:0]  idx;
    reg [1:0]  st;
    reg        busy;
    reg signed [20:0] acc;
    reg [23:0] p;
    reg signed [15:0] raw_r;
    reg [23:0] lvl_n;                       // nivel do envelope ja atualizado
    reg signed [32:0] prod;

    wire [23:0] inc;
    note_rom u_notes (.note(idx), .phase_inc(inc));
    wire signed [15:0] raw;
    wave_gen u_wave (.phase(p), .wave(wave), .raw(raw));

    // proximo estado do envelope da voz idx
    wire        gate   = active[idx];
    wire [23:0] lvl    = env_lvl[idx];
    wire [2:0]  est    = env_st[idx];
    reg  [24:0] t;                          // 25 bits para detectar estouro
    reg  [23:0] nlvl;
    reg  [2:0]  nst;
    always @* begin
        nlvl = lvl; nst = est; t = 25'd0;
        case (est)
            IDLE:    if (gate) nst = ATTACK;
            ATTACK:  if (!gate) nst = RELEASE;
                     else begin
                         t = {1'b0, lvl} + ATK_RATE;
                         if (t >= {1'b0, FULL}) begin nlvl = FULL; nst = DECAY; end else nlvl = t[23:0];
                     end
            DECAY:   if (!gate) nst = RELEASE;
                     else if (lvl <= SUS_LVL + DEC_RATE) begin nlvl = SUS_LVL; nst = SUSTAIN; end
                     else nlvl = lvl - DEC_RATE;
            SUSTAIN: if (!gate) nst = RELEASE; else nlvl = SUS_LVL;
            RELEASE: if (gate) nst = ATTACK;                    // tocou de novo: recomeca do nivel atual
                     else if (lvl <= REL_RATE) begin nlvl = 24'd0; nst = IDLE; end
                     else nlvl = lvl - REL_RATE;
            default: nst = IDLE;
        endcase
    end

    integer k;
    initial for (k = 0; k < 8; k = k + 1) begin phase_mem[k] = 0; env_lvl[k] = 0; env_st[k] = IDLE; end

    wire signed [32:0] prod_next = raw_r * $signed({1'b0, lvl_n[23:8]});   // 16 bits sinal x 17 bits sinal
    wire signed [20:0] acc_next  = acc + (prod >>> (16 + VOICE_SHIFT));

    always @(posedge clk) begin
        if (reset) begin
            busy <= 0; idx <= 0; st <= 0; acc <= 0; sample <= 0;
            for (k = 0; k < 8; k = k + 1) begin phase_mem[k] <= 0; env_lvl[k] <= 0; env_st[k] <= IDLE; end
        end else if (sample_en && !busy) begin
            busy <= 1; idx <= 0; st <= 0; acc <= 0;
        end else if (busy) begin
            case (st)
                2'd0: begin
                    p <= phase_mem[idx] + inc;
                    phase_mem[idx] <= phase_mem[idx] + inc;
                    st <= 1;
                end
                2'd1: begin
                    raw_r <= raw;
                    lvl_n <= nlvl;
                    env_lvl[idx] <= nlvl;
                    env_st[idx]  <= nst;
                    st <= 2;
                end
                2'd2: begin prod <= prod_next; st <= 3; end
                2'd3: begin
                    acc <= acc_next;
                    st  <= 0;
                    idx <= idx + 3'd1;
                    if (idx == 3'd7) begin busy <= 0; sample <= acc_next[15:0]; end
                end
            endcase
        end
    end
endmodule
