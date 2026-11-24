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
//
// Estimulos (en orden):
//   Entradas fijas y distintas entre si para reconocer cual pasa:
//     d0 = 0xAAAA0000, d1 = 0xBBBB1111, d2 = 0xCCCC2222, d3 = 0xDDDD3333
//   1. sel = 00
//   2. sel = 01
//   3. sel = 10
//   4. sel = 11
//   5. Con sel = 01 se cambia d1 a 0x12345678
//
// Resultados esperados:
//   1. y = d0 = 0xAAAA0000
//   2. y = d1 = 0xBBBB1111
//   3. y = d2 = 0xCCCC2222
//   4. y = d3 = 0xDDDD3333
//   5. y = 0x12345678 de inmediato (la salida sigue a la entrada)
// ============================================================================
module tb_mux4;

    reg  [31:0] d0 = 32'hAAAA0000, d1 = 32'hBBBB1111,
                d2 = 32'hCCCC2222, d3 = 32'hDDDD3333;
    reg  [1:0]  sel;
    wire [31:0] y;
    integer     errores = 0;

    mux4 #(32) dut (.sel(sel), .d0(d0), .d1(d1), .d2(d2), .d3(d3), .y(y));

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
        sel = 2'b00; #1 revisar(32'hAAAA0000, "sel=00 -> d0");
        sel = 2'b01; #1 revisar(32'hBBBB1111, "sel=01 -> d1");
        sel = 2'b10; #1 revisar(32'hCCCC2222, "sel=10 -> d2");
        sel = 2'b11; #1 revisar(32'hDDDD3333, "sel=11 -> d3");

        sel = 2'b01; d1 = 32'h12345678;
        #1 revisar(32'h12345678, "sigue a la entrada");

        if (errores == 0) $display("tb_mux4: TODAS LAS PRUEBAS PASARON");
        else              $display("tb_mux4: %0d ERRORES", errores);
        $finish;
    end

endmodule
