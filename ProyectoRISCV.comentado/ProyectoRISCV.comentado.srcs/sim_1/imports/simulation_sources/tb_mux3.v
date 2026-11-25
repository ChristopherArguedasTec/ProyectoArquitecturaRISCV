`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_mux3
//
// Objetivo:
//   Verificar que el multiplexor de tres entradas (mux3) entrega la entrada
//   que indica sel, que con sel = 11 (valor que no se usa) entrega d0, y que
//   la salida sigue a la entrada sin esperar el reloj (es combinacional).
//   En el procesador es el multiplexor PCSrc: d0 = PC + 4, d1 = PC + Imm y
//   d2 = ALUOut con el bit 0 en cero (destino de jalr).
// ============================================================================
module tb_mux3;

    // ---------------- Senales hacia y desde el mux ----------------
    // Entradas fijas y distintas entre si para reconocer cual pasa
    reg  [31:0] d0 = 32'hAAAA0000, d1 = 32'hBBBB1111, d2 = 32'hCCCC2222;
    reg  [1:0]  sel;                        // seleccion de 2 bits
    wire [31:0] y;                          // salida
    integer     errores = 0;                // contador de pruebas fallidas

    // ---------------- Modulo bajo prueba ----------------
    mux3 #(32) dut (.sel(sel), .d0(d0), .d1(d1), .d2(d2), .y(y));

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
        sel = 2'b00; #1 revisar(32'hAAAA0000, "sel=00 -> d0");             // 1. debe salir d0
        sel = 2'b01; #1 revisar(32'hBBBB1111, "sel=01 -> d1");             // 2. debe salir d1
        sel = 2'b10; #1 revisar(32'hCCCC2222, "sel=10 -> d2");             // 3. debe salir d2
        sel = 2'b11; #1 revisar(32'hAAAA0000, "sel=11 -> d0 (defecto)");   // 4. sale d0

        // 5. Con sel = 10 se cambia d2: y debe cambiar de inmediato, sin reloj
        sel = 2'b10; d2 = 32'h12345678;
        #1 revisar(32'h12345678, "sigue a la entrada");

        // ---------------- Resumen ----------------
        if (errores == 0) $display("tb_mux3: TODAS LAS PRUEBAS PASARON");
        else              $display("tb_mux3: %0d ERRORES", errores);
        $finish;
    end

endmodule
