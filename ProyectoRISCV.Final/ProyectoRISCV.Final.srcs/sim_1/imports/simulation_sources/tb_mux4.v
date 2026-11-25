`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_mux4
//
// Objetivo:
//   Verificar que el multiplexor de cuatro entradas (mux4) entrega la entrada
//   que indica sel para los cuatro valores posibles, y que la salida sigue a
//   la entrada sin esperar el reloj (es combinacional). En el procesador es
//   el multiplexor ResultSrc: d0 = ALUOut, d1 = MDR, d2 = PC + 4 y
//   d3 = inmediato (ImmExt, para lui).
// ============================================================================
module tb_mux4;

    // ---------------- Senales hacia y desde el mux ----------------
    // Entradas fijas y distintas entre si para reconocer cual pasa
    reg  [31:0] d0 = 32'hAAAA0000, d1 = 32'hBBBB1111,
                d2 = 32'hCCCC2222, d3 = 32'hDDDD3333;
    reg  [1:0]  sel;                        // seleccion de 2 bits
    wire [31:0] y;                          // salida
    integer     errores = 0;                // contador de pruebas fallidas

    // ---------------- Modulo bajo prueba ----------------
    mux4 #(32) dut (.sel(sel), .d0(d0), .d1(d1), .d2(d2), .d3(d3), .y(y));

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
        sel = 2'b00; #1 revisar(32'hAAAA0000, "sel=00 -> d0");    // 1. debe salir d0
        sel = 2'b01; #1 revisar(32'hBBBB1111, "sel=01 -> d1");    // 2. debe salir d1
        sel = 2'b10; #1 revisar(32'hCCCC2222, "sel=10 -> d2");    // 3. debe salir d2
        sel = 2'b11; #1 revisar(32'hDDDD3333, "sel=11 -> d3");    // 4. debe salir d3

        // 5. Con sel = 01 se cambia d1: y debe cambiar de inmediato, sin reloj
        sel = 2'b01; d1 = 32'h12345678;
        #1 revisar(32'h12345678, "sigue a la entrada");

        // ---------------- Resumen ----------------
        if (errores == 0) $display("tb_mux4: TODAS LAS PRUEBAS PASARON");
        else              $display("tb_mux4: %0d ERRORES", errores);
        $finish;
    end

endmodule
