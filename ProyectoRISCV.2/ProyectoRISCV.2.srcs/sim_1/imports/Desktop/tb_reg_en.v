`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_reg_en
//
// Objetivo:
//   Verificar que reg_en captura d solo cuando en = 1, conserva su valor con
//   en = 0 y vuelve a 0 con reset síncrono.
//
// Estímulos (en orden):
//   1. reset = 1 durante un flanco con d = 0xDEADBEEF y en = 1.
//   2. reset = 0, en = 1, d = 0x12345678 -> flanco.
//   3. en = 0, d = 0xAAAAAAAA -> dos flancos.
//   4. en = 1, d = 0x000000FF -> flanco.
//   5. d cambia a 0x55555555 entre flancos (sin flanco) con en = 1.
//   6. reset = 1 con en = 1 -> flanco.
//
// Resultados esperados:
//   1. q = 0 (el reset tiene prioridad sobre en).
//   2. q = 0x12345678.
//   3. q sigue en 0x12345678 (no captura con en = 0).
//   4. q = 0x000000FF.
//   5. q no cambia hasta el siguiente flanco (0x000000FF).
//   6. q = 0.
// ============================================================================
module tb_reg_en;

    reg         clk = 0, reset = 0, en = 0;
    reg  [31:0] d = 0;
    wire [31:0] q;
    integer     errores = 0;

    reg_en #(.WIDTH(32)) dut (.clk(clk), .reset(reset), .en(en), .d(d), .q(q));

    always #5 clk = ~clk;   // periodo de 10 ns

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
        // Los estímulos se cambian en el flanco de bajada para no chocar con
        // el flanco de subida, que es cuando el registro captura.
        @(negedge clk); reset = 1; en = 1; d = 32'hDEADBEEF;
        @(negedge clk); revisar(32'h0, "1 reset con en=1");

        reset = 0; en = 1; d = 32'h12345678;
        @(negedge clk); revisar(32'h12345678, "2 captura con en=1");

        en = 0; d = 32'hAAAAAAAA;
        @(negedge clk); @(negedge clk); revisar(32'h12345678, "3 mantiene con en=0");

        en = 1; d = 32'h000000FF;
        @(negedge clk); revisar(32'h000000FF, "4 captura nuevo valor");

        #2 d = 32'h55555555;
        #1 revisar(32'h000000FF, "5 sin flanco no cambia");

        @(negedge clk); reset = 1;
        @(negedge clk); revisar(32'h0, "6 reset vuelve a 0");

        if (errores == 0) $display("tb_reg_en: TODAS LAS PRUEBAS PASARON");
        else              $display("tb_reg_en: %0d ERRORES", errores);
        $finish;
    end

endmodule
