`timescale 1ns / 1ps
// ============================================================================
// Modulo:   data_mem  (DATA MEM)
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Memoria de DEPTH palabras de 32 bits con lectura combinacional y escritura
// sincrona de una palabra completa o de un solo byte. Guarda las variables
// del programa, que viven en la pila: lw lee, sw escribe palabras (i, b, r,
// ra, s0) y sb escribe un solo byte (char a). Es la memoria a la que se le
// hace el dump al final de la simulacion, desde el testbench por jerarquia
// (por ejemplo dut.u_dmem.mem).
// ============================================================================
module data_mem #(
    parameter DEPTH = 1024                  // numero de palabras (1024 = 4 KB)
)(
    input  wire        clk,                 // reloj
    input  wire        we,                  // habilitacion de escritura (MemWrite)
    input  wire        store_byte,          // 1 = byte (sb), 0 = palabra (sw)
    input  wire [31:0] addr,                // direccion en bytes (alu_out)
    input  wire [31:0] wdata,               // dato a escribir (registro B = rs2)
    output wire [31:0] rdata                // palabra leida (va al registro MDR)
);

    localparam AW = $clog2(DEPTH);   // bits de indice (10 para 1024 palabras)

    reg [31:0] mem [0:DEPTH-1];             // DEPTH palabras de 32 bits
    // Indice de palabra: addr[AW+1:2]; el byte dentro de la palabra es
    // addr[1:0]. Como solo se usan los bits bajos, la direccion 0xFFFFFFE8
    // (pila con sp = 0 al inicio) cae en la palabra 0xFE8 de la memoria
    wire [AW-1:0] idx = addr[AW+1:2];
    integer i;

    // Se inicializa en 0 para que el dump sea predecible
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'b0;
    end

    // Escritura sincrona (flanco de subida, solo si we = 1)
    always @(posedge clk) begin
        if (we) begin
            // sb: solo el byte addr[1:0] con wdata[7:0]; los otros tres bytes
            // no cambian (little-endian: el byte 0 son los bits 7:0)
            if (store_byte)
                mem[idx][8*addr[1:0] +: 8] <= wdata[7:0];   // sb
            else
                mem[idx] <= wdata;                          // sw
        end
    end

    // Lectura combinacional de la palabra completa (lw)
    assign rdata = mem[idx];

endmodule
