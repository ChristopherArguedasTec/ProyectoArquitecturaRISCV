`timescale 1ns / 1ps
// ============================================================================
// Módulo:  sumador
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Funcionalidad:
//   Suma combinacional de dos operandos de 32 bits. El acarreo de salida se
//   descarta (las direcciones dan la vuelta en 32 bits).
//
// Entradas:
//   a - primer operando
//   b - segundo operando
// Salidas:
//   y - a + b
//
// Por qué existe:
//   Calcula las dos posibles direcciones siguientes del PC sin ocupar la ALU:
//     u_add_pc4:   y = pc + 4      (instrucción siguiente y dirección de
//                                   retorno de jal/jalr)
//     u_add_pcimm: y = pc + imm_ext (destino de jal y de bne/bge)
// ============================================================================
module sumador (
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire [31:0] y
);

    assign y = a + b;

endmodule
