// =====================================================================================
// poly_gen.v - GERADOR POLIFONICO: 8 vozes com envelope ADSR, somadas numa amostra so
// =====================================================================================
//
// O QUE FAZ: a cada pedido de amostra (sample_en), calcula o valor de cada uma das 8 notas
// naquele instante, aplica o volume de cada uma (envelope) e soma tudo numa amostra de
// 16 bits. Cada nota tem a sua "voz": voz 0 = C4, voz 1 = D4, ..., voz 7 = C5.
//
// IDEIA PRINCIPAL (multiciclo): em vez de 8 circuitos iguais trabalhando ao mesmo tempo,
// existe UM caminho de dados que atende as 8 vozes, uma depois da outra. Isso cabe porque
// entre duas amostras ha 1024 ciclos de relogio (50 MHz / 48828,125 Hz) e cada voz gasta
// so 4 ciclos: 8 vozes x 4 = 32 ciclos, cerca de 3% do tempo disponivel. Economiza
// multiplicadores e logica da FPGA. O que cada voz precisa lembrar entre uma amostra e
// outra (fase, nivel e estado do envelope) fica guardado em pequenas memorias de 8 posicoes.
//
// OS 4 PASSOS DE CADA VOZ (variavel st):
//   (0) avanca a fase da voz (fase + incremento da nota)
//   (1) le a onda naquela fase e calcula o proximo passo do envelope
//   (2) multiplica onda x envelope (aplica o volume)
//   (3) soma no acumulador e passa para a proxima voz; na voz 7, entrega a amostra
//
// ENVELOPE ADSR (o volume de cada nota ao longo do tempo, atualizado 1 vez por amostra):
//   IDLE    --(tecla apertada)--> ATTACK : sobe de onde estiver ate o maximo em ATK_MS
//   ATTACK  --(chegou ao maximo)--> DECAY : desce ate SUS_PCT % do maximo em DEC_MS
//   DECAY   --(chegou)-------------> SUSTAIN: fica em SUS_PCT % enquanto a tecla estiver apertada
//   qualquer um --(tecla solta)----> RELEASE: desce ate zero em cerca de REL_MS -> IDLE
//   RELEASE --(apertou de novo)----> ATTACK  (recomeca do nivel atual, sem estalo)
// Sem envelope, o som comecaria e pararia de golpe, e isso se ouve como um "clique".
//
// MIXAGEM: cada voz e dividida por 2^VOICE_SHIFT antes de somar. Com VOICE_SHIFT >= 3,
// 8 vozes no maximo nunca passam do limite de 16 bits (veja synth_poly_core.v).
// =====================================================================================
module poly_gen #(
    parameter VOICE_SHIFT = 4,      // padrao; o synth_poly_core usa 3 (os testbenches usam este 4)
    parameter ATK_MS      = 10,     // ataque: tempo para subir de 0 ao maximo (ms)
    parameter DEC_MS      = 150,    // decaimento: tempo para descer do maximo ao sustain (ms)
    parameter SUS_PCT     = 70,     // sustain: nivel enquanto a tecla esta apertada (% do maximo)
    parameter REL_MS      = 200     // soltura: tempo para descer do sustain ate zero (ms)
) (
    input  wire               clk,        // 50 MHz
    input  wire               reset,      // ativo em 1
    input  wire               sample_en,  // pulso de 1 ciclo: "calcule a proxima amostra"
    input  wire        [7:0]  active,     // bit i = tecla da nota i apertada (0 = C4 ... 7 = C5)
    input  wire        [1:0]  wave,       // 0 seno, 1 quadrada, 2 serra, 3 triangular (igual para todas as vozes)
    output reg  signed [15:0] sample      // amostra pronta (soma das vozes); muda 1 vez por amostra
);
    // ---------------------------------------------------------------------------------
    // CONSTANTES DO ENVELOPE
    // O nivel do envelope tem 24 bits: 0 = mudo, FULL = 2^24-1 = volume maximo.
    // As taxas dizem quanto o nivel muda A CADA AMOSTRA. Para ir de 0 a FULL em T ms:
    //   amostras em T ms = T * fs / 1000   ->   taxa = FULL * 1000 / fs / T
    // FULL * 1000 / fs = (2^24-1) * 1000 / 48828 = 343597, por isso esse numero aparece abaixo.
    // Com os valores padrao: ATK_RATE = 34359, DEC_RATE = 687, REL_RATE = 1202, SUS_LVL = 70% de FULL.
    // (as divisoes sao inteiras, entao os tempos reais ficam a menos de 0,1% dos pedidos)
    // ---------------------------------------------------------------------------------
    localparam [23:0] FULL     = 24'hFFFFFF;                                  // nivel maximo
    localparam [23:0] SUS_LVL  = (24'hFFFFFF / 100) * SUS_PCT;                // nivel do sustain
    localparam [23:0] ATK_RATE = 343597 / ATK_MS;                             // 0 -> FULL em ATK_MS
    localparam [23:0] DEC_RATE = ((343597 / 100) * (100 - SUS_PCT)) / DEC_MS; // FULL -> SUS_LVL em DEC_MS
    localparam [23:0] REL_RATE = ((343597 / 100) * SUS_PCT) / REL_MS;         // SUS_LVL -> 0 em REL_MS

    // Codigos dos estados do envelope
    localparam [2:0] IDLE = 3'd0, ATTACK = 3'd1, DECAY = 3'd2, SUSTAIN = 3'd3, RELEASE = 3'd4;

    // ---------------------------------------------------------------------------------
    // MEMORIA DE CADA VOZ (8 posicoes, indexadas pelo numero da voz)
    // ---------------------------------------------------------------------------------
    reg [23:0] phase_mem [0:7];     // fase do acumulador de cada voz (onde ela esta no ciclo da onda)
    reg [23:0] env_lvl   [0:7];     // nivel atual do envelope de cada voz
    reg [2:0]  env_st    [0:7];     // estado atual do envelope de cada voz (IDLE, ATTACK...)

    // ---------------------------------------------------------------------------------
    // REGISTRADORES DO CAMINHO DE DADOS COMPARTILHADO
    // ---------------------------------------------------------------------------------
    reg [2:0]  idx;                         // qual voz esta sendo calculada agora (0 a 7)
    reg [1:0]  st;                          // em qual dos 4 passos estamos (0 a 3)
    reg        busy;                        // 1 = varrendo as vozes; 0 = esperando o proximo sample_en
    reg signed [20:0] acc;                  // soma parcial das vozes (21 bits: folga para nao estourar no meio da soma)
    reg [23:0] p;                           // fase nova da voz atual (copia que alimenta o wave_gen)
    reg signed [15:0] raw_r;                // valor da onda da voz atual, guardado no passo 1
    reg [23:0] lvl_n;                       // nivel do envelope ja atualizado, guardado no passo 1
    reg signed [32:0] prod;                 // onda x envelope, guardado no passo 2

    // Incremento de fase da voz atual: a tabela de notas recebe o numero da voz
    // (a voz i toca sempre a nota i).
    wire [23:0] inc;
    note_rom u_notes (.note(idx), .phase_inc(inc));

    // Valor da onda na fase p (combinacional: fica pronto no mesmo ciclo em que p muda)
    wire signed [15:0] raw;
    wave_gen u_wave (.phase(p), .wave(wave), .raw(raw));

    // ---------------------------------------------------------------------------------
    // PROXIMO PASSO DO ENVELOPE DA VOZ idx (combinacional)
    // Olha o estado e o nivel atuais da voz e se a tecla dela esta apertada (gate),
    // e calcula o nivel (nlvl) e o estado (nst) que ela deve ter nesta amostra.
    // Nada e gravado aqui: a gravacao acontece no passo 1 do bloco sequencial abaixo.
    // ---------------------------------------------------------------------------------
    wire        gate   = active[idx];       // 1 = tecla desta voz apertada
    wire [23:0] lvl    = env_lvl[idx];      // nivel atual
    wire [2:0]  est    = env_st[idx];       // estado atual
    reg  [24:0] t;                          // nivel + taxa com 1 bit a mais, para perceber se passou do maximo
    reg  [23:0] nlvl;                       // proximo nivel
    reg  [2:0]  nst;                        // proximo estado
    always @* begin
        nlvl = lvl; nst = est; t = 25'd0;   // por padrao, nada muda
        case (est)
            IDLE:    if (gate) nst = ATTACK;                    // apertou: comeca a subir na proxima amostra
            ATTACK:  if (!gate) nst = RELEASE;                  // soltou durante a subida
                     else begin
                         t = {1'b0, lvl} + ATK_RATE;
                         // chegou (ou passaria) do maximo: trava em FULL e comeca a descer
                         if (t >= {1'b0, FULL}) begin nlvl = FULL; nst = DECAY; end else nlvl = t[23:0];
                     end
            DECAY:   if (!gate) nst = RELEASE;
                     // mais um passo passaria do sustain: trava nele (evita descer abaixo)
                     else if (lvl <= SUS_LVL + DEC_RATE) begin nlvl = SUS_LVL; nst = SUSTAIN; end
                     else nlvl = lvl - DEC_RATE;
            SUSTAIN: if (!gate) nst = RELEASE; else nlvl = SUS_LVL;
            RELEASE: if (gate) nst = ATTACK;                    // tocou de novo: recomeca do nivel atual
                     // mais um passo passaria do zero: zera e desliga (evita "dar a volta" e virar volume maximo)
                     else if (lvl <= REL_RATE) begin nlvl = 24'd0; nst = IDLE; end
                     else nlvl = lvl - REL_RATE;
            default: nst = IDLE;                                // codigo invalido: volta ao repouso
        endcase
    end

    // Valores iniciais (usados na simulacao e na carga da FPGA): tudo parado e mudo.
    integer k;
    initial for (k = 0; k < 8; k = k + 1) begin phase_mem[k] = 0; env_lvl[k] = 0; env_st[k] = IDLE; end

    // ---------------------------------------------------------------------------------
    // CONTAS DO VOLUME (combinacionais, usadas nos passos 2 e 3)
    // prod_next: onda (16 bits com sinal) x os 16 bits mais altos do nivel (0 a 65535).
    //   O {1'b0, ...} poe um 0 na frente para o nivel ser tratado como numero positivo
    //   numa conta com sinal (17 bits). Resultado em 33 bits, que cabem qualquer produto.
    // acc_next: >>> 16 desfaz a escala do nivel (equivale a multiplicar a onda por nivel/65536)
    //   e >>> VOICE_SHIFT aplica a atenuacao da mixagem. >>> e o deslocamento que preserva o sinal.
    // ---------------------------------------------------------------------------------
    wire signed [32:0] prod_next = raw_r * $signed({1'b0, lvl_n[23:8]});
    wire signed [20:0] acc_next  = acc + (prod >>> (16 + VOICE_SHIFT));

    // ---------------------------------------------------------------------------------
    // MAQUINA DE ESTADOS: varre as 8 vozes, 4 passos cada
    // ---------------------------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            busy <= 0; idx <= 0; st <= 0; acc <= 0; sample <= 0;
            for (k = 0; k < 8; k = k + 1) begin phase_mem[k] <= 0; env_lvl[k] <= 0; env_st[k] <= IDLE; end
        end else if (sample_en && !busy) begin
            // pedido de amostra: comeca a varredura pela voz 0, com a soma zerada
            busy <= 1; idx <= 0; st <= 0; acc <= 0;
        end else if (busy) begin
            case (st)
                2'd0: begin
                    // PASSO 0: avanca a fase da voz. A fase anda mesmo com a nota desligada
                    // (o envelope em zero e que a deixa muda).
                    p <= phase_mem[idx] + inc;              // vai para o wave_gen
                    phase_mem[idx] <= phase_mem[idx] + inc; // guarda para a proxima amostra
                    st <= 1;
                end
                2'd1: begin
                    // PASSO 1: o wave_gen ja tem o valor da onda na fase p; guarda.
                    // Grava tambem o novo nivel e estado do envelope calculados acima.
                    raw_r <= raw;
                    lvl_n <= nlvl;
                    env_lvl[idx] <= nlvl;
                    env_st[idx]  <= nst;
                    st <= 2;
                end
                2'd2: begin prod <= prod_next; st <= 3; end  // PASSO 2: onda x envelope
                2'd3: begin
                    // PASSO 3: soma a voz e passa para a proxima
                    acc <= acc_next;
                    st  <= 0;
                    idx <= idx + 3'd1;
                    // Ultima voz: entrega a soma. Os 16 bits de baixo bastam porque a atenuacao
                    // garante que a soma de 8 vozes fica entre -32768 e 32767.
                    if (idx == 3'd7) begin busy <= 0; sample <= acc_next[15:0]; end
                end
            endcase
        end
    end
endmodule
