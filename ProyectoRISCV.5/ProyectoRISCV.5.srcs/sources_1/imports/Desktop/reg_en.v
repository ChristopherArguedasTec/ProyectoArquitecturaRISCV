`timescale 1ns / 1ps
// ============================================================================
// Módulo:  reg_en
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Funcionalidad:
//   Registro de WIDTH bits con habilitación (enable). En cada flanco de subida
//   del reloj captura la entrada d solo si en = 1; si en = 0 conserva su valor.
//   Con reset (síncrono, activo en alto) vuelve a 0.
//
// Entradas:
//   clk   - reloj
//   reset - reset síncrono, activo en alto
//   en    - habilitación de escritura (PC: PCWrite, IR: IRWrite)
//   d     - dato a guardar (PC: pc_next, IR: instr)
// Salidas:
//   q     - valor guardado (PC: pc, IR: ir)
//
// Por qué existe:
//   En el diseño multiciclo una instrucción dura varios ciclos. El PC y el IR
//   deben mantener su valor durante toda la instrucción y solo actualizarse en
//   un ciclo específico: el PC en el último estado (PCWrite) y el IR en Fetch
//   (IRWrite). Por eso necesitan enable.
//   Instancias: u_pc y u_ir (WIDTH = 32).
// ============================================================================
module reg_en #(
    parameter WIDTH = 32
)(
    input  wire             clk,
    input  wire             reset,
    input  wire             en,
    input  wire [WIDTH-1:0] d,
    output reg  [WIDTH-1:0] q
);

    always @(posedge clk) begin
        if (reset)
            q <= {WIDTH{1'b0}};
        else if (en)
            q <= d;
        // si en = 0, q conserva su valor
    end

endmodule
