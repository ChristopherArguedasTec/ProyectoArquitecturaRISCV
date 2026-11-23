`timescale 1ns / 1ps
// ============================================================================
// Modulo:  regfile  (REG FILE)
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Funcionalidad:
//   Banco de 32 registros de 32 bits (x0 a x31) con dos puertos de lectura
//   combinacional y uno de escritura sincrona.
//   - Lectura: rd1 = regs[ra1] y rd2 = regs[ra2] de inmediato. x0 siempre se
//     lee como 0.
//   - Escritura: en el flanco de subida, si we = 1 y wa != 0, regs[wa] <= wd.
//     Las escrituras a x0 se ignoran.
//   - Reset (sincrono, activo en alto): pone los 32 registros en 0.
//
// Entradas:
//   clk   - reloj
//   reset - pone todos los registros en 0
//   we    - habilitacion de escritura (RegWrite)
//   ra1   - direccion de lectura 1 = ir[19:15] (rs1)
//   ra2   - direccion de lectura 2 = ir[24:20] (rs2)
//   wa    - direccion de escritura = ir[11:7]  (rd)
//   wd    - dato a escribir = result (salida del mux de resultado)
// Salidas:
//   rd1   - valor de rs1 (va al registro A)
//   rd2   - valor de rs2 (va al registro B)
//
// Por que existe:
//   Guarda los operandos y resultados de todas las instrucciones. Necesita
//   dos lecturas porque sw/sb y bne/bge usan rs1 y rs2 a la vez, y una
//   escritura para el rd de addi, andi, slli, lw, lui, jal y jalr.
//   Con sp = 0 al reset, addi sp,sp,-32 deja sp = 0xFFFFFFE0; la memoria de
//   datos usa los bits bajos de la direccion, asi que el programa funciona
//   sin inicializar sp.
// ============================================================================
module regfile (
    input  wire        clk,
    input  wire        reset,
    input  wire        we,
    input  wire [4:0]  ra1,
    input  wire [4:0]  ra2,
    input  wire [4:0]  wa,
    input  wire [31:0] wd,
    output wire [31:0] rd1,
    output wire [31:0] rd2
);

    reg [31:0] regs [0:31];
    integer i;

    // Escritura sincrona
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'b0;
        end else if (we && (wa != 5'd0)) begin
            regs[wa] <= wd;
        end
    end

    // Lectura combinacional; x0 siempre vale 0
    assign rd1 = (ra1 == 5'd0) ? 32'b0 : regs[ra1];
    assign rd2 = (ra2 == 5'd0) ? 32'b0 : regs[ra2];

endmodule
