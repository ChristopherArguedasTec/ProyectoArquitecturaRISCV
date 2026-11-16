`timescale 1ns / 1ps
// ============================================================================
// Módulo:  data_mem  (DATA MEM)
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Funcionalidad:
//   Memoria de DEPTH palabras de 32 bits con lectura combinacional y
//   escritura síncrona de una palabra completa o de un solo byte.
//   - Índice de palabra: addr[AW+1:2]. Byte dentro de la palabra: addr[1:0].
//     Como solo se usan los bits bajos, la dirección 0xFFFFFFE8 (pila con
//     sp = 0 al inicio) cae en la palabra 0xFE8 de una memoria de 1024
//     palabras.
//   - Lectura: rdata = palabra completa en addr (lw).
//   - Escritura en el flanco de subida si we = 1:
//       store_byte = 0 (sw): se escribe la palabra completa.
//       store_byte = 1 (sb): se escribe solo el byte addr[1:0] con
//                            wdata[7:0]; los otros tres bytes no cambian
//                            (little-endian: el byte 0 son los bits 7:0).
//   - Se inicializa en 0 para que el dump sea predecible.
//
// Parámetros:
//   DEPTH      - número de palabras (1024 = 4 KB)
// Entradas:
//   clk        - reloj
//   we         - habilitación de escritura (MemWrite)
//   store_byte - 1 = escribir un byte (sb), 0 = escribir palabra (sw)
//   addr       - dirección en bytes (alu_out)
//   wdata      - dato a escribir (valor de rs2, salida del registro B)
// Salidas:
//   rdata      - palabra leída (va al registro MDR)
//
// Por qué existe:
//   Guarda las variables del programa, que viven en la pila: lw lee, sw
//   escribe palabras (i, b, r, ra, s0) y sb escribe un solo byte (char a).
//   Es la memoria a la que se le hace el dump al final de la simulación,
//   desde el testbench por jerarquía (por ejemplo dut.u_dmem.mem).
// ============================================================================
module data_mem #(
    parameter DEPTH = 1024
)(
    input  wire        clk,
    input  wire        we,
    input  wire        store_byte,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output wire [31:0] rdata
);

    localparam AW = $clog2(DEPTH);   // bits de índice (10 para 1024 palabras)

    reg [31:0] mem [0:DEPTH-1];
    wire [AW-1:0] idx = addr[AW+1:2];
    integer i;

    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'b0;
    end

    // Escritura síncrona
    always @(posedge clk) begin
        if (we) begin
            if (store_byte)
                mem[idx][8*addr[1:0] +: 8] <= wdata[7:0];   // sb
            else
                mem[idx] <= wdata;                          // sw
        end
    end

    // Lectura combinacional
    assign rdata = mem[idx];

endmodule
