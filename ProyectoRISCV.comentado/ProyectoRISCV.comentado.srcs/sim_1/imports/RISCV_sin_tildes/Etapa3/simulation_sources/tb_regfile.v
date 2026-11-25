`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_regfile
//
// Objetivo:
//   Verificar el banco de registros: reset, escritura sincrona con we, lectura
//   combinacional por los dos puertos, que x0 siempre vale 0 y que la
//   escritura no se ve antes del flanco.
// ============================================================================
module tb_regfile;

    // ---------------- Senales hacia y desde el banco ----------------
    reg         clk = 0, reset = 0, we = 0;
    reg  [4:0]  ra1 = 0, ra2 = 0, wa = 0;   // registros de lectura y escritura
    reg  [31:0] wd = 0;                     // dato a escribir
    wire [31:0] rd1, rd2;                   // datos leidos
    integer     errores = 0;                // contador de pruebas fallidas

    // ---------------- Modulo bajo prueba ----------------
    regfile dut (.clk(clk), .reset(reset), .we(we), .ra1(ra1), .ra2(ra2),
                 .wa(wa), .wd(wd), .rd1(rd1), .rd2(rd2));

    // ---------------- Reloj ----------------
    always #5 clk = ~clk;   // periodo de 10 ns

    // ---------------- Tarea de revision ----------------
    // Recibe el valor a revisar (rd1 o rd2) y lo compara con el esperado
    task revisar(input [31:0] valor, input [31:0] esperado, input [8*44-1:0] caso);
        begin
            if (valor !== esperado) begin
                $display("ERROR  %0s: %h, esperado %h", caso, valor, esperado);
                errores = errores + 1;
            end else
                $display("OK     %0s: %h", caso, valor);
        end
    endtask

    // ---------------- Estimulos ----------------
    // Se cambian en el flanco de bajada; el banco escribe en el de subida
    initial begin
        // 1. reset: x5 y x31 deben valer 0
        @(negedge clk); reset = 1;
        @(negedge clk); reset = 0;
        ra1 = 5'd5; ra2 = 5'd31; #1;
        revisar(rd1, 32'h0, "1 reset x5");
        revisar(rd2, 32'h0, "1 reset x31");

        // 2. escribir x5 = 0x21 (b = 33) y leerlo por los dos puertos
        we = 1; wa = 5'd5; wd = 32'h00000021;
        @(negedge clk); we = 0;
        ra1 = 5'd5; ra2 = 5'd5; #1;
        revisar(rd1, 32'h00000021, "2 x5 por ra1");
        revisar(rd2, 32'h00000021, "2 x5 por ra2");

        // 3. escribir x15 (a5) = 0xC7DF y leer dos registros distintos a la vez
        we = 1; wa = 5'd15; wd = 32'h0000C7DF;
        @(negedge clk); we = 0;
        ra1 = 5'd5; ra2 = 5'd15; #1;
        revisar(rd1, 32'h00000021, "3 x5 por ra1");
        revisar(rd2, 32'h0000C7DF, "3 x15 por ra2");

        // 4. intentar escribir x0: la escritura se ignora y x0 sigue en 0
        we = 1; wa = 5'd0; wd = 32'hFFFFFFFF;
        @(negedge clk); we = 0;
        ra1 = 5'd0; #1;
        revisar(rd1, 32'h0, "4 x0 siempre 0");

        // 5. we = 0 no escribe: x5 sigue en 0x21
        we = 0; wa = 5'd5; wd = 32'hDEADBEEF;
        @(negedge clk);
        ra1 = 5'd5; #1;
        revisar(rd1, 32'h00000021, "5 we=0 no escribe");

        // 6. la escritura solo se ve despues del flanco: x2 (sp) vale 0 antes
        //    y 0xFFFFFFE0 despues
        we = 1; wa = 5'd2; wd = 32'hFFFFFFE0; ra1 = 5'd2; #1;
        revisar(rd1, 32'h0, "6 sp antes del flanco");
        @(negedge clk); we = 0; #1;
        revisar(rd1, 32'hFFFFFFE0, "6 sp despues del flanco");

        // 7. reset borra todo: x15 vuelve a 0
        reset = 1;
        @(negedge clk); reset = 0;
        ra2 = 5'd15; #1;
        revisar(rd2, 32'h0, "7 reset borra x15");

        // ---------------- Resumen ----------------
        if (errores == 0) $display("tb_regfile: TODAS LAS PRUEBAS PASARON");
        else              $display("tb_regfile: %0d ERRORES", errores);
        $finish;
    end

endmodule
