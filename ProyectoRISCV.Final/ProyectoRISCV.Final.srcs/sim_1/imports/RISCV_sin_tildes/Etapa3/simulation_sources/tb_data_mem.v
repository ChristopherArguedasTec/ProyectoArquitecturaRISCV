`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_data_mem
//
// Objetivo:
//   Verificar la memoria de datos: escritura de palabra (sw), escritura de un
//   solo byte en los cuatro desplazamientos (sb), lectura (lw), que con
//   we = 0 no se escribe, que solo se usan los bits bajos de la direccion, y
//   generar el dump de memoria a un archivo.
//
// Estimulos (en orden), con direcciones y valores del programa:
//   1. Leer 0xFE8 sin haber escrito.
//   2. sw: addr 0xFFFFFFE8 (i en la pila), wdata 0x00000002.
//      Leer con addr 0xFFFFFFE8 y con addr 0x00000FE8.
//   3. sw: addr 0xFFFFFFE4 (r), wdata 0x0000C7DF.
//   4. sb: addr 0xFFFFFFE3 (char a), wdata 0x12345663 ('c' en el byte bajo).
//      Luego sb en la misma direccion con 0x62 ('b').
//   5. sw: addr 0x100, wdata 0xAABBCCDD; luego sb 0x11 en 0x100, 0x22 en
//      0x101, 0x33 en 0x102 y 0x44 en 0x103, leyendo despues de cada uno.
//   6. we = 0 con addr 0xFE8 y wdata 0xFFFFFFFF.
//   7. Dump de toda la memoria a dump_data_mem.txt con el formato
//      "0x<direccion> 0x<valor>", una palabra por linea.
//
// Resultados esperados:
//   1. 0x00000000 (la memoria inicia en 0).
//   2. 0x00000002 en ambas lecturas (0xFFFFFFE8 y 0xFE8 son la misma palabra).
//   3. mem[0xFE4] = 0x0000C7DF.
//   4. mem[0xFE0] = 0x63000000 y luego 0x62000000 (byte 3 de la palabra).
//   5. 0xAABBCC11, 0xAABB2211, 0xAA332211, 0x44332211.
//   6. mem[0xFE8] sigue en 0x00000002.
//   7. El archivo tiene 1024 lineas; las de 0xFE0, 0xFE4 y 0xFE8 coinciden
//      con la tabla 7.2 del documento (0x62000000, 0x0000C7DF, 0x00000002).
// ============================================================================
module tb_data_mem;

    reg         clk = 0, we = 0, store_byte = 0;
    reg  [31:0] addr = 0, wdata = 0;
    wire [31:0] rdata;
    integer     errores = 0, f, k;

    data_mem #(.DEPTH(1024)) dut (.clk(clk), .we(we), .store_byte(store_byte),
                                  .addr(addr), .wdata(wdata), .rdata(rdata));

    always #5 clk = ~clk;

    task revisar(input [31:0] esperado, input [8*40-1:0] caso);
        begin
            if (rdata !== esperado) begin
                $display("ERROR  %0s: mem[%h] = %h, esperado %h", caso, addr, rdata, esperado);
                errores = errores + 1;
            end else
                $display("OK     %0s: mem[%h] = %h", caso, addr, rdata);
        end
    endtask

    // Escribe en el siguiente flanco de subida (estimulos en flanco de bajada)
    task escribir(input [31:0] a, input [31:0] d, input es_byte);
        begin
            @(negedge clk); we = 1; store_byte = es_byte; addr = a; wdata = d;
            @(negedge clk); we = 0; store_byte = 0;
        end
    endtask

    task leer(input [31:0] a);
        begin addr = a; #1; end
    endtask

    initial begin
        // 1. memoria inicia en 0
        leer(32'h00000FE8);                 revisar(32'h0, "1 inicia en 0");

        // 2. sw y truncado de direccion
        escribir(32'hFFFFFFE8, 32'h00000002, 0);
        leer(32'hFFFFFFE8);                 revisar(32'h00000002, "2 sw i (0xFFFFFFE8)");
        leer(32'h00000FE8);                 revisar(32'h00000002, "2 misma palabra (0xFE8)");

        // 3. sw de r
        escribir(32'hFFFFFFE4, 32'h0000C7DF, 0);
        leer(32'hFFFFFFE4);                 revisar(32'h0000C7DF, "3 sw r");

        // 4. sb del char a: solo cambia el byte 3 de la palabra 0xFE0
        escribir(32'hFFFFFFE3, 32'h12345663, 1);
        leer(32'hFFFFFFE0);                 revisar(32'h63000000, "4 sb 'c' en byte 3");
        escribir(32'hFFFFFFE3, 32'h00000062, 1);
        leer(32'hFFFFFFE0);                 revisar(32'h62000000, "4 sb 'b' en byte 3");

        // 5. sb en los cuatro desplazamientos
        escribir(32'h00000100, 32'hAABBCCDD, 0);
        escribir(32'h00000100, 32'h00000011, 1);
        leer(32'h00000100);                 revisar(32'hAABBCC11, "5 sb offset 0");
        escribir(32'h00000101, 32'h00000022, 1);
        leer(32'h00000100);                 revisar(32'hAABB2211, "5 sb offset 1");
        escribir(32'h00000102, 32'h00000033, 1);
        leer(32'h00000100);                 revisar(32'hAA332211, "5 sb offset 2");
        escribir(32'h00000103, 32'h00000044, 1);
        leer(32'h00000100);                 revisar(32'h44332211, "5 sb offset 3");

        // 6. we = 0 no escribe
        @(negedge clk); we = 0; addr = 32'h00000FE8; wdata = 32'hFFFFFFFF;
        @(negedge clk);
        leer(32'h00000FE8);                 revisar(32'h00000002, "6 we=0 no escribe");

        // 7. dump de la memoria
        f = $fopen("dump_data_mem.txt", "w");
        for (k = 0; k < 1024; k = k + 1)
            $fdisplay(f, "0x%0h 0x%08h", k * 4, dut.mem[k]);
        $fclose(f);
        $display("Dump escrito en dump_data_mem.txt (1024 palabras)");

        if (errores == 0) $display("tb_data_mem: TODAS LAS PRUEBAS PASARON");
        else              $display("tb_data_mem: %0d ERRORES", errores);
        $finish;
    end

endmodule
