`timescale 1ns / 1ps
// ============================================================================
// Modulo:   mux3
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Multiplexor de 3 entradas de WIDTH bits. Decide la proxima direccion del
// PC segun la instruccion: seguir en orden, saltar con PC + inmediato (jal,
// bne/bge tomados) o saltar a rs1 + imm (jalr).
// Instancia: u_mux_pc.
// ============================================================================
module mux3 #(
    parameter WIDTH = 32                    // ancho del dato en bits
)(
    input  wire [1:0]       sel,            // seleccion de 2 bits (PCSrc)
    input  wire [WIDTH-1:0] d0,             // pc_plus4: siguiente instruccion
    input  wire [WIDTH-1:0] d1,             // pc_imm: destino de jal y branches
    input  wire [WIDTH-1:0] d2,             // {alu_out[31:1], 1'b0}: destino de jalr
    output reg  [WIDTH-1:0] y               // pc_next (entra al registro PC)
);

    // Bloque combinacional: se recalcula cada vez que cambia una entrada
    always @(*) begin
        case (sel)
            2'b00:   y = d0;                // PC + 4
            2'b01:   y = d1;                // PC + Imm
            2'b10:   y = d2;                // destino de jalr
            default: y = d0;   // 11 no se usa; sale d0 para no dejar un valor indefinido
        endcase
    end

endmodule
