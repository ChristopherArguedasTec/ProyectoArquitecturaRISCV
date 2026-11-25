`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_data_mem
//
// Objetivo:
//   Verificar la memoria de datos: escritura de palabra (sw), escritura de un
//   solo byte en los cuatro desplazamientos (sb), lectura (lw), que con
//   we = 0 no se escribe, que solo se usan los bits bajos de la direccion, y
//   generar el dump de memoria a un archivo. Las direcciones y valores salen
//   del programa del proyecto.
// ============================================================================
module tb_data_mem;

    // ---------------- Senales hacia y desde la memoria ----------------
    reg         clk = 0, we = 0, store_byte = 0;
    reg  [31:0] addr = 0, wdata = 0;
    wire [31:0] rdata;                      // palabra leida
    integer     errores = 0, f, k;          // contador de errores, archivo y indice del dump

    // ---------------- Modulo bajo prueba ----------------
    data_mem #(.DEPTH(1024)) dut (.clk(clk), .we(we), .store_byte(store_byte),
                                  .addr(addr), .wdata(wdata), .rdata(rdata));

    // ---------------- Reloj ----------------
    always #5 clk = ~clk;   // periodo de 10 ns

    // ---------------- Tareas ----------------
    // revisar: compara rdata con el valor esperado e imprime OK o ERROR
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
    // es_byte = 0 hace un sw, es_byte = 1 hace un sb
    task escribir(input [31:0] a, input [31:0] d, input es_byte);
        begin
            @(negedge clk); we = 1; store_byte = es_byte; addr = a; wdata = d;
            @(negedge clk); we = 0; store_byte = 0;
        end
    endtask

    // leer: pone la direccion y espera 1 ns (la lectura es combinacional)
    task leer(input [31:0] a);
        begin addr = a; #1; end
    endtask

    // ---------------- Estimulos ----------------
    initial begin
        // 1. memoria inicia en 0
        leer(32'h00000FE8);                 revisar(32'h0, "1 inicia en 0");

        // 2. sw y truncado de direccion: 0xFFFFFFE8 (i en la pila) y 0xFE8
        //    son la misma palabra, porque solo se usan los bits bajos
        escribir(32'hFFFFFFE8, 32'h00000002, 0);
        leer(32'hFFFFFFE8);                 revisar(32'h00000002, "2 sw i (0xFFFFFFE8)");
        leer(32'h00000FE8);                 revisar(32'h00000002, "2 misma palabra (0xFE8)");

        // 3. sw de r
        escribir(32'hFFFFFFE4, 32'h0000C7DF, 0);
        leer(32'hFFFFFFE4);                 revisar(32'h0000C7DF, "3 sw r");

        // 4. sb del char a: solo cambia el byte 3 de la palabra 0xFE0
        //    ('c' = 0x63 y luego 'b' = 0x62 en el byte bajo de wdata)
        escribir(32'hFFFFFFE3, 32'h12345663, 1);
        leer(32'hFFFFFFE0);                 revisar(32'h63000000, "4 sb 'c' en byte 3");
        escribir(32'hFFFFFFE3, 32'h00000062, 1);
        leer(32'hFFFFFFE0);                 revisar(32'h62000000, "4 sb 'b' en byte 3");

        // 5. sb en los cuatro desplazamientos: primero un sw de 0xAABBCCDD y
        //    luego se reemplaza un byte a la vez; los demas no deben cambiar
        escribir(32'h00000100, 32'hAABBCCDD, 0);
        escribir(32'h00000100, 32'h00000011, 1);
        leer(32'h00000100);                 revisar(32'hAABBCC11, "5 sb offset 0");
        escribir(32'h00000101, 32'h00000022, 1);
        leer(32'h00000100);                 revisar(32'hAABB2211, "5 sb offset 1");
        escribir(32'h00000102, 32'h00000033, 1);
        leer(32'h00000100);                 revisar(32'hAA332211, "5 sb offset 2");
        escribir(32'h00000103, 32'h00000044, 1);
        leer(32'h00000100);                 revisar(32'h44332211, "5 sb offset 3");

        // 6. we = 0 no escribe: mem[0xFE8] debe seguir en 2
        @(negedge clk); we = 0; addr = 32'h00000FE8; wdata = 32'hFFFFFFFF;
        @(negedge clk);
        leer(32'h00000FE8);                 revisar(32'h00000002, "6 we=0 no escribe");

        // 7. dump de la memoria: 1024 lineas "0x<direccion> 0x<valor>". Las de
        //    0xFE0, 0xFE4 y 0xFE8 deben ser 0x62000000, 0x0000C7DF y 0x00000002
        f = $fopen("dump_data_mem.txt", "w");
        for (k = 0; k < 1024; k = k + 1)
            $fdisplay(f, "0x%0h 0x%08h", k * 4, dut.mem[k]);
        $fclose(f);
        $display("Dump escrito en dump_data_mem.txt (1024 palabras)");

        // ---------------- Resumen ----------------
        if (errores == 0) $display("tb_data_mem: TODAS LAS PRUEBAS PASARON");
        else              $display("tb_data_mem: %0d ERRORES", errores);
        $finish;
    end

endmodule
