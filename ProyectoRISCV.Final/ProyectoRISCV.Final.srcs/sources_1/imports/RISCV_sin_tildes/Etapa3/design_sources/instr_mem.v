`timescale 1ns / 1ps
// ============================================================================
// Modulo:   instr_mem  (PRG MEM)
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Memoria de solo lectura con el programa compilado (las 36 instrucciones de
// main). Entrega de forma combinacional la instruccion de la direccion addr.
// Segun el enunciado, es el unico elemento que se cambia durante la
// evaluacion: basta con reemplazar el archivo FILE.
// ============================================================================
module instr_mem #(
    parameter DEPTH = 256,                  // numero de palabras (256 = 1 KB)
    parameter FILE  = "programa.hex"        // archivo hexadecimal con el programa
)(
    input  wire [31:0] addr,                // direccion en bytes (viene del PC)
    output wire [31:0] data                 // instruccion de 32 bits (va al IR)
);

    localparam AW = $clog2(DEPTH);   // bits de indice (8 para 256 palabras)

    reg [31:0] mem [0:DEPTH-1];             // DEPTH palabras de 32 bits
    integer i;

    // Al iniciar la simulacion: primero se llena con ceros y luego se carga
    // el programa (una palabra hexadecimal por linea; la primera linea es la
    // direccion 0). Lo que queda despues del programa vale 0x00000000, un
    // opcode no soportado que lleva a la unidad de control a HALT. Con este
    // programa nunca se llega ahi: el ret de main salta a la direccion 0
    // (ra = 0 desde el reset).
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'b0;
        $readmemh(FILE, mem);
    end

    // Lectura combinacional. Indice de palabra = addr[AW+1:2]: las
    // instrucciones estan alineadas a 4 bytes, los 2 bits bajos no se usan
    assign data = mem[addr[AW+1:2]];

endmodule
