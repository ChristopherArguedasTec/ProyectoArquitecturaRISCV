`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_mux2
//
// Objetivo:
//   Verificar que el multiplexor de dos entradas (mux2) entrega d0 con
//   sel = 0 y d1 con sel = 1, y que la salida sigue a la entrada sin esperar
//   el reloj (es combinacional). En el procesador es el multiplexor ALUSrc:
//   d0 = registro B y d1 = inmediato (ImmExt).
// ============================================================================
module tb_mux2;

    // ---------------- Senales hacia y desde el mux ----------------
    // Entradas fijas y distintas entre si para reconocer cual pasa
    reg  [31:0] d0 = 32'hAAAA0000, d1 = 32'hBBBB1111;
    reg         sel;                        // seleccion
    wire [31:0] y;                          // salida
    integer     errores = 0;                // contador de pruebas fallidas

    // ---------------- Modulo bajo prueba ----------------
    mux2 #(32) dut (.sel(sel), .d0(d0), .d1(d1), .y(y));

    // ---------------- Tarea de revision ----------------
    // Compara y con el valor esperado e imprime OK o ERROR
    task revisar(input [31:0] esperado, input [8*40-1:0] caso);
        begin
            if (y !== esperado) begin
                $display("ERROR  %0s: y = %h, esperado %h", caso, y, esperado);
                errores = errores + 1;
            end else
                $display("OK     %0s: y = %h", caso, y);
        end
    endtask

    // ---------------- Estimulos ----------------
    // Despues de cada cambio se espera 1 ns para que la salida se actualice
    initial begin
        sel = 1'b0; #1 revisar(32'hAAAA0000, "sel=0 -> d0");    // 1. debe salir d0
        sel = 1'b1; #1 revisar(32'hBBBB1111, "sel=1 -> d1");    // 2. debe salir d1

        // 3. Con sel = 1 se cambia d1: y debe cambiar de inmediato, sin reloj
        d1 = 32'h12345678;
        #1 revisar(32'h12345678, "sigue a la entrada");

        // ---------------- Resumen ----------------
        if (errores == 0) $display("tb_mux2: TODAS LAS PRUEBAS PASARON");
        else              $display("tb_mux2: %0d ERRORES", errores);
        $finish;
    end

endmodule
