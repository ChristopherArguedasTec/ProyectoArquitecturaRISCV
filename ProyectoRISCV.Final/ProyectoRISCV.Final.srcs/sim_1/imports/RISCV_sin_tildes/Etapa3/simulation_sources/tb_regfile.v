`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_regfile
//
// Objetivo:
//   Verificar el banco de registros: reset, escritura sincrona con we, lectura
//   combinacional por los dos puertos, que x0 siempre vale 0 y que la
//   escritura no se ve antes del flanco.
//
// Estimulos (en orden):
//   1. reset = 1 durante un flanco; leer x5 y x31.
//   2. Escribir x5 = 0x00000021 (b = 33) con we = 1 -> flanco; leer x5 por
//      los dos puertos.
//   3. Escribir x15 (a5) = 0x0000C7DF -> flanco; leer x5 por ra1 y x15 por
//      ra2 al mismo tiempo.
//   4. Intentar escribir x0 = 0xFFFFFFFF con we = 1 -> flanco; leer x0.
//   5. we = 0, wa = x5, wd = 0xDEADBEEF -> flanco; leer x5.
//   6. we = 1, wa = x2 (sp), wd = 0xFFFFFFE0, sin flanco todavia; leer x2.
//      Luego flanco y leer x2 otra vez.
//   7. reset = 1 -> flanco; leer x15.
//
// Resultados esperados:
//   1. x5 = 0, x31 = 0.
//   2. rd1 = rd2 = 0x00000021.
//   3. rd1 = 0x00000021, rd2 = 0x0000C7DF.
//   4. x0 = 0 (la escritura se ignora).
//   5. x5 sigue en 0x00000021 (no escribe con we = 0).
//   6. Antes del flanco x2 = 0; despues x2 = 0xFFFFFFE0.
//   7. x15 = 0.
// ============================================================================
module tb_regfile;

    reg         clk = 0, reset = 0, we = 0;
    reg  [4:0]  ra1 = 0, ra2 = 0, wa = 0;
    reg  [31:0] wd = 0;
    wire [31:0] rd1, rd2;
    integer     errores = 0;

    regfile dut (.clk(clk), .reset(reset), .we(we), .ra1(ra1), .ra2(ra2),
                 .wa(wa), .wd(wd), .rd1(rd1), .rd2(rd2));

    always #5 clk = ~clk;

    task revisar(input [31:0] valor, input [31:0] esperado, input [8*44-1:0] caso);
        begin
            if (valor !== esperado) begin
                $display("ERROR  %0s: %h, esperado %h", caso, valor, esperado);
                errores = errores + 1;
            end else
                $display("OK     %0s: %h", caso, valor);
        end
    endtask

    initial begin
        // 1. reset
        @(negedge clk); reset = 1;
        @(negedge clk); reset = 0;
        ra1 = 5'd5; ra2 = 5'd31; #1;
        revisar(rd1, 32'h0, "1 reset x5");
        revisar(rd2, 32'h0, "1 reset x31");

        // 2. escribir x5
        we = 1; wa = 5'd5; wd = 32'h00000021;
        @(negedge clk); we = 0;
        ra1 = 5'd5; ra2 = 5'd5; #1;
        revisar(rd1, 32'h00000021, "2 x5 por ra1");
        revisar(rd2, 32'h00000021, "2 x5 por ra2");

        // 3. escribir x15 y leer dos registros distintos
        we = 1; wa = 5'd15; wd = 32'h0000C7DF;
        @(negedge clk); we = 0;
        ra1 = 5'd5; ra2 = 5'd15; #1;
        revisar(rd1, 32'h00000021, "3 x5 por ra1");
        revisar(rd2, 32'h0000C7DF, "3 x15 por ra2");

        // 4. intentar escribir x0
        we = 1; wa = 5'd0; wd = 32'hFFFFFFFF;
        @(negedge clk); we = 0;
        ra1 = 5'd0; #1;
        revisar(rd1, 32'h0, "4 x0 siempre 0");

        // 5. we = 0 no escribe
        we = 0; wa = 5'd5; wd = 32'hDEADBEEF;
        @(negedge clk);
        ra1 = 5'd5; #1;
        revisar(rd1, 32'h00000021, "5 we=0 no escribe");

        // 6. la escritura solo se ve despues del flanco
        we = 1; wa = 5'd2; wd = 32'hFFFFFFE0; ra1 = 5'd2; #1;
        revisar(rd1, 32'h0, "6 sp antes del flanco");
        @(negedge clk); we = 0; #1;
        revisar(rd1, 32'hFFFFFFE0, "6 sp despues del flanco");

        // 7. reset borra todo
        reset = 1;
        @(negedge clk); reset = 0;
        ra2 = 5'd15; #1;
        revisar(rd2, 32'h0, "7 reset borra x15");

        if (errores == 0) $display("tb_regfile: TODAS LAS PRUEBAS PASARON");
        else              $display("tb_regfile: %0d ERRORES", errores);
        $finish;
    end

endmodule
