`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_sumador
//
// Objetivo:
//   Verificar la suma de 32 bits en los casos que usa el procesador: PC + 4 y
//   PC + inmediato (positivo y negativo), incluido el desborde de 32 bits.
//
// Estímulos (en orden), con valores del programa del proyecto:
//   1. a = 0x00000000, b = 4            (PC + 4 desde el inicio)
//   2. a = 0x00000034, b = 4            (PC + 4 a mitad del programa)
//   3. a = 0x00000030, b = 0x0000003C   (j +60:   PC + Imm positivo)
//   4. a = 0x00000074, b = 0xFFFFFFC0   (bge -64: PC + Imm negativo)
//   5. a = 0x00000038, b = 0x00000010   (bnez +16)
//   6. a = 0xFFFFFFFC, b = 4            (desborde: el acarreo se descarta)
//
// Resultados esperados:
//   1. 0x00000004   2. 0x00000038   3. 0x0000006C
//   4. 0x00000034   5. 0x00000048   6. 0x00000000
// ============================================================================
module tb_sumador;

    reg  [31:0] a, b;
    wire [31:0] y;
    integer     errores = 0;

    sumador dut (.a(a), .b(b), .y(y));

    task probar(input [31:0] va, input [31:0] vb, input [31:0] esperado, input [8*40-1:0] caso);
        begin
            a = va; b = vb; #1;
            if (y !== esperado) begin
                $display("ERROR  %0s: %h + %h = %h, esperado %h", caso, a, b, y, esperado);
                errores = errores + 1;
            end else
                $display("OK     %0s: %h + %h = %h", caso, a, b, y);
        end
    endtask

    initial begin
        probar(32'h00000000, 32'd4,         32'h00000004, "1 PC+4 inicio");
        probar(32'h00000034, 32'd4,         32'h00000038, "2 PC+4");
        probar(32'h00000030, 32'h0000003C,  32'h0000006C, "3 PC+Imm positivo (j)");
        probar(32'h00000074, 32'hFFFFFFC0,  32'h00000034, "4 PC+Imm negativo (bge)");
        probar(32'h00000038, 32'h00000010,  32'h00000048, "5 PC+Imm (bnez)");
        probar(32'hFFFFFFFC, 32'd4,         32'h00000000, "6 desborde");

        if (errores == 0) $display("tb_sumador: TODAS LAS PRUEBAS PASARON");
        else              $display("tb_sumador: %0d ERRORES", errores);
        $finish;
    end

endmodule
