`timescale 1ns / 1ps
// ============================================================================
// Modulo:   reg_noen
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Registro de WIDTH bits sin habilitacion: captura d en cada flanco de
// subida. Separa las etapas del multiciclo: guarda el resultado de un ciclo
// para usarlo en el siguiente (operandos leidos en Decode, resultado de la
// ALU en Execute, dato leido en Memory).
// No necesita enable porque durante una instruccion sus entradas no cambian:
// A y B porque el IR y el banco de registros se mantienen; ALUOut porque las
// senales de control de la ALU dependen solo de la instruccion; y MDR porque
// la direccion de memoria (ALUOut) tampoco cambia. Asi vuelven a capturar
// siempre el mismo valor.
// Instancias: u_a, u_b, u_aluout y u_mdr (WIDTH = 32).
// ============================================================================
module reg_noen #(
    parameter WIDTH = 32                    // ancho del dato en bits
)(
    input  wire             clk,            // reloj
    input  wire             reset,          // reset sincrono, activo en alto
    input  wire [WIDTH-1:0] d,              // rd1, rd2, alu_result o mem_rdata
    output reg  [WIDTH-1:0] q               // a, b, alu_out o mdr (ciclo anterior)
);

    // En cada flanco de subida: reset a 0 o captura de d (sin enable)
    always @(posedge clk) begin
        if (reset)
            q <= {WIDTH{1'b0}};             // reset: el registro vuelve a 0
        else
            q <= d;                         // captura d en todos los flancos
    end

endmodule
