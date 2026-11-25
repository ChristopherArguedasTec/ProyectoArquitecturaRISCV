`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_imm_gen
//
// Objetivo:
//   Verificar que el generador de inmediatos arma y extiende con signo el
//   inmediato de los cinco formatos (I, S, B, U, J), usando instrucciones
//   reales del programa del proyecto, y que un imm_src no usado da 0.
// ============================================================================
module tb_imm_gen;

    // ---------------- Senales hacia y desde imm_gen ----------------
    reg  [31:0] instr;                      // instruccion (la pone el testbench)
    reg  [2:0]  imm_src;                    // formato
    wire [31:0] imm_ext;                    // inmediato que entrega el modulo
    integer     errores = 0;                // contador de pruebas fallidas

    // ---------------- Modulo bajo prueba ----------------
    imm_gen dut (.instr(instr), .imm_src(imm_src), .imm_ext(imm_ext));

    // ---------------- Tarea de prueba ----------------
    // Pone la instruccion y el formato, espera 1 ns (es combinacional) y
    // compara imm_ext con el valor esperado
    task probar(input [31:0] ins, input [2:0] src, input [31:0] esperado, input [8*30-1:0] caso);
        begin
            instr = ins; imm_src = src; #1;
            if (imm_ext !== esperado) begin
                $display("ERROR  %0s: %h -> %h, esperado %h", caso, ins, imm_ext, esperado);
                errores = errores + 1;
            end else
                $display("OK     %0s: %h -> %h", caso, ins, imm_ext);
        end
    endtask

    // ---------------- Estimulos ----------------
    initial begin
        // Formato I (000)
        probar(32'hfe010113, 3'b000, 32'hFFFFFFE0, "I addi sp,sp,-32");     // -32
        probar(32'h7df78793, 3'b000, 32'h000007DF, "I addi a5,a5,2015");    // +2015, mayor positivo
        probar(32'h00f7f793, 3'b000, 32'h0000000F, "I andi a5,a5,15");      // +15
        probar(32'h00179793, 3'b000, 32'h00000001, "I slli a5,a5,1");       // shamt (24:20)
        probar(32'hfe842783, 3'b000, 32'hFFFFFFE8, "I lw a5,-24(s0)");      // -24
        probar(32'h00008067, 3'b000, 32'h00000000, "I ret");                // jalr, imm 0

        // Formato S (001): inmediato partido en bits 31:25 y 11:7
        probar(32'h00112e23, 3'b001, 32'h0000001C, "S sw ra,28(sp)");       // +28
        probar(32'hfef42623, 3'b001, 32'hFFFFFFEC, "S sw a5,-20(s0)");      // -20
        probar(32'hfef401a3, 3'b001, 32'hFFFFFFE3, "S sb a5,-29(s0)");      // -29

        // Formato B (010): bits reordenados y 0 al final
        probar(32'h00079863, 3'b010, 32'h00000010, "B bnez +16");           // +16
        probar(32'hfce7d0e3, 3'b010, 32'hFFFFFFC0, "B bge -64");            // -64

        // Formato U (011): bits 31:12 arriba y 12 ceros abajo
        probar(32'h0000c7b7, 3'b011, 32'h0000C000, "U lui a5,0xc");

        // Formato J (100): bits reordenados y 0 al final
        probar(32'h03c0006f, 3'b100, 32'h0000003C, "J j +60");              // +60
        probar(32'h01c0006f, 3'b100, 32'h0000001C, "J j +28");              // +28

        // imm_src no usado (111): debe dar 0
        probar(32'hfe010113, 3'b111, 32'h00000000, "imm_src no usado");

        // ---------------- Resumen ----------------
        if (errores == 0) $display("tb_imm_gen: TODAS LAS PRUEBAS PASARON");
        else              $display("tb_imm_gen: %0d ERRORES", errores);
        $finish;
    end

endmodule
