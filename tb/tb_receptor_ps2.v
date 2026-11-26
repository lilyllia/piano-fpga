`timescale 1ns/1ps
// tb_receptor_ps2.v - um "teclado falso" manda codigos pelos dois fios e conferimos o que o receptor entrega.
module tb_receptor_ps2;
    reg clk = 0, reset = 1;
    reg ps2_clk = 1, ps2_dat = 1;          // fios em repouso ficam em 1
    wire [7:0] codigo;
    wire       pronto;

    receptor_ps2 dut (.clk(clk), .reset(reset), .ps2_clk(ps2_clk), .ps2_dat(ps2_dat),
                      .codigo(codigo), .pronto(pronto));

    always #10 clk = ~clk;                 // 50 MHz: periodo de 20 ns

    // envia um codigo como o teclado faria: relogio de 12,5 kHz (80 us por bit)
    task envia(input [7:0] c, input paridade_errada);
        integer i;
        reg [10:0] quadro;
        begin
            quadro = {1'b1, ~^c ^ paridade_errada, c, 1'b0};   // fim, paridade, dados, inicio
            for (i = 0; i < 11; i = i + 1) begin
                ps2_dat = quadro[i];       // o teclado poe o bit no fio...
                #20000 ps2_clk = 0;        // ...e desce o relogio: hora de ler
                #40000 ps2_clk = 1;
                #20000;
            end
            #100000;                       // pausa entre codigos
        end
    endtask

    integer recebidos = 0;
    always @(posedge clk) if (pronto) begin
        recebidos = recebidos + 1;
        $display("recebido %h (em %0d us)", codigo, $time / 1000);
    end

    initial begin
        $dumpfile("receptor_ps2.vcd");
        $dumpvars(0, tb_receptor_ps2);
        #1000 reset = 0;
        envia(8'h1C, 0);                   // tecla A
        envia(8'hF0, 0);                   // soltou...
        envia(8'h1C, 0);                   // ...a tecla A
        envia(8'h42, 1);                   // K com paridade errada: deve ser descartado
        // quadro cortado no meio (teclado desconectado): so 3 bits
        ps2_dat = 0; #20000 ps2_clk = 0; #40000 ps2_clk = 1; #20000;
        ps2_dat = 1; #20000 ps2_clk = 0; #40000 ps2_clk = 1; #20000;
        ps2_dat = 1; #20000 ps2_clk = 0; #40000 ps2_clk = 1; #20000;
        #3000000;                          // 3 ms parado: o receptor recomeca
        envia(8'h33, 0);                   // tecla H: deve chegar certinho
        $display("codigos validos recebidos: %0d (esperado 4: 1C F0 1C 33)", recebidos);
        $finish;
    end
endmodule
