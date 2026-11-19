`timescale 1ns / 1ps
// ============================================================================
// Módulo:  instr_mem  (PRG MEM)
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Funcionalidad:
//   Memoria de solo lectura de DEPTH palabras de 32 bits. Entrega de forma
//   combinacional la instrucción guardada en la dirección addr.
//   - Índice de palabra: addr[AW+1:2] (las instrucciones están alineadas a
//     4 bytes, así que los 2 bits bajos no se usan).
//   - Al iniciar la simulación se llena con ceros y luego se carga el
//     programa con $readmemh desde FILE (una palabra hexadecimal por línea;
//     la primera línea es la instrucción de la dirección 0).
//   - Lo que queda después del programa vale 0x00000000, un opcode no
//     soportado que lleva a la unidad de control al estado HALT.
//
// Parámetros:
//   DEPTH - número de palabras (256 = 1 KB)
//   FILE  - nombre del archivo hexadecimal con el programa
// Entradas:
//   addr  - dirección en bytes (viene del PC)
// Salidas:
//   data  - instrucción de 32 bits (va a la entrada d del IR)
//
// Por qué existe:
//   Guarda el programa compilado (las 36 instrucciones de main). Según el
//   enunciado, es el único elemento que se cambia durante la evaluación:
//   basta con reemplazar el archivo FILE.
// ============================================================================
module instr_mem #(
    parameter DEPTH = 256,
    parameter FILE  = "programa.hex"
)(
    input  wire [31:0] addr,
    output wire [31:0] data
);

    localparam AW = $clog2(DEPTH);   // bits de índice (8 para 256 palabras)

    reg [31:0] mem [0:DEPTH-1];
    integer i;

    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'b0;
        $readmemh(FILE, mem);
    end

    assign data = mem[addr[AW+1:2]];

endmodule
