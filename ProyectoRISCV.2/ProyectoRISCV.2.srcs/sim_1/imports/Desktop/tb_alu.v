`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_alu
//
// Objetivo:
//   Verificar las cuatro operaciones de la ALU, las banderas zero y lt
//   (incluida la comparación con signo) y que los códigos reservados dan 0.
//   Los casos salen de instrucciones del programa del proyecto.
//
// Estímulos (a, b, alu_control) y resultados esperados (result, zero, lt):
//    1. suma  0xFFFFFFE0 + 0x20   (addi sp,sp,32 con sp=-32)   -> 0x00000000, zero=1
//    2. suma  0x00000000 + 0xFFFFFFE0 (addi sp,sp,-32)         -> 0xFFFFFFE0
//    3. suma  0x0000C000 + 0x7DF  (lui + addi = 0xC7DF)        -> 0x0000C7DF
//    4. suma  0x00000000 + 0xFFFFFFE8 (dirección de lw -24(s0)) -> 0xFFFFFFE8
//    5. resta 1 - 0               (bne a5,zero con i=1)        -> 1, zero=0
//    6. resta 0 - 0               (bne a5,zero con i=0)        -> 0, zero=1
//    7. resta 1 - 1               (bge a5,a4 con i=1)          -> 0, lt=0
//    8. resta 1 - 2               (bge a5,a4 con i=2)          -> 0xFFFFFFFF, lt=1
//    9. resta -1 - 1              (negativo vs positivo)       -> 0xFFFFFFFE, lt=1
//   10. resta 1 - (-1)            (positivo vs negativo)       -> 2, lt=0
//   11. AND   0x42 & 0xF          (b & 0xF con b=66)           -> 0x00000002
//   12. SLL   33 << 1             (b << 1)                     -> 0x00000042
//   13. SLL   1 << 0x21           (solo usa b[4:0] = 1)        -> 0x00000002
//   14. código 111 reservado                                   -> 0, zero=1
//   Los casos 9 y 10 fallarían si lt no se calculara con signo.
// ============================================================================
module tb_alu;

    reg  [31:0] a, b;
    reg  [2:0]  alu_control;
    wire [31:0] result;
    wire        zero, lt;
    integer     errores = 0;

    alu dut (.a(a), .b(b), .alu_control(alu_control), .result(result), .zero(zero), .lt(lt));

    task probar(input [31:0] va, input [31:0] vb, input [2:0] op,
                input [31:0] e_res, input e_zero, input e_lt, input [8*44-1:0] caso);
        begin
            a = va; b = vb; alu_control = op; #1;
            if (result !== e_res || zero !== e_zero || lt !== e_lt) begin
                $display("ERROR  %0s: result=%h zero=%b lt=%b | esperado %h %b %b",
                         caso, result, zero, lt, e_res, e_zero, e_lt);
                errores = errores + 1;
            end else
                $display("OK     %0s: result=%h zero=%b lt=%b", caso, result, zero, lt);
        end
    endtask

    initial begin
        //     a             b             op      result        zero  lt
        probar(32'hFFFFFFE0, 32'h00000020, 3'b000, 32'h00000000, 1'b1, 1'b1, " 1 suma addi sp,sp,32");
        probar(32'h00000000, 32'hFFFFFFE0, 3'b000, 32'hFFFFFFE0, 1'b0, 1'b0, " 2 suma addi sp,sp,-32");
        probar(32'h0000C000, 32'h000007DF, 3'b000, 32'h0000C7DF, 1'b0, 1'b0, " 3 suma lui+addi C7DF");
        probar(32'h00000000, 32'hFFFFFFE8, 3'b000, 32'hFFFFFFE8, 1'b0, 1'b0, " 4 suma direccion lw");
        probar(32'h00000001, 32'h00000000, 3'b001, 32'h00000001, 1'b0, 1'b0, " 5 resta bne i=1");
        probar(32'h00000000, 32'h00000000, 3'b001, 32'h00000000, 1'b1, 1'b0, " 6 resta bne i=0");
        probar(32'h00000001, 32'h00000001, 3'b001, 32'h00000000, 1'b1, 1'b0, " 7 resta bge 1>=1");
        probar(32'h00000001, 32'h00000002, 3'b001, 32'hFFFFFFFF, 1'b0, 1'b1, " 8 resta bge 1<2");
        probar(32'hFFFFFFFF, 32'h00000001, 3'b001, 32'hFFFFFFFE, 1'b0, 1'b1, " 9 lt con signo -1<1");
        probar(32'h00000001, 32'hFFFFFFFF, 3'b001, 32'h00000002, 1'b0, 1'b0, "10 lt con signo 1>-1");
        probar(32'h00000042, 32'h0000000F, 3'b010, 32'h00000002, 1'b0, 1'b0, "11 AND andi");
        probar(32'h00000021, 32'h00000001, 3'b011, 32'h00000042, 1'b0, 1'b0, "12 SLL slli");
        probar(32'h00000001, 32'h00000021, 3'b011, 32'h00000002, 1'b0, 1'b1, "13 SLL usa b[4:0]");
        probar(32'h12345678, 32'h00000001, 3'b111, 32'h00000000, 1'b1, 1'b0, "14 codigo reservado");

        if (errores == 0) $display("tb_alu: TODAS LAS PRUEBAS PASARON");
        else              $display("tb_alu: %0d ERRORES", errores);
        $finish;
    end

endmodule
