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
//
// Estimulos (en orden):
//   Entradas fijas y distintas entre si para reconocer cual pasa:
//     d0 = 0xAAAA0000, d1 = 0xBBBB1111, d2 = 0xCCCC2222
//   1. sel = 00
//   2. sel = 01
//   3. sel = 10
//   4. sel = 11 (no lo genera la unidad de control)
//   5. Con sel = 10 se cambia d2 a 0x12345678
//
// Resultados esperados:
//   1. y = d0 = 0xAAAA0000
//   2. y = d1 = 0xBBBB1111
//   3. y = d2 = 0xCCCC2222
//   4. y = d0 = 0xAAAA0000 (valor por defecto)
//   5. y = 0x12345678 de inmediato (la salida sigue a la entrada)
// ============================================================================
module tb_mux3;

    reg  [31:0] d0 = 32'hAAAA0000, d1 = 32'hBBBB1111, d2 = 32'hCCCC2222;
    reg  [1:0]  sel;
    wire [31:0] y;
    integer     errores = 0;

    mux3 #(32) dut (.sel(sel), .d0(d0), .d1(d1), .d2(d2), .y(y));

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
        sel = 2'b11; #1 revisar(32'hAAAA0000, "sel=11 -> d0 (defecto)");

        sel = 2'b10; d2 = 32'h12345678;
        #1 revisar(32'h12345678, "sigue a la entrada");

        if (errores == 0) $display("tb_mux3: TODAS LAS PRUEBAS PASARON");
        else              $display("tb_mux3: %0d ERRORES", errores);
        $finish;
    end

endmodule
