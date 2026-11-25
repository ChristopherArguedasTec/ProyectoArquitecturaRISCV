`timescale 1ns / 1ps
// ============================================================================
// Modulo:   imm_gen  (EXT / unidad de signo)
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Extrae el inmediato de la instruccion segun su formato y lo extiende con
// signo a 32 bits. Cada formato guarda el inmediato en bits distintos (en S,
// B y J viene "desordenado" para que rs1, rs2 y rd esten siempre en la misma
// posicion); este modulo lo reordena para que el resto del procesador reciba
// siempre un numero de 32 bits.
// ============================================================================
module imm_gen (
    input  wire [31:0] instr,               // instruccion completa (salida del IR)
    input  wire [2:0]  imm_src,             // formato del inmediato (ImmSrc)
    output reg  [31:0] imm_ext              // inmediato de 32 bits
);

    // Armado del inmediato segun el formato. instr[31] siempre es el bit de
    // signo, por eso se copia en los bits altos ({n{instr[31]}}).
    // Un formato no usado (default) da 0.
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
