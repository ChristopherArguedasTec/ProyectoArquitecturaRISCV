`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_instr_mem
//
// Objetivo:
//   Verificar que la memoria de instrucciones carga programa.hex (las 36
//   instrucciones de main) y que cada direccion entrega la instruccion que
//   indica el desensamblado. Tambien que despues del programa hay ceros.
//
// Estimulos: leer estas direcciones (en bytes)
//   0x00  primera instruccion          0x04  segunda instruccion
//   0x10  lui a5,0xc                   0x20  sb a5,-29(s0)
//   0x38  bnez a5                      0x74  bge a5,a4
//   0x8C  ret (ultima instruccion)     0x90  despues del programa
//   0x3FC ultima palabra de la memoria (indice 255)
//   0x02  direccion no alineada (los bits 1:0 se ignoran)
//
// Resultados esperados (del desensamblado de main):
//   0x00 -> fe010113   0x04 -> 00112e23   0x10 -> 0000c7b7   0x20 -> fef401a3
//   0x38 -> 00079863   0x74 -> fce7d0e3   0x8C -> 00008067   0x90 -> 00000000
//   0x3FC -> 00000000  0x02 -> fe010113
// ============================================================================
module tb_instr_mem;

    reg  [31:0] addr;
    wire [31:0] data;
    integer     errores = 0;

    instr_mem #(.DEPTH(256), .FILE("programa.hex")) dut (.addr(addr), .data(data));

    task probar(input [31:0] a, input [31:0] esperado, input [8*36-1:0] caso);
        begin
            addr = a; #1;
            if (data !== esperado) begin
                $display("ERROR  %0s: mem[%h] = %h, esperado %h", caso, a, data, esperado);
                errores = errores + 1;
            end else
                $display("OK     %0s: mem[%h] = %h", caso, a, data);
        end
    endtask

    initial begin
        #1;
        probar(32'h00, 32'hfe010113, "addi sp,sp,-32");
        probar(32'h04, 32'h00112e23, "sw ra,28(sp)");
        probar(32'h10, 32'h0000c7b7, "lui a5,0xc");
        probar(32'h20, 32'hfef401a3, "sb a5,-29(s0)");
        probar(32'h38, 32'h00079863, "bnez a5");
        probar(32'h74, 32'hfce7d0e3, "bge a5,a4");
        probar(32'h8C, 32'h00008067, "ret");
        probar(32'h90, 32'h00000000, "despues del programa");
        probar(32'h3FC, 32'h00000000, "ultima palabra");
        probar(32'h02, 32'hfe010113, "no alineada (ignora bits 1:0)");

        if (errores == 0) $display("tb_instr_mem: TODAS LAS PRUEBAS PASARON");
        else              $display("tb_instr_mem: %0d ERRORES", errores);
        $finish;
    end

endmodule
