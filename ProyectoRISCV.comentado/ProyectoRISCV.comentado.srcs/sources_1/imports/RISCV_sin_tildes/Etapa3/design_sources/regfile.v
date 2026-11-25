`timescale 1ns / 1ps
// ============================================================================
// Modulo:   regfile  (REG FILE)
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Banco de 32 registros de 32 bits (x0 a x31) con dos puertos de lectura
// combinacional y uno de escritura sincrona. Necesita dos lecturas porque
// sw/sb y bne/bge usan rs1 y rs2 a la vez, y una escritura para el rd de
// addi, andi, slli, lw, lui, jal y jalr.
// Con sp = 0 al reset, addi sp,sp,-32 deja sp = 0xFFFFFFE0; la memoria de
// datos usa los bits bajos de la direccion, asi que el programa funciona sin
// inicializar sp.
// ============================================================================
module regfile (
    input  wire        clk,                 // reloj
    input  wire        reset,               // pone todos los registros en 0
    input  wire        we,                  // habilitacion de escritura (RegWrite)
    input  wire [4:0]  ra1,                 // registro de lectura 1 = ir[19:15] (rs1)
    input  wire [4:0]  ra2,                 // registro de lectura 2 = ir[24:20] (rs2)
    input  wire [4:0]  wa,                  // registro de escritura = ir[11:7]  (rd)
    input  wire [31:0] wd,                  // dato a escribir (result)
    output wire [31:0] rd1,                 // valor de rs1 (va al registro A)
    output wire [31:0] rd2                  // valor de rs2 (va al registro B)
);

    reg [31:0] regs [0:31];                 // los 32 registros de 32 bits
    integer i;                              // contador del for del reset

    // Escritura sincrona
    always @(posedge clk) begin
        if (reset) begin                    // reset: los 32 registros en 0
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'b0;
        end else if (we && (wa != 5'd0)) begin
            regs[wa] <= wd;                 // las escrituras a x0 se ignoran
        end
    end

    // Lectura combinacional; x0 siempre vale 0
    assign rd1 = (ra1 == 5'd0) ? 32'b0 : regs[ra1];
    assign rd2 = (ra2 == 5'd0) ? 32'b0 : regs[ra2];

endmodule
