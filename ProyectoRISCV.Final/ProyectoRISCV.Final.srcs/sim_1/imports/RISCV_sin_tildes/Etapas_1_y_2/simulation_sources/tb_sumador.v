`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_sumador
//
// Objetivo:
//   Verificar la suma de 32 bits en los casos que usa el procesador: PC + 4 y
//   PC + inmediato (positivo y negativo), incluido el desborde de 32 bits.
//   Los valores salen del programa del proyecto.
// ============================================================================
module tb_sumador;

    // ---------------- Senales hacia y desde el sumador ----------------
    reg  [31:0] a, b;                       // operandos (los pone el testbench)
    wire [31:0] y;                          // resultado
    integer     errores = 0;                // contador de pruebas fallidas

    // ---------------- Modulo bajo prueba ----------------
    sumador dut (.a(a), .b(b), .y(y));

    // ---------------- Tarea de prueba ----------------
    // Pone a y b, espera 1 ns (es combinacional) y compara y con el esperado
    task probar(input [31:0] va, input [31:0] vb, input [31:0] esperado, input [8*40-1:0] caso);
        begin
            a = va; b = vb; #1;
            if (y !== esperado) begin
                $display("ERROR  %0s: %h + %h = %h, esperado %h", caso, a, b, y, esperado);
                errores = errores + 1;
            end else
                $display("OK     %0s: %h + %h = %h", caso, a, b, y);
        end
    endtask

    // ---------------- Estimulos ----------------
    initial begin
        // 1 y 2: PC + 4 al inicio y a mitad del programa
        // 3: j +60 (PC + Imm positivo)   4: bge -64 (PC + Imm negativo)
        // 5: bnez +16                     6: desborde, el acarreo se descarta
        //     a             b              esperado
        probar(32'h00000000, 32'd4,         32'h00000004, "1 PC+4 inicio");
        probar(32'h00000034, 32'd4,         32'h00000038, "2 PC+4");
        probar(32'h00000030, 32'h0000003C,  32'h0000006C, "3 PC+Imm positivo (j)");
        probar(32'h00000074, 32'hFFFFFFC0,  32'h00000034, "4 PC+Imm negativo (bge)");
        probar(32'h00000038, 32'h00000010,  32'h00000048, "5 PC+Imm (bnez)");
        probar(32'hFFFFFFFC, 32'd4,         32'h00000000, "6 desborde");

        // ---------------- Resumen ----------------
        if (errores == 0) $display("tb_sumador: TODAS LAS PRUEBAS PASARON");
        else              $display("tb_sumador: %0d ERRORES", errores);
        $finish;
    end

endmodule
