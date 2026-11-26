`timescale 1ns/1ps
// tb_tradutor_teclas.v - manda codigos direto para o tradutor (sem receptor) e confere as teclas.
module tb_tradutor_teclas;
    reg clk = 0, reset = 1;
    reg [7:0] codigo = 0;
    reg pronto = 0;
    wire [7:0] teclas;

    tradutor_teclas dut (.clk(clk), .reset(reset), .codigo(codigo), .pronto(pronto), .teclas(teclas));

    always #10 clk = ~clk;

    // simula o receptor: poe o codigo e da um pulso de "pronto" de 1 ciclo
    task chega(input [7:0] c);
        begin
            @(negedge clk) codigo = c; pronto = 1;
            @(negedge clk) pronto = 0;
            repeat (5) @(negedge clk);
        end
    endtask

    integer falhas = 0;
    task confere(input [7:0] esperado, input [8*24-1:0] passo);
        begin
            if (teclas !== esperado) begin
                $display("FALHOU  %0s: teclas=%b, esperado %b", passo, teclas, esperado);
                falhas = falhas + 1;
            end else
                $display("ok      %0s: teclas=%b", passo, teclas);
        end
    endtask

    initial begin
        $dumpfile("tradutor_teclas.vcd");
        $dumpvars(0, tb_tradutor_teclas);
        #100 reset = 0;
        chega(8'h1C);              confere(8'b00000001, "aperta A");
        chega(8'h23);              confere(8'b00000101, "aperta D");
        chega(8'h34);              confere(8'b00010101, "aperta G (acorde)");
        chega(8'h1C);              confere(8'b00010101, "repete A segurado");
        chega(8'hF0); chega(8'h23); confere(8'b00010001, "solta D");
        chega(8'hE0); chega(8'h75); confere(8'b00010001, "seta ignorada");
        chega(8'h1D);              confere(8'b00010001, "W ignorado");
        chega(8'h42);              confere(8'b10010001, "aperta K");
        chega(8'hF0); chega(8'h1C); chega(8'hF0); chega(8'h34); chega(8'hF0); chega(8'h42);
                                   confere(8'b00000000, "solta tudo");
        $display("falhas: %0d", falhas);
        $finish;
    end
endmodule
