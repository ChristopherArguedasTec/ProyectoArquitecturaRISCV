`timescale 1ns / 1ps
// ============================================================================
// Módulo:  mux3
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Funcionalidad:
//   Multiplexor de 3 entradas de WIDTH bits.
//   sel = 00 -> d0, 01 -> d1, 10 -> d2, 11 (no usado) -> d0 por defecto.
//
// Entradas:
//   sel - selección de 2 bits (PCSrc)
//   d0  - pc_plus4                (siguiente instrucción)
//   d1  - pc_imm                  (destino de jal y branches)
//   d2  - {alu_out[31:1], 1'b0}   (destino de jalr con el bit 0 en cero)
// Salidas:
//   y   - pc_next (entra al registro PC)
//
// Por qué existe:
//   Decide la próxima dirección del PC según la instrucción: seguir en orden,
//   saltar con PC + inmediato (jal, bne/bge tomados) o saltar a rs1 + imm
//   (jalr). El caso 11 devuelve d0 para que nunca quede un valor indefinido.
//   Instancia: u_mux_pc.
// ============================================================================
module mux3 #(
    parameter WIDTH = 32
)(
    input  wire [1:0]       sel,
    input  wire [WIDTH-1:0] d0,
    input  wire [WIDTH-1:0] d1,
    input  wire [WIDTH-1:0] d2,
    output reg  [WIDTH-1:0] y
);

    always @(*) begin
        case (sel)
            2'b00:   y = d0;
            2'b01:   y = d1;
            2'b10:   y = d2;
            default: y = d0;   // 11 no se usa
        endcase
    end

endmodule
