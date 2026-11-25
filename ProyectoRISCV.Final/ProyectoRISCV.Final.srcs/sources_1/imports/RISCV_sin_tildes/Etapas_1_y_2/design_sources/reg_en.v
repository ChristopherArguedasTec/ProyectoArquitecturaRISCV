`timescale 1ns / 1ps
// ============================================================================
// Modulo:   reg_en
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Registro de WIDTH bits con habilitacion (enable). En el diseno multiciclo
// una instruccion dura varios ciclos; el PC y el IR deben mantener su valor
// durante toda la instruccion y solo actualizarse en un ciclo especifico:
// el PC en el ultimo estado (PCWrite) y el IR en Fetch (IRWrite).
// Instancias: u_pc y u_ir (WIDTH = 32).
// ============================================================================
module reg_en #(
    parameter WIDTH = 32                    // ancho del dato en bits
)(
    input  wire             clk,            // reloj
    input  wire             reset,          // reset sincrono, activo en alto
    input  wire             en,             // habilitacion (PC: PCWrite, IR: IRWrite)
    input  wire [WIDTH-1:0] d,              // dato a guardar (PC: pc_next, IR: instr)
    output reg  [WIDTH-1:0] q               // valor guardado (PC: pc, IR: ir)
);

    // Todo ocurre en el flanco de subida del reloj
    always @(posedge clk) begin
        if (reset)
            q <= {WIDTH{1'b0}};             // reset: el registro vuelve a 0
        else if (en)
            q <= d;                         // en = 1: captura el dato d
        // si en = 0, q conserva su valor
    end

endmodule
