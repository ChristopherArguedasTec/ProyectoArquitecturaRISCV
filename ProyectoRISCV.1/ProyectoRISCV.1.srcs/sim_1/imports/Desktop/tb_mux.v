`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_mux  (prueba mux2, mux3 y mux4)
//
// Objetivo:
//   Verificar que cada multiplexor entrega la entrada correspondiente a cada
//   valor de sel, y que mux3 con sel = 11 (no usado) entrega d0.
//
// Estímulos:
//   Entradas fijas y distintas entre sí para poder reconocer cuál pasó:
//     d0 = 0xAAAA0000, d1 = 0xBBBB1111, d2 = 0xCCCC2222, d3 = 0xDDDD3333
//   mux2: sel = 0, 1.
//   mux3: sel = 00, 01, 10, 11.
//   mux4: sel = 00, 01, 10, 11.
//   Al final se cambia d1 con sel fijo para ver que la salida sigue a la
//   entrada (es combinacional).
//
// Resultados esperados:
//   mux2: 0 -> d0, 1 -> d1.
//   mux3: 00 -> d0, 01 -> d1, 10 -> d2, 11 -> d0 (valor por defecto).
//   mux4: 00 -> d0, 01 -> d1, 10 -> d2, 11 -> d3.
//   Cambio de d1 con sel = 01: la salida cambia de inmediato al nuevo d1.
// ============================================================================
module tb_mux;

    reg  [31:0] d0 = 32'hAAAA0000, d1 = 32'hBBBB1111,
                d2 = 32'hCCCC2222, d3 = 32'hDDDD3333;
    reg         sel2;
    reg  [1:0]  sel3, sel4;
    wire [31:0] y2, y3, y4;
    integer     errores = 0;

    mux2 #(32) u_m2 (.sel(sel2), .d0(d0), .d1(d1), .y(y2));
    mux3 #(32) u_m3 (.sel(sel3), .d0(d0), .d1(d1), .d2(d2), .y(y3));
    mux4 #(32) u_m4 (.sel(sel4), .d0(d0), .d1(d1), .d2(d2), .d3(d3), .y(y4));

    task revisar(input [31:0] y, input [31:0] esperado, input [8*40-1:0] caso);
        begin
            if (y !== esperado) begin
                $display("ERROR  %0s: y = %h, esperado %h", caso, y, esperado);
                errores = errores + 1;
            end else
                $display("OK     %0s: y = %h", caso, y);
        end
    endtask

    initial begin
        sel2 = 0;     #1 revisar(y2, d0, "mux2 sel=0");
        sel2 = 1;     #1 revisar(y2, d1, "mux2 sel=1");

        sel3 = 2'b00; #1 revisar(y3, d0, "mux3 sel=00");
        sel3 = 2'b01; #1 revisar(y3, d1, "mux3 sel=01");
        sel3 = 2'b10; #1 revisar(y3, d2, "mux3 sel=10");
        sel3 = 2'b11; #1 revisar(y3, d0, "mux3 sel=11 (defecto)");

        sel4 = 2'b00; #1 revisar(y4, d0, "mux4 sel=00");
        sel4 = 2'b01; #1 revisar(y4, d1, "mux4 sel=01");
        sel4 = 2'b10; #1 revisar(y4, d2, "mux4 sel=10");
        sel4 = 2'b11; #1 revisar(y4, d3, "mux4 sel=11");

        sel4 = 2'b01; d1 = 32'h12345678;
        #1 revisar(y4, 32'h12345678, "mux4 sigue a la entrada");

        if (errores == 0) $display("tb_mux: TODAS LAS PRUEBAS PASARON");
        else              $display("tb_mux: %0d ERRORES", errores);
        $finish;
    end

endmodule
