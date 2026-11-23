`timescale 1ns / 1ps
// ============================================================================
// Modulo:  instr_mem  (PRG MEM)
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Funcionalidad:
//   Memoria de solo lectura de DEPTH palabras de 32 bits. Entrega de forma
//   combinacional la instruccion guardada en la direccion addr.
//   - Indice de palabra: addr[AW+1:2] (las instrucciones estan alineadas a
//     4 bytes, asi que los 2 bits bajos no se usan).
//   - Al iniciar la simulacion se llena con ceros y luego se carga el
//     programa con $readmemh desde FILE (una palabra hexadecimal por linea;
//     la primera linea es la instruccion de la direccion 0).
//   - Lo que queda despues del programa vale 0x00000000, un opcode no
//     soportado que lleva a la unidad de control al estado HALT. Con este
//     programa nunca se llega ahi: el ret de main salta a la direccion 0
//     (ra = 0 desde el reset).
//
// Parametros:
//   DEPTH - numero de palabras (256 = 1 KB)
//   FILE  - nombre del archivo hexadecimal con el programa
// Entradas:
//   addr  - direccion en bytes (viene del PC)
// Salidas:
//   data  - instruccion de 32 bits (va a la entrada d del IR)
//
// Por que existe:
//   Guarda el programa compilado (las 36 instrucciones de main). Segun el
//   enunciado, es el unico elemento que se cambia durante la evaluacion:
//   basta con reemplazar el archivo FILE.
// ============================================================================
module instr_mem #(
    parameter DEPTH = 256,
    parameter FILE  = "programa.hex"
)(
    input  wire [31:0] addr,
    output wire [31:0] data
);

    localparam AW = $clog2(DEPTH);   // bits de indice (8 para 256 palabras)

    reg [31:0] mem [0:DEPTH-1];
    integer i;

    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'b0;
        $readmemh(FILE, mem);
    end

    assign data = mem[addr[AW+1:2]];

endmodule
