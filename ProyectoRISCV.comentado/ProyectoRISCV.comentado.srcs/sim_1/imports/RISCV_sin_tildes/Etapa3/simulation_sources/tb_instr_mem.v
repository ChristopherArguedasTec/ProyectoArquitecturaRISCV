`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_instr_mem
//
// Objetivo:
//   Verificar que la memoria de instrucciones carga programa.hex (las 36
//   instrucciones de main) y que cada direccion entrega la instruccion que
//   indica el desensamblado. Tambien que despues del programa hay ceros.
// ============================================================================
module tb_instr_mem;

    // ---------------- Senales hacia y desde la memoria ----------------
    reg  [31:0] addr;                       // direccion en bytes
    wire [31:0] data;                       // instruccion leida
    integer     errores = 0;                // contador de pruebas fallidas

    // ---------------- Modulo bajo prueba ----------------
    instr_mem #(.DEPTH(256), .FILE("programa.hex")) dut (.addr(addr), .data(data));

    // ---------------- Tarea de prueba ----------------
    // Pone la direccion, espera 1 ns (lectura combinacional) y compara la
    // instruccion con la del desensamblado
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

    // ---------------- Estimulos ----------------
    initial begin
        #1;                                                 // deja que $readmemh cargue
        // Instrucciones del programa
        probar(32'h00, 32'hfe010113, "addi sp,sp,-32");             // primera instruccion
        probar(32'h04, 32'h00112e23, "sw ra,28(sp)");               // segunda instruccion
        probar(32'h10, 32'h0000c7b7, "lui a5,0xc");
        probar(32'h20, 32'hfef401a3, "sb a5,-29(s0)");
        probar(32'h38, 32'h00079863, "bnez a5");
        probar(32'h74, 32'hfce7d0e3, "bge a5,a4");
        probar(32'h8C, 32'h00008067, "ret");                        // ultima instruccion
        // Fuera del programa: ceros
        probar(32'h90, 32'h00000000, "despues del programa");
        probar(32'h3FC, 32'h00000000, "ultima palabra");            // indice 255
        // Direccion no alineada: los bits 1:0 se ignoran, sale la de 0x00
        probar(32'h02, 32'hfe010113, "no alineada (ignora bits 1:0)");

        // ---------------- Resumen ----------------
        if (errores == 0) $display("tb_instr_mem: TODAS LAS PRUEBAS PASARON");
        else              $display("tb_instr_mem: %0d ERRORES", errores);
        $finish;
    end

endmodule
