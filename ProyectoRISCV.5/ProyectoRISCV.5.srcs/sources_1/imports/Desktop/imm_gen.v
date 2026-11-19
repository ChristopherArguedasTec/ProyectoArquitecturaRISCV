`timescale 1ns / 1ps
// ============================================================================
// Módulo:  imm_gen  (EXT / unidad de signo)
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Funcionalidad:
//   Extrae el inmediato de la instrucción según su formato y lo extiende con
//   signo a 32 bits (copiando instr[31], que siempre es el bit de signo):
//     imm_src = 000  I: {{20{i[31]}}, i[31:20]}
//     imm_src = 001  S: {{20{i[31]}}, i[31:25], i[11:7]}
//     imm_src = 010  B: {{19{i[31]}}, i[31], i[7], i[30:25], i[11:8], 1'b0}
//     imm_src = 011  U: {i[31:12], 12'b0}
//     imm_src = 100  J: {{11{i[31]}}, i[31], i[19:12], i[20], i[30:21], 1'b0}
//     otros           : 0
//
// Entradas:
//   instr   - instrucción completa (salida del IR)
//   imm_src - formato del inmediato (ImmSrc, depende solo del opcode)
// Salidas:
//   imm_ext - inmediato de 32 bits; va al mux ALUSrc, al sumador PC + Imm y
//             a la entrada 11 del mux de resultado (lui)
//
// Por qué existe:
//   Cada formato guarda el inmediato en bits distintos de la instrucción
//   (en S, B y J viene "desordenado" para que rs1, rs2 y rd estén siempre en
//   la misma posición). Este módulo lo reordena y extiende el signo para que
//   el resto del procesador reciba siempre un número de 32 bits. Ejemplos:
//   el -32 de addi sp,sp,-32, el -29 de sb a5,-29(s0), el -64 de bge y el
//   0xC000 de lui a5,0xc.
// ============================================================================
module imm_gen (
    input  wire [31:0] instr,
    input  wire [2:0]  imm_src,
    output reg  [31:0] imm_ext
);

    always @(*) begin
        case (imm_src)
            3'b000: imm_ext = {{20{instr[31]}}, instr[31:20]};                                // I
            3'b001: imm_ext = {{20{instr[31]}}, instr[31:25], instr[11:7]};                   // S
            3'b010: imm_ext = {{19{instr[31]}}, instr[31], instr[7], instr[30:25],
                               instr[11:8], 1'b0};                                            // B
            3'b011: imm_ext = {instr[31:12], 12'b0};                                          // U
            3'b100: imm_ext = {{11{instr[31]}}, instr[31], instr[19:12], instr[20],
                               instr[30:21], 1'b0};                                           // J
            default: imm_ext = 32'b0;
        endcase
    end

endmodule
