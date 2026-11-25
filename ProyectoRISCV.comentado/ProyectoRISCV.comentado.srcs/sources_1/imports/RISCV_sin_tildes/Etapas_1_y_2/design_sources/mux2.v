`timescale 1ns / 1ps
// ============================================================================
// Modulo:   mux2
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Multiplexor de 2 entradas de WIDTH bits. Elige el segundo operando de la
// ALU: las tipo I y S (addi, andi, slli, lw, sw, sb, jalr) operan con el
// inmediato (ALUSrc = 1); los branches (bne, bge) comparan dos registros
// (ALUSrc = 0).
// Instancia: u_mux_alusrc.
// ============================================================================
module mux2 #(
    parameter WIDTH = 32                    // ancho del dato en bits
)(
    input  wire             sel,            // seleccion (ALUSrc)
    input  wire [WIDTH-1:0] d0,             // entrada 0: b (registro B = rs2)
    input  wire [WIDTH-1:0] d1,             // entrada 1: imm_ext (inmediato extendido)
    output wire [WIDTH-1:0] y               // alu_b: segundo operando de la ALU
);

    // sel = 0 -> d0, sel = 1 -> d1
    assign y = sel ? d1 : d0;

endmodule
