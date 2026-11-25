`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_reg_en
//
// Objetivo:
//   Verificar que reg_en captura d solo cuando en = 1, conserva su valor con
//   en = 0 y vuelve a 0 con reset sincrono.
// ============================================================================
module tb_reg_en;

    // ---------------- Senales hacia y desde el registro ----------------
    reg         clk = 0, reset = 0, en = 0;
    reg  [31:0] d = 0;                      // dato de entrada
    wire [31:0] q;                          // valor guardado
    integer     errores = 0;                // contador de pruebas fallidas

    // ---------------- Modulo bajo prueba ----------------
    reg_en #(.WIDTH(32)) dut (.clk(clk), .reset(reset), .en(en), .d(d), .q(q));

    // ---------------- Reloj ----------------
    always #5 clk = ~clk;   // periodo de 10 ns

    // ---------------- Tarea de revision ----------------
    // Compara q con el valor esperado e imprime OK o ERROR
    task revisar(input [31:0] esperado, input [8*40-1:0] caso);
        begin
            if (q !== esperado) begin
                $display("ERROR  %0s: q = %h, esperado %h", caso, q, esperado);
                errores = errores + 1;
            end else
                $display("OK     %0s: q = %h", caso, q);
        end
    endtask

    // ---------------- Estimulos ----------------
    initial begin
        // Los estimulos se cambian en el flanco de bajada para no chocar con
        // el flanco de subida, que es cuando el registro captura.

        // 1. reset = 1 con en = 1: q debe quedar en 0 (el reset tiene prioridad)
        @(negedge clk); reset = 1; en = 1; d = 32'hDEADBEEF;
        @(negedge clk); revisar(32'h0, "1 reset con en=1");

        // 2. en = 1: q debe capturar d
        reset = 0; en = 1; d = 32'h12345678;
        @(negedge clk); revisar(32'h12345678, "2 captura con en=1");

        // 3. en = 0 durante dos flancos: q debe conservar 0x12345678
        en = 0; d = 32'hAAAAAAAA;
        @(negedge clk); @(negedge clk); revisar(32'h12345678, "3 mantiene con en=0");

        // 4. en = 1 otra vez: q captura el nuevo valor
        en = 1; d = 32'h000000FF;
        @(negedge clk); revisar(32'h000000FF, "4 captura nuevo valor");

        // 5. d cambia entre flancos: q no cambia hasta el siguiente flanco
        #2 d = 32'h55555555;
        #1 revisar(32'h000000FF, "5 sin flanco no cambia");

        // 6. reset = 1: q vuelve a 0
        @(negedge clk); reset = 1;
        @(negedge clk); revisar(32'h0, "6 reset vuelve a 0");

        // ---------------- Resumen ----------------
        if (errores == 0) $display("tb_reg_en: TODAS LAS PRUEBAS PASARON");
        else              $display("tb_reg_en: %0d ERRORES", errores);
        $finish;
    end

endmodule
