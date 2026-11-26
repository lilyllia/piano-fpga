// tradutor_teclas.v - transforma os codigos do teclado no vetor de 8 notas (o mesmo formato das chaves SW[7:0]).
//
// O QUE ESTE MODULO PRECISA FAZER (detalhes e teoria na aba "Pacote B" do guia):
//   Cada vez que "pronto" vale 1, chegou um codigo novo em "codigo".
//   - Apertar uma tecla: chega o codigo dela -> liga o bit da nota.
//   - Soltar: chega F0 e depois o codigo -> desliga o bit da nota.
//   - Prefixo E0 (setas e outras teclas estendidas): o codigo seguinte deve ser ignorado.
//   - Qualquer tecla fora da tabela abaixo: ignorada.
//
//   Tecla:  A    S    D    F    G    H    J    K
//   Codigo: 1C   1B   23   2B   34   33   3B   42
//   Nota:   C4   D4   E4   F4   G4   A4   B4   C5
//   Bit:    0    1    2    3    4    5    6    7
//
// PARTES SUGERIDAS:
//   1. a tabela codigo -> qual bit (e se e uma das 8 teclas)
//   2. lembrar se o codigo anterior foi F0 ou E0
//   3. ligar ou desligar o bit certo quando chega um codigo de tecla
//
// TESTE: tb/tb_tradutor_teclas.v (veja o LEIA-ME). Pronto quando mostrar "falhas: 0".
module tradutor_teclas (
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] codigo,     // vem do receptor
    input  wire       pronto,     // vem do receptor: 1 quando chega um codigo novo
    output reg  [7:0] teclas      // bit ligado = nota tocando
);

    // escreva aqui

endmodule
