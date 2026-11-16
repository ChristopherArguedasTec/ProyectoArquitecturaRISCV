`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_imm_gen
//
// Objetivo:
//   Verificar que el generador de inmediatos arma y extiende con signo el
//   inmediato de los cinco formatos (I, S, B, U, J), usando instrucciones
//   reales del programa del proyecto, y que un imm_src no usado da 0.
//
// Estímulos (instrucción, imm_src) y resultado esperado (imm_ext):
//   I  fe010113 addi sp,sp,-32      -> 0xFFFFFFE0  (-32)
//   I  7df78793 addi a5,a5,2015     -> 0x000007DF  (+2015, positivo máximo usado)
//   I  00f7f793 andi a5,a5,15       -> 0x0000000F
//   I  00179793 slli a5,a5,1        -> 0x00000001  (shamt en bits 24:20)
//   I  fe842783 lw a5,-24(s0)       -> 0xFFFFFFE8  (-24)
//   I  00008067 ret (jalr)          -> 0x00000000
//   S  00112e23 sw ra,28(sp)        -> 0x0000001C  (+28)
//   S  fef42623 sw a5,-20(s0)       -> 0xFFFFFFEC  (-20)
//   S  fef401a3 sb a5,-29(s0)       -> 0xFFFFFFE3  (-29)
//   B  00079863 bnez a5,+16         -> 0x00000010  (+16)
//   B  fce7d0e3 bge a5,a4,-64       -> 0xFFFFFFC0  (-64)
//   U  0000c7b7 lui a5,0xc          -> 0x0000C000
//   J  03c0006f j +60               -> 0x0000003C  (+60)
//   J  01c0006f j +28               -> 0x0000001C  (+28)
//   -  imm_src = 111 (no usado)     -> 0x00000000
// ============================================================================
module tb_imm_gen;

    reg  [31:0] instr;
    reg  [2:0]  imm_src;
    wire [31:0] imm_ext;
    integer     errores = 0;

    imm_gen dut (.instr(instr), .imm_src(imm_src), .imm_ext(imm_ext));

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

    initial begin
        probar(32'hfe010113, 3'b000, 32'hFFFFFFE0, "I addi sp,sp,-32");
        probar(32'h7df78793, 3'b000, 32'h000007DF, "I addi a5,a5,2015");
        probar(32'h00f7f793, 3'b000, 32'h0000000F, "I andi a5,a5,15");
        probar(32'h00179793, 3'b000, 32'h00000001, "I slli a5,a5,1");
        probar(32'hfe842783, 3'b000, 32'hFFFFFFE8, "I lw a5,-24(s0)");
        probar(32'h00008067, 3'b000, 32'h00000000, "I ret");
        probar(32'h00112e23, 3'b001, 32'h0000001C, "S sw ra,28(sp)");
        probar(32'hfef42623, 3'b001, 32'hFFFFFFEC, "S sw a5,-20(s0)");
        probar(32'hfef401a3, 3'b001, 32'hFFFFFFE3, "S sb a5,-29(s0)");
        probar(32'h00079863, 3'b010, 32'h00000010, "B bnez +16");
        probar(32'hfce7d0e3, 3'b010, 32'hFFFFFFC0, "B bge -64");
        probar(32'h0000c7b7, 3'b011, 32'h0000C000, "U lui a5,0xc");
        probar(32'h03c0006f, 3'b100, 32'h0000003C, "J j +60");
        probar(32'h01c0006f, 3'b100, 32'h0000001C, "J j +28");
        probar(32'hfe010113, 3'b111, 32'h00000000, "imm_src no usado");

        if (errores == 0) $display("tb_imm_gen: TODAS LAS PRUEBAS PASARON");
        else              $display("tb_imm_gen: %0d ERRORES", errores);
        $finish;
    end

endmodule
