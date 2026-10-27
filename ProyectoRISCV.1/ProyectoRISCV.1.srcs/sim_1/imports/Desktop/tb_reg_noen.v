`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_reg_noen
//
// Objetivo:
//   Verificar que reg_noen captura d en cada flanco de subida (q sigue a d con
//   un ciclo de retraso), no cambia entre flancos y vuelve a 0 con reset.
//
// Estímulos (en orden):
//   1. reset = 1 durante un flanco con d = 0xFFFFFFFF.
//   2. reset = 0; d toma 0x00000001, 0x00000002 y 0xC7DF en ciclos seguidos.
//   3. d cambia a 0xBADBAD00 entre flancos (sin flanco).
//   4. reset = 1 -> flanco.
//
// Resultados esperados:
//   1. q = 0.
//   2. Después de cada flanco q toma el valor de d de ese ciclo:
//      0x00000001, 0x00000002, 0x0000C7DF.
//   3. q sigue en 0x0000C7DF hasta el siguiente flanco.
//   4. q = 0.
// ============================================================================
module tb_reg_noen;

    reg         clk = 0, reset = 0;
    reg  [31:0] d = 0;
    wire [31:0] q;
    integer     errores = 0;

    reg_noen #(.WIDTH(32)) dut (.clk(clk), .reset(reset), .d(d), .q(q));

    always #5 clk = ~clk;

    task revisar(input [31:0] esperado, input [8*40-1:0] caso);
        begin
            if (q !== esperado) begin
                $display("ERROR  %0s: q = %h, esperado %h", caso, q, esperado);
                errores = errores + 1;
            end else
                $display("OK     %0s: q = %h", caso, q);
        end
    endtask

    initial begin
        @(negedge clk); reset = 1; d = 32'hFFFFFFFF;
        @(negedge clk); revisar(32'h0, "1 reset");

        reset = 0; d = 32'h00000001;
        @(negedge clk); revisar(32'h00000001, "2a captura 1");
        d = 32'h00000002;
        @(negedge clk); revisar(32'h00000002, "2b captura 2");
        d = 32'h0000C7DF;
        @(negedge clk); revisar(32'h0000C7DF, "2c captura C7DF");

        #2 d = 32'hBADBAD00;
        #1 revisar(32'h0000C7DF, "3 sin flanco no cambia");

        @(negedge clk); reset = 1;
        @(negedge clk); revisar(32'h0, "4 reset vuelve a 0");

        if (errores == 0) $display("tb_reg_noen: TODAS LAS PRUEBAS PASARON");
        else              $display("tb_reg_noen: %0d ERRORES", errores);
        $finish;
    end

endmodule
