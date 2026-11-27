// =====================================================================================
// receptor_ps2.v - RECEPTOR do teclado PS/2 (a placa so escuta; nunca fala com o teclado)
// =====================================================================================
//
// O QUE FAZ: ouve os dois fios do teclado, monta cada quadro de 11 bits e entrega o codigo
// da tecla (8 bits) com um aviso de 1 ciclo (pronto). Quem interpreta o codigo (apertou,
// soltou, qual nota) e o tradutor_teclas; este modulo so entrega os bytes que chegam.
//
// O QUADRO PS/2 (Chapweske, "The PS/2 Mouse/Keyboard Protocol"):
//   inicio (sempre 0) | 8 bits de dados, o MENOS significativo primeiro | paridade impar | fim (sempre 1)
//   O teclado gera o proprio relogio (10 a 30 kHz, conforme a fonte) e cada bit deve ser lido na
//   BORDA DE DESCIDA desse relogio. Em repouso, os dois fios ficam em 1.
//   Exemplo, tecla A (codigo 1C = 0001 1100):
//     inicio 0 | dados 0 0 1 1 1 0 0 0 (do bit 0 ao bit 7) | paridade 0 | fim 1
//     (os dados ja tem tres bits 1, um numero impar, entao a paridade e 0)
//
// AS 6 PARTES, NA ORDEM EM QUE O SINAL PASSA POR ELAS:
//   1. sincronizar os fios com o relogio da placa (contra metaestabilidade)
//   2. filtrar ruido do relogio do teclado
//   3. detectar a borda de descida (o instante de ler cada bit)
//   4. guardar os bits, contando qual bit do quadro e cada um
//   5. no 11o bit, conferir inicio, fim e paridade e entregar o codigo
//   6. se o teclado parar no meio de um quadro (~2 ms sem borda), recomecar
//
// TESTE: tb/tb_receptor_ps2.v. Esperado: 1C, F0, 1C e 33 recebidos, e o K com paridade
// errada e o quadro cortado descartados ("codigos validos recebidos: 4").
// =====================================================================================
module receptor_ps2 (
    input  wire       clk,        // relogio da placa, 50 MHz
    input  wire       reset,      // 1 = recomeca do zero
    input  wire       ps2_clk,    // fio de relogio do teclado
    input  wire       ps2_dat,    // fio de dados do teclado
    output reg  [7:0] codigo,     // ultimo codigo recebido
    output reg        pronto      // 1 durante um unico ciclo quando chega um codigo valido
);

    // ---------------------------------------------------------------------------------
    // PARTE 1: SINCRONIZAR os fios do teclado com o relogio da placa
    // O teclado muda os fios no ritmo dele, sem relacao com os 50 MHz da placa.
    // Dois flip-flops em sequencia evitam metaestabilidade: o primeiro pode ficar
    // indeciso, mas tem 1 ciclo inteiro para se resolver antes do segundo ler.
    // Usamos SEMPRE a posicao [1] (saida do segundo flip-flop).
    // ---------------------------------------------------------------------------------
    reg [1:0] sinc_clk;   // [0] = 1o flip-flop, [1] = 2o flip-flop (o valor confiavel)
    reg [1:0] sinc_dat;

    always @(posedge clk) begin
        sinc_clk <= {sinc_clk[0], ps2_clk};   // empurra: o valor novo entra em [0], o antigo de [0] vai para [1]
        sinc_dat <= {sinc_dat[0], ps2_dat};
    end

    wire bit_dado = sinc_dat[1];              // o fio de dados, ja sincronizado (e o que sera lido)

    // ---------------------------------------------------------------------------------
    // PARTE 2: FILTRAR o ruido do relogio do teclado
    // Guarda as ultimas 8 leituras do relogio ja sincronizado. O relogio "limpo" so muda
    // quando as 8 forem iguais: um pico de ruido (poucos ciclos) nunca chega a 8 e e
    // ignorado; uma mudanca de verdade passa com ~180 ns de atraso (um bit dura ~80 us).
    // So o relogio e filtrado: o dado so e lido na descida do relogio, quando ja esta
    // parado ha dezenas de microssegundos, entao um pico nele fora desse instante nao importa.
    // ---------------------------------------------------------------------------------
    reg [7:0] amostras;   // ultimas 8 leituras de sinc_clk[1] (a mais nova em [0])
    reg       clk_limpo;  // relogio do teclado sem ruido

    always @(posedge clk) begin
        if (reset) begin
            amostras  <= 8'hFF;     // comeca como se o relogio estivesse em repouso (1)
            clk_limpo <= 1'b1;
        end else begin
            amostras <= {amostras[6:0], sinc_clk[1]};   // empurra a leitura nova, descarta a mais velha
            if (amostras == 8'hFF)      clk_limpo <= 1'b1;   // 8 leituras em 1
            else if (amostras == 8'h00) clk_limpo <= 1'b0;   // 8 leituras em 0
            // senao: leituras misturadas, clk_limpo fica como estava
        end
    end

    // ---------------------------------------------------------------------------------
    // PARTE 3: DETECTAR A BORDA DE DESCIDA do relogio limpo
    // Guarda o valor do ciclo anterior e compara com o de agora: antes 1 e agora 0 e uma
    // descida. O resultado e um pulso de exatamente 1 ciclo, que diz "leia o bit agora".
    // Por que nao usar o relogio do teclado direto no always (@(negedge ps2_clk))?
    // Isso criaria um segundo dominio de relogio no circuito, com os mesmos problemas de
    // sincronizacao da Parte 1. Assim, tudo continua andando no relogio de 50 MHz.
    // ---------------------------------------------------------------------------------
    reg  clk_anterior;                                   // clk_limpo no ciclo anterior
    always @(posedge clk) clk_anterior <= clk_limpo;
    wire borda_descida = clk_anterior & ~clk_limpo;      // 1 so no ciclo em que o relogio desceu

    // ---------------------------------------------------------------------------------
    // PARTES 4, 5 E 6: GUARDAR os bits, CONFERIR o quadro e RECOMECAR se o teclado parar
    // Ficam no mesmo bloco porque mexem nos mesmos registradores (contagem e bits).
    // ---------------------------------------------------------------------------------
    reg [9:0]  bits;      // os 10 primeiros bits do quadro; o 11o (fim) e conferido na hora que chega
    reg [3:0]  contagem;  // quantos bits deste quadro ja chegaram (0 a 10)
    reg [16:0] parado;    // ciclos sem borda no meio de um quadro (17 bits: conta ate 131071, passa de 100000)

    always @(posedge clk) begin
        pronto <= 1'b0;                    // por padrao 0: so vira 1 no ciclo em que um codigo e entregue
        if (reset) begin
            contagem <= 4'd0;
            parado   <= 17'd0;
            codigo   <= 8'd0;
        end else if (borda_descida) begin
            parado <= 17'd0;               // chegou um bit: o teclado nao esta parado
            if (contagem == 4'd10) begin
                // ---- PARTE 5: chegou o 11o bit (o fim). Conferir o quadro inteiro ----
                // Em bits: [0] = inicio, [8:1] = os 8 dados (bit 0 do codigo em [1]), [9] = paridade.
                // As tres condicoes:
                //   inicio == 0, fim (o bit chegando agora) == 1, e
                //   ^bits[9:1] == 1: o OU exclusivo de todos os bits de dados e da paridade da 1
                //   quando a quantidade de bits 1 e impar, que e a regra da paridade impar.
                contagem <= 4'd0;          // em qualquer caso, o proximo bit e o inicio de outro quadro
                if (bits[0] == 1'b0 && bit_dado == 1'b1 && (^bits[9:1]) == 1'b1) begin
                    codigo <= bits[8:1];   // os dados ja estao na ordem certa (ver Parte 4)
                    pronto <= 1'b1;        // avisa por 1 ciclo: "codigo novo"
                end
                // quadro invalido: nao entrega nada, so recomeca
            end else begin
                // ---- PARTE 4: guardar o bit que chegou ----
                // O bit numero N do quadro vai para a posicao N do vetor. Como o teclado manda
                // o bit menos significativo primeiro, o bit 0 do codigo cai em bits[1], o bit 1
                // em bits[2] e assim por diante: no fim, bits[8:1] ja e o codigo na ordem certa.
                bits[contagem] <= bit_dado;
                contagem <= contagem + 4'd1;
            end
        end else if (contagem != 4'd0) begin
            // ---- PARTE 6: no meio de um quadro e sem borda: contar o tempo parado ----
            // Se passar de 100.000 ciclos (100.000 x 20 ns = 2 ms) sem nenhum bit, o quadro foi
            // cortado (teclado desconectado, ruido). Zera a contagem para o proximo quadro
            // comecar alinhado; sem isso, um quadro cortado desalinharia todos os seguintes.
            if (parado == 17'd100000) contagem <= 4'd0;
            else parado <= parado + 17'd1;
        end
    end
endmodule
