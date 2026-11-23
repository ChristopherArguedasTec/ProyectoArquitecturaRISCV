`timescale 1ns / 1ps
// ============================================================================
// Modulo:  alu
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Funcionalidad:
//   Unidad aritmetico-logica de 32 bits. Segun alu_control realiza:
//     000  suma            a + b
//     001  resta           a - b
//     010  AND bit a bit   a & b
//     011  desplazamiento  a << b[4:0]   (SLL)
//     100-111 reservados   resultado 0
//   Ademas entrega dos banderas hacia la unidad de control:
//     zero = 1 si el resultado es 0
//     lt   = 1 si a < b comparando con signo (independiente de alu_control)
//
// Entradas:
//   a           - primer operando (salida del registro A = rs1)
//   b           - segundo operando (salida del mux ALUSrc: B = rs2 o imm_ext)
//   alu_control - operacion a realizar (ALUControl)
// Salidas:
//   result      - resultado (va al registro ALUOut)
//   zero        - bandera de cero (la usa bne)
//   lt          - bandera "menor que" con signo (la usa bge)
//
// Por que existe:
//   - Suma:  addi y el calculo de direcciones rs1 + imm de lw, sw, sb y jalr.
//   - Resta: compara rs1 con rs2 en bne y bge (zero = 1 si son iguales).
//   - AND:   andi.
//   - SLL:   slli. Solo se usan los 5 bits bajos de b porque un registro de
//            32 bits no se desplaza mas de 31 posiciones.
//   lt se calcula con $signed: sin eso, un numero negativo como -1
//   (0xFFFFFFFF) se veria como el mas grande y bge fallaria.
// ============================================================================
module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  alu_control,
    output reg  [31:0] result,
    output wire        zero,
    output wire        lt
);

    always @(*) begin
        case (alu_control)
            3'b000:  result = a + b;          // suma
            3'b001:  result = a - b;          // resta
            3'b010:  result = a & b;          // AND
            3'b011:  result = a << b[4:0];    // SLL
            default: result = 32'b0;          // codigos reservados
        endcase
    end

    assign zero = (result == 32'b0);
    assign lt   = ($signed(a) < $signed(b));

endmodule
