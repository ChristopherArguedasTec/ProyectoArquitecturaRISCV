`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_reg_noen
//
// Objetivo:
//   Verificar que reg_noen captura d en cada flanco de subida (q sigue a d con
//   un ciclo de retraso), no cambia entre flancos y vuelve a 0 con reset.
// ============================================================================
module tb_reg_noen;

    // ---------------- Senales hacia y desde el registro ----------------
    reg         clk = 0, reset = 0;
    reg  [31:0] d = 0;                      // dato de entrada
    wire [31:0] q;                          // valor guardado
    integer     errores = 0;                // contador de pruebas fallidas

    // ---------------- Modulo bajo prueba ----------------
    reg_noen #(.WIDTH(32)) dut (.clk(clk), .reset(reset), .d(d), .q(q));

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
    // Se cambian en el flanco de bajada; el registro captura en el de subida
    initial begin
        // 1. reset = 1: q debe quedar en 0
        @(negedge clk); reset = 1; d = 32'hFFFFFFFF;
        @(negedge clk); revisar(32'h0, "1 reset");

        // 2. Sin enable: q toma d en cada flanco, ciclo tras ciclo
        reset = 0; d = 32'h00000001;
        @(negedge clk); revisar(32'h00000001, "2a captura 1");
        d = 32'h00000002;
        @(negedge clk); revisar(32'h00000002, "2b captura 2");
        d = 32'h0000C7DF;
        @(negedge clk); revisar(32'h0000C7DF, "2c captura C7DF");

        // 3. d cambia entre flancos: q sigue en 0xC7DF hasta el siguiente flanco
        #2 d = 32'hBADBAD00;
        #1 revisar(32'h0000C7DF, "3 sin flanco no cambia");

        // 4. reset = 1: q vuelve a 0
        @(negedge clk); reset = 1;
        @(negedge clk); revisar(32'h0, "4 reset vuelve a 0");

        // ---------------- Resumen ----------------
        if (errores == 0) $display("tb_reg_noen: TODAS LAS PRUEBAS PASARON");
        else              $display("tb_reg_noen: %0d ERRORES", errores);
        $finish;
    end

endmodule
