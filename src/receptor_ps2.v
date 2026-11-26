// receptor_ps2.v - recebe os codigos do teclado PS/2 (a placa so escuta; nunca fala com o teclado).
//
// O QUE ESTE MODULO PRECISA FAZER (detalhes e teoria na aba "Pacote A" do guia):
//   O teclado manda cada codigo num quadro de 11 bits pelo fio ps2_dat, no ritmo do proprio relogio (ps2_clk):
//   inicio (0), 8 bits de dados (o menos significativo primeiro), paridade impar, fim (1).
//   Cada bit deve ser lido na borda de descida de ps2_clk.
//   Quando um quadro completo e valido chegar, o modulo coloca o codigo em "codigo" e deixa
//   "pronto" em 1 durante UM ciclo de clk. Quadro invalido (inicio, fim ou paridade errados) e descartado.
//
// PARTES SUGERIDAS (uma de cada vez, testando entre elas):
//   1. sincronizar ps2_clk e ps2_dat com o relogio da placa (dois flip-flops em sequencia)
//   2. filtrar ruido do relogio do teclado
//   3. detectar a borda de descida
//   4. guardar os bits que chegam, contando qual bit do quadro e cada um
//   5. no 11o bit, conferir inicio, fim e paridade e entregar o codigo
//   6. se o teclado parar no meio de um quadro (~2 ms sem borda), recomecar a contagem
//
// TESTE: tb/tb_receptor_ps2.v (veja o LEIA-ME). Pronto quando mostrar os 4 codigos esperados.
module receptor_ps2 (
    input  wire       clk,        // relogio da placa, 50 MHz
    input  wire       reset,      // 1 = recomeca do zero
    input  wire       ps2_clk,    // fio de relogio do teclado
    input  wire       ps2_dat,    // fio de dados do teclado
    output reg  [7:0] codigo,     // ultimo codigo recebido
    output reg        pronto      // 1 durante um unico ciclo quando chega um codigo valido
);

    // escreva aqui

endmodule
