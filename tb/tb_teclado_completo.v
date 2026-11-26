`timescale 1ns/1ps
// tb_teclado_completo.v - teclado falso -> receptor -> tradutor: confere as teclas no fim da cadeia.
module tb_teclado_completo;
    reg clk = 0, reset = 1, ps2_clk = 1, ps2_dat = 1;
    wire [7:0] codigo, teclas;
    wire pronto;
    receptor_ps2    u_rx  (.clk(clk), .reset(reset), .ps2_clk(ps2_clk), .ps2_dat(ps2_dat), .codigo(codigo), .pronto(pronto));
    tradutor_teclas u_tec (.clk(clk), .reset(reset), .codigo(codigo), .pronto(pronto), .teclas(teclas));
    always #10 clk = ~clk;

    task envia(input [7:0] c);
        integer i; reg [10:0] quadro;
        begin
            quadro = {1'b1, ~^c, c, 1'b0};
            for (i = 0; i < 11; i = i + 1) begin
                ps2_dat = quadro[i]; #20000 ps2_clk = 0; #40000 ps2_clk = 1; #20000;
            end
            #100000;
        end
    endtask

    integer falhas = 0;
    task confere(input [7:0] esperado, input [8*24-1:0] passo);
        begin
            if (teclas !== esperado) begin $display("FALHOU  %0s: %b", passo, teclas); falhas = falhas + 1; end
            else $display("ok      %0s: %b", passo, teclas);
        end
    endtask

    integer k;
    reg [7:0] cod [0:7];
    initial begin
        cod[0]=8'h1C; cod[1]=8'h1B; cod[2]=8'h23; cod[3]=8'h2B; cod[4]=8'h34; cod[5]=8'h33; cod[6]=8'h3B; cod[7]=8'h42;
        #1000 reset = 0;
        for (k = 0; k < 8; k = k + 1) begin
            envia(cod[k]);
            if (teclas !== (8'd1 << k)) begin $display("FALHOU tecla %0d: %b", k, teclas); falhas = falhas + 1; end
            envia(8'hF0); envia(cod[k]);
        end
        confere(8'b00000000, "escala tocada e solta");
        envia(8'h1C); envia(8'h23); envia(8'h34);
        confere(8'b00010101, "acorde A D G");
        $display("falhas: %0d", falhas);
        $finish;
    end
endmodule
