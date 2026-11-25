`timescale 1ns / 1ps
// ============================================================================
// Modulo:   sumador
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Suma combinacional de dos operandos de 32 bits. Calcula las dos posibles
// direcciones siguientes del PC sin ocupar la ALU:
//   u_add_pc4:   y = pc + 4       (instruccion siguiente y direccion de
//                                  retorno de jal/jalr)
//   u_add_pcimm: y = pc + imm_ext (destino de jal y de bne/bge)
// ============================================================================
module sumador (
    input  wire [31:0] a,                   // primer operando (pc)
    input  wire [31:0] b,                   // segundo operando (4 o imm_ext)
    output wire [31:0] y                    // resultado a + b
);

    // Suma combinacional; el acarreo de salida se descarta
    // (las direcciones dan la vuelta en 32 bits)
    assign y = a + b;

endmodule
