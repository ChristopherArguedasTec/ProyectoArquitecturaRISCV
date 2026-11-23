`timescale 1ns / 1ps
// ============================================================================
// Modulo:  reg_noen
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Funcionalidad:
//   Registro de WIDTH bits sin habilitacion: captura d en cada flanco de
//   subida del reloj. Con reset (sincrono, activo en alto) vuelve a 0.
//
// Entradas:
//   clk   - reloj
//   reset - reset sincrono, activo en alto (deja formas de onda limpias)
//   d     - dato (A: rd1, B: rd2, ALUOut: alu_result, MDR: mem_rdata)
// Salidas:
//   q     - dato del ciclo anterior (A: a, B: b, ALUOut: alu_out, MDR: mdr)
//
// Por que existe:
//   Separa las etapas del multiciclo: guarda el resultado de un ciclo para
//   usarlo en el siguiente (operandos leidos en Decode, resultado de la ALU
//   en Execute, dato leido en Memory). No necesita enable porque durante una
//   instruccion sus entradas no cambian: A y B porque el IR y el banco de
//   registros se mantienen; ALUOut porque las senales de control de la ALU
//   dependen solo de la instruccion; y MDR porque la direccion de memoria
//   (ALUOut) tampoco cambia. Asi vuelven a capturar siempre el mismo valor.
//   Instancias: u_a, u_b, u_aluout y u_mdr (WIDTH = 32).
// ============================================================================
module reg_noen #(
    parameter WIDTH = 32
)(
    input  wire             clk,
    input  wire             reset,
    input  wire [WIDTH-1:0] d,
    output reg  [WIDTH-1:0] q
);

    always @(posedge clk) begin
        if (reset)
            q <= {WIDTH{1'b0}};
        else
            q <= d;
    end

endmodule
