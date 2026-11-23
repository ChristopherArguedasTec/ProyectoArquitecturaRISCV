`timescale 1ns / 1ps
// ============================================================================
// Modulo:  mux4
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Funcionalidad:
//   Multiplexor de 4 entradas de WIDTH bits.
//   sel = 00 -> d0, 01 -> d1, 10 -> d2, 11 -> d3.
//
// Entradas:
//   sel - seleccion de 2 bits (ResultSrc)
//   d0  - alu_out  (addi, andi, slli)
//   d1  - mdr      (lw)
//   d2  - pc_plus4 (jal, jalr: direccion de retorno)
//   d3  - imm_ext  (lui)
// Salidas:
//   y   - result (dato que se escribe en rd del banco de registros)
//
// Por que existe:
//   Cada tipo de instruccion escribe en rd un dato que viene de un lugar
//   distinto; este mux elige cual segun ResultSrc.
//   Instancia: u_mux_result.
// ============================================================================
module mux4 #(
    parameter WIDTH = 32
)(
    input  wire [1:0]       sel,
    input  wire [WIDTH-1:0] d0,
    input  wire [WIDTH-1:0] d1,
    input  wire [WIDTH-1:0] d2,
    input  wire [WIDTH-1:0] d3,
    output reg  [WIDTH-1:0] y
);

    always @(*) begin
        case (sel)
            2'b00:   y = d0;
            2'b01:   y = d1;
            2'b10:   y = d2;
            2'b11:   y = d3;
            default: y = d0;   // solo para simulacion: si sel vale x/z sale d0
        endcase
    end

endmodule
