`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_riscv_top
//
// Objetivo:
//   Correr el programa completo (las 36 instrucciones de main en
//   programa.hex) en el procesador multiciclo, detectar el fin del programa
//   (el ret de main), hacer el dump de la memoria de datos a un archivo y
//   comparar el resultado con el estado final esperado.
//   Se espera que el ret se ejecute en el ciclo 191 contando desde el reset
//   (47 instrucciones ejecutadas).
// ============================================================================
module tb_riscv_top;

    // ---------------- Reloj, reset y contadores ----------------
    reg clk = 0, reset = 1;
    integer ciclos = 0, instrucciones = 0, errores = 0, f, k;

    // Salidas del procesador
    wire        mem_we, mem_byte, reg_we, done;
    wire [31:0] mem_addr, mem_wdata, reg_wd;
    wire [4:0]  reg_wa;

    // ---------------- Procesador bajo prueba ----------------
    riscv_top #(.PROGRAMA("programa.hex")) dut (
        .clk(clk), .reset(reset),
        .mem_we(mem_we), .mem_byte(mem_byte), .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .reg_we(reg_we), .reg_wa(reg_wa), .reg_wd(reg_wd), .done(done));

    always #5 clk = ~clk;   // periodo de 10 ns

    // ---------------- Monitor de escrituras a memoria ----------------
    // Muestra cada escritura a memoria hecha por el programa (sw / sb), para
    // ver como cambian las variables del programa en C. La direccion se
    // muestra con sus 12 bits bajos, que son los que usa la memoria. El ciclo
    // impreso puede variar en 1 segun el simulador, porque el contador y el
    // mensaje estan en dos bloques que se ejecutan en el mismo flanco; no
    // afecta el resultado.
    always @(posedge clk) begin
        if (!reset && mem_we) begin
            if (mem_byte)
                $display("  ciclo %0d: sb  mem[0x%0h] <- 0x%02h", ciclos, mem_addr[11:0], mem_wdata[7:0]);
            else
                $display("  ciclo %0d: sw  mem[0x%0h] <- 0x%08h", ciclos, mem_addr[11:0], mem_wdata);
        end
    end

    // ---------------- Contadores ----------------
    // Cuenta ciclos e instrucciones terminadas (cuando se escribe el PC)
    always @(posedge clk) begin
        if (!reset) begin
            ciclos = ciclos + 1;
            if (dut.PCWrite) instrucciones = instrucciones + 1;
        end
    end

    // ---------------- Tareas de revision ----------------
    // revisar_mem: lee una palabra de la memoria de datos por jerarquia
    // (dir >> 2 = numero de palabra) y la compara con el valor esperado
    task revisar_mem(input [31:0] dir, input [31:0] esperado, input [8*20-1:0] nom_var);
        begin
            if (dut.u_dmem.mem[dir >> 2] !== esperado) begin
                $display("ERROR  mem[0x%0h] (%0s) = %h, esperado %h",
                         dir, nom_var, dut.u_dmem.mem[dir >> 2], esperado);
                errores = errores + 1;
            end else
                $display("OK     mem[0x%0h] (%0s) = %h", dir, nom_var, dut.u_dmem.mem[dir >> 2]);
        end
    endtask

    // revisar_reg: lee un registro del banco por jerarquia y lo compara
    task revisar_reg(input [4:0] n, input [31:0] esperado, input [8*4-1:0] nom);
        begin
            if (dut.u_regfile.regs[n] !== esperado) begin
                $display("ERROR  %0s (x%0d) = %h, esperado %h", nom, n, dut.u_regfile.regs[n], esperado);
                errores = errores + 1;
            end else
                $display("OK     %0s (x%0d) = %h", nom, n, dut.u_regfile.regs[n]);
        end
    endtask

    // ---------------- Estimulos ----------------
    initial begin
        // 1. reset durante dos ciclos
        repeat (2) @(negedge clk);
        reset = 0;

        // 2. correr hasta el ret (salida done). Si en 1000 ciclos no termina,
        //    se detiene con error
        while (!done && ciclos < 1000)
            @(negedge clk);
        @(negedge clk);   // deja pasar el flanco que ejecuta el ret

        if (ciclos >= 1000) begin
            $display("ERROR  el programa no termino en 1000 ciclos");
            errores = errores + 1;
        end
        $display("Fin del programa: %0d ciclos, %0d instrucciones", ciclos, instrucciones);

        // 3. Dump de la memoria de datos: 1024 lineas "0x<direccion> 0x<valor>"
        f = $fopen("dump_memoria_datos.txt", "w");
        for (k = 0; k < 1024; k = k + 1)
            $fdisplay(f, "0x%0h 0x%08h", k * 4, dut.u_dmem.mem[k]);
        $fclose(f);
        $display("Dump escrito en dump_memoria_datos.txt");

        // 4. Comparacion con el estado final esperado
        revisar_mem(32'hfe0, 32'h62000000, "a");               // char a = 'b' en el byte 0xfe3
        revisar_mem(32'hfe4, 32'h0000c7df, "r");
        revisar_mem(32'hfe8, 32'h00000002, "i");
        revisar_mem(32'hfec, 32'h00000002, "b");               // 33 -> 66 -> 66 & 15 = 2
        revisar_mem(32'hff8, 32'h00000000, "s0 guardado");
        revisar_mem(32'hffc, 32'h00000000, "ra guardado");
        revisar_reg(5'd2,  32'h00000000, "sp");
        revisar_reg(5'd8,  32'h00000000, "s0");
        revisar_reg(5'd14, 32'h00000002, "a4");
        revisar_reg(5'd15, 32'h00000000, "a5");
        if (ciclos !== 191) begin                              // 191 ciclos desde el reset
            $display("ERROR  ciclos = %0d, esperado 191", ciclos); errores = errores + 1;
        end

        // ---------------- Resumen ----------------
        if (errores == 0) $display("tb_riscv_top: EL PROGRAMA CORRIO CORRECTAMENTE");
        else              $display("tb_riscv_top: %0d ERRORES", errores);
        $finish;
    end

endmodule
