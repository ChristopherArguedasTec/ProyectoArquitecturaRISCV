`timescale 1ns / 1ps
// ============================================================================
// Módulo:  mux2
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Funcionalidad:
//   Multiplexor de 2 entradas de WIDTH bits. sel = 0 -> d0, sel = 1 -> d1.
//
// Entradas:
//   sel - selección (ALUSrc)
//   d0  - entrada 0 (b: valor de rs2 guardado en el registro B)
//   d1  - entrada 1 (imm_ext: inmediato extendido)
// Salidas:
//   y   - entrada seleccionada (alu_b: segundo operando de la ALU)
//
// Por qué existe:
//   Elige el segundo operando de la ALU. Las tipo I y S (addi, andi, slli,
//   lw, sw, sb, jalr) operan con el inmediato (ALUSrc = 1); los branches
//   (bne, bge) comparan dos registros (ALUSrc = 0).
//   Instancia: u_mux_alusrc.
// ============================================================================
module mux2 #(
    parameter WIDTH = 32
)(
    input  wire             sel,
    input  wire [WIDTH-1:0] d0,
    input  wire [WIDTH-1:0] d1,
    output wire [WIDTH-1:0] y
);

    assign y = sel ? d1 : d0;

endmodule
