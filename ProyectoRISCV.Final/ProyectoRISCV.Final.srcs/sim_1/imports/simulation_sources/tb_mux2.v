`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_mux2
//
// Objetivo:
//   Verificar que el multiplexor de dos entradas (mux2) entrega d0 con
//   sel = 0 y d1 con sel = 1, y que la salida sigue a la entrada sin esperar
//   el reloj (es combinacional). En el procesador es el multiplexor ALUSrc:
//   d0 = registro B y d1 = inmediato (ImmExt).
//
// Estimulos (en orden):
//   Entradas fijas y distintas entre si para reconocer cual pasa:
//     d0 = 0xAAAA0000, d1 = 0xBBBB1111
//   1. sel = 0
//   2. sel = 1
//   3. Con sel = 1 se cambia d1 a 0x12345678
//
// Resultados esperados:
//   1. y = d0 = 0xAAAA0000
//   2. y = d1 = 0xBBBB1111
//   3. y = 0x12345678 de inmediato (la salida sigue a la entrada)
// ============================================================================
module tb_mux2;

    reg  [31:0] d0 = 32'hAAAA0000, d1 = 32'hBBBB1111;
    reg         sel;
    wire [31:0] y;
    integer     errores = 0;

    mux2 #(32) dut (.sel(sel), .d0(d0), .d1(d1), .y(y));

    task revisar(input [31:0] esperado, input [8*40-1:0] caso);
        begin
            if (y !== esperado) begin
                $display("ERROR  %0s: y = %h, esperado %h", caso, y, esperado);
                errores = errores + 1;
            end else
                $display("OK     %0s: y = %h", caso, y);
        end
    endtask

    initial begin
        sel = 1'b0; #1 revisar(32'hAAAA0000, "sel=0 -> d0");
        sel = 1'b1; #1 revisar(32'hBBBB1111, "sel=1 -> d1");

        d1 = 32'h12345678;
        #1 revisar(32'h12345678, "sigue a la entrada");

        if (errores == 0) $display("tb_mux2: TODAS LAS PRUEBAS PASARON");
        else              $display("tb_mux2: %0d ERRORES", errores);
        $finish;
    end

endmodule
