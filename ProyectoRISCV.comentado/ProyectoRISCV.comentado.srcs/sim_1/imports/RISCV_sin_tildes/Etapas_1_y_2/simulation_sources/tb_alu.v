`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_alu
//
// Objetivo:
//   Verificar las cuatro operaciones de la ALU, las banderas zero y lt
//   (incluida la comparacion con signo) y que los codigos reservados dan 0.
//   Los casos salen de instrucciones del programa del proyecto.
// ============================================================================
module tb_alu;

    // ---------------- Senales hacia y desde la ALU ----------------
    reg  [31:0] a, b;                       // operandos (los pone el testbench)
    reg  [2:0]  alu_control;                // operacion
    wire [31:0] result;                     // salidas de la ALU
    wire        zero, lt;
    integer     errores = 0;                // contador de pruebas fallidas

    // ---------------- Modulo bajo prueba ----------------
    alu dut (.a(a), .b(b), .alu_control(alu_control), .result(result), .zero(zero), .lt(lt));

    // ---------------- Tarea de prueba ----------------
    // Pone a, b y la operacion, espera 1 ns (la ALU es combinacional) y compara
    // result, zero y lt con los valores esperados
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

    // ---------------- Estimulos ----------------
    initial begin
        // Suma (000): addi y direcciones
        //   1. addi sp,sp,32 con sp = -32 -> 0, zero = 1
        //   2. addi sp,sp,-32 con sp = 0  -> 0xFFFFFFE0
        //   3. lui + addi                 -> 0xC7DF
        //   4. direccion de lw -24(s0)    -> 0xFFFFFFE8
        //     a             b             op      result        zero  lt
        probar(32'hFFFFFFE0, 32'h00000020, 3'b000, 32'h00000000, 1'b1, 1'b1, " 1 suma addi sp,sp,32");
        probar(32'h00000000, 32'hFFFFFFE0, 3'b000, 32'hFFFFFFE0, 1'b0, 1'b0, " 2 suma addi sp,sp,-32");
        probar(32'h0000C000, 32'h000007DF, 3'b000, 32'h0000C7DF, 1'b0, 1'b0, " 3 suma lui+addi C7DF");
        probar(32'h00000000, 32'hFFFFFFE8, 3'b000, 32'hFFFFFFE8, 1'b0, 1'b0, " 4 suma direccion lw");

        // Resta (001): comparaciones de bne y bge
        //   5 y 6. bne a5,zero con i = 1 (zero = 0) y con i = 0 (zero = 1)
        //   7 y 8. bge a5,a4 con i = 1 (1 >= 1, lt = 0) y con i = 2 (1 < 2, lt = 1)
        probar(32'h00000001, 32'h00000000, 3'b001, 32'h00000001, 1'b0, 1'b0, " 5 resta bne i=1");
        probar(32'h00000000, 32'h00000000, 3'b001, 32'h00000000, 1'b1, 1'b0, " 6 resta bne i=0");
        probar(32'h00000001, 32'h00000001, 3'b001, 32'h00000000, 1'b1, 1'b0, " 7 resta bge 1>=1");
        probar(32'h00000001, 32'h00000002, 3'b001, 32'hFFFFFFFF, 1'b0, 1'b1, " 8 resta bge 1<2");

        // lt con signo: estos dos casos fallarian si lt no usara $signed
        //   9. -1 < 1 (negativo vs positivo)   10. 1 > -1 (positivo vs negativo)
        probar(32'hFFFFFFFF, 32'h00000001, 3'b001, 32'hFFFFFFFE, 1'b0, 1'b1, " 9 lt con signo -1<1");
        probar(32'h00000001, 32'hFFFFFFFF, 3'b001, 32'h00000002, 1'b0, 1'b0, "10 lt con signo 1>-1");

        // AND (010) y SLL (011)
        //   11. b & 0xF con b = 66   12. 33 << 1   13. 1 << 0x21: solo usa b[4:0] = 1
        probar(32'h00000042, 32'h0000000F, 3'b010, 32'h00000002, 1'b0, 1'b0, "11 AND andi");
        probar(32'h00000021, 32'h00000001, 3'b011, 32'h00000042, 1'b0, 1'b0, "12 SLL slli");
        probar(32'h00000001, 32'h00000021, 3'b011, 32'h00000002, 1'b0, 1'b1, "13 SLL usa b[4:0]");

        // Codigo reservado (111): resultado 0
        probar(32'h12345678, 32'h00000001, 3'b111, 32'h00000000, 1'b1, 1'b0, "14 codigo reservado");
        if (errores == 0) $display("tb_alu: TODAS LAS PRUEBAS PASARON");
        else              $display("tb_alu: %0d ERRORES", errores);
        $finish;
    end

endmodule
