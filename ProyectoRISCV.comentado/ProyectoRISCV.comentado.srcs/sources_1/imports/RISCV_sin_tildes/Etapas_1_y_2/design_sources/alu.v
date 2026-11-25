`timescale 1ns / 1ps
// ============================================================================
// Modulo:   alu
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Unidad aritmetico-logica de 32 bits. Hace la operacion que indica
// alu_control y entrega dos banderas a la unidad de control (zero y lt).
//   - Suma:  addi y el calculo de direcciones rs1 + imm de lw, sw, sb y jalr.
//   - Resta: compara rs1 con rs2 en bne y bge.
//   - AND:   andi.
//   - SLL:   slli.
// ============================================================================
module alu (
    input  wire [31:0] a,                   // primer operando (registro A = rs1)
    input  wire [31:0] b,                   // segundo operando (mux ALUSrc)
    input  wire [2:0]  alu_control,         // operacion a realizar (ALUControl)
    output reg  [31:0] result,              // resultado (va al registro ALUOut)
    output wire        zero,                // bandera de cero (la usa bne)
    output wire        lt                   // bandera menor que, con signo (bge)
);

    // Operacion segun alu_control (bloque combinacional)
    always @(*) begin
        case (alu_control)
            3'b000:  result = a + b;          // suma
            3'b001:  result = a - b;          // resta
            3'b010:  result = a & b;          // AND
            3'b011:  result = a << b[4:0];    // SLL (5 bits: maximo 31)
            default: result = 32'b0;          // codigos reservados (100 a 111)
        endcase
    end

    // Banderas hacia la unidad de control
    // zero = 1 si el resultado es 0 (en la resta: rs1 y rs2 son iguales)
    assign zero = (result == 32'b0);
    // lt = 1 si a < b con signo, independiente de alu_control. Sin $signed,
    // un negativo como -1 (0xFFFFFFFF) se veria como el mas grande y bge fallaria
    assign lt   = ($signed(a) < $signed(b));

endmodule
