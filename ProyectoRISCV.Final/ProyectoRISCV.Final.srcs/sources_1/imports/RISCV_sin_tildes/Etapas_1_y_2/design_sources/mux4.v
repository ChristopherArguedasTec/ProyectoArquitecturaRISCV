`timescale 1ns / 1ps
// ============================================================================
// Modulo:   mux4
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Multiplexor de 4 entradas de WIDTH bits. Cada tipo de instruccion escribe
// en rd un dato que viene de un lugar distinto; este mux elige cual segun
// ResultSrc.
// Instancia: u_mux_result.
// ============================================================================
module mux4 #(
    parameter WIDTH = 32                    // ancho del dato en bits
)(
    input  wire [1:0]       sel,            // seleccion de 2 bits (ResultSrc)
    input  wire [WIDTH-1:0] d0,             // alu_out  (addi, andi, slli)
    input  wire [WIDTH-1:0] d1,             // mdr      (lw)
    input  wire [WIDTH-1:0] d2,             // pc_plus4 (jal, jalr: retorno)
    input  wire [WIDTH-1:0] d3,             // imm_ext  (lui)
    output reg  [WIDTH-1:0] y               // result: dato que se escribe en rd
);

    // Bloque combinacional: cada valor de sel tiene su entrada
    always @(*) begin
        case (sel)
            2'b00:   y = d0;                // ALUOut
            2'b01:   y = d1;                // MDR
            2'b10:   y = d2;                // PC + 4
            2'b11:   y = d3;                // inmediato
            default: y = d0;   // solo para simulacion: si sel vale x/z sale d0
        endcase
    end

endmodule
