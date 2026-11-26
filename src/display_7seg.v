// display_7seg.v - mostra um digito de 0 a 9 num display de 7 segmentos da DE1.
//
// O QUE ESTE MODULO PRECISA FAZER (detalhes na aba "Pacote C" do guia):
//   Para cada valor de "digito" de 0 a 9, acender os segmentos que desenham aquele numero.
//   Valores de 10 a 15 apagam o display.
//   Na DE1 cada segmento ACENDE COM 0.
//
//   Nomes dos segmentos:        aaa
//   seg[0] = a  seg[4] = e     f   b
//   seg[1] = b  seg[5] = f      ggg
//   seg[2] = c  seg[6] = g     e   c
//   seg[3] = d                  ddd
//
// TESTE: tb/tb_display_7seg.v (veja o LEIA-ME). Ele desenha cada digito na tela com '#':
//   pronto quando os desenhos de 0 a 9 parecerem os numeros certos e 10 a 15 aparecerem apagados.
module display_7seg (
    input  wire [3:0] digito,
    output reg  [6:0] seg
);

    // escreva aqui

endmodule
