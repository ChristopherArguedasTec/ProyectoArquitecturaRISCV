`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_control_unit
//
// Objetivo:
//   Verificar que la FSM recorre los estados correctos para cada tipo de
//   instruccion, que las escrituras (PCWrite, IRWrite, RegWrite, MemWrite)
//   se activan solo en el estado que corresponde, que las senales de
//   seleccion tienen el valor de la tabla de senales, que los branches
//   deciden bien con zero/lt y que un opcode no soportado lleva a HALT.
//
// Metodo: para cada caso se aplica reset, se fijan opcode, funct3, zero y lt,
// y se avanza ciclo a ciclo revisando el estado y las escrituras. En el
// ultimo ciclo se revisan tambien las senales de seleccion.
// Estados: S0..S4 = 0..4, HALT = 5.
// ============================================================================
module tb_control_unit;

    // ---------------- Senales hacia y desde la unidad de control ----------------
    reg        clk = 0, reset = 0;
    reg  [6:0] opcode = 0;                  // entradas que fija el testbench
    reg  [2:0] funct3 = 0;
    reg        zero = 0, lt = 0;
    wire       PCWrite, IRWrite, RegWrite, MemWrite, StoreByte, ALUSrc;   // salidas
    wire [1:0] PCSrc, ResultSrc;
    wire [2:0] ImmSrc, ALUControl;
    integer    errores = 0;                 // contador de pruebas fallidas

    // ---------------- Modulo bajo prueba ----------------
    control_unit dut (.clk(clk), .reset(reset), .opcode(opcode), .funct3(funct3),
                      .zero(zero), .lt(lt), .PCWrite(PCWrite), .IRWrite(IRWrite),
                      .RegWrite(RegWrite), .MemWrite(MemWrite), .StoreByte(StoreByte),
                      .PCSrc(PCSrc), .ResultSrc(ResultSrc), .ImmSrc(ImmSrc),
                      .ALUSrc(ALUSrc), .ALUControl(ALUControl));

    // ---------------- Reloj ----------------
    always #5 clk = ~clk;   // periodo de 10 ns

    reg [8*12-1:0] nombre;   // nombre del caso que se esta probando

    // ---------------- Tareas ----------------
    // Revisa el estado y las escrituras del ciclo actual y avanza un ciclo.
    // esc = {PCWrite, IRWrite, RegWrite, MemWrite}
    task ciclo(input [2:0] e_state, input [3:0] esc);
        begin
            #1;
            if (dut.state !== e_state || {PCWrite, IRWrite, RegWrite, MemWrite} !== esc) begin
                $display("ERROR  %0s: estado %0d esc %b | esperado estado %0d esc %b",
                         nombre, dut.state, {PCWrite, IRWrite, RegWrite, MemWrite}, e_state, esc);
                errores = errores + 1;
            end
            @(negedge clk);
        end
    endtask

    // Revisa las senales de seleccion (se llama en el ultimo ciclo)
    task senales(input [1:0] e_pcsrc, input [1:0] e_res, input [2:0] e_imm,
                 input e_alusrc, input [2:0] e_aluc, input e_sb);
        begin
            #1;
            if (PCSrc !== e_pcsrc || ResultSrc !== e_res || ImmSrc !== e_imm ||
                ALUSrc !== e_alusrc || ALUControl !== e_aluc || StoreByte !== e_sb) begin
                $display("ERROR  %0s: PCSrc %b ResultSrc %b ImmSrc %b ALUSrc %b ALUControl %b StoreByte %b",
                         nombre, PCSrc, ResultSrc, ImmSrc, ALUSrc, ALUControl, StoreByte);
                $display("       esperado:  %b %b %b %b %b %b", e_pcsrc, e_res, e_imm, e_alusrc, e_aluc, e_sb);
                errores = errores + 1;
            end else
                $display("OK     %0s", nombre);
        end
    endtask

    // Prepara un caso: guarda el nombre, fija las entradas y aplica reset
    // (la FSM queda en S0)
    task iniciar(input [8*12-1:0] n, input [6:0] op, input [2:0] f3, input z, input l);
        begin
            nombre = n; opcode = op; funct3 = f3; zero = z; lt = l;
            reset = 1; @(negedge clk); reset = 0;
        end
    endtask

    // Combinaciones de escrituras que se esperan en cada estado
    //                       esc = PCWrite IRWrite RegWrite MemWrite
    localparam [3:0] FETCH = 4'b0100, NADA = 4'b0000, WB = 4'b1010, ST = 4'b1001, BR = 4'b1000;

    // ---------------- Estimulos ----------------
    // senales(PCSrc, ResultSrc, ImmSrc, ALUSrc, ALUControl, StoreByte)
    initial begin
        @(negedge clk);

        // ---- tipo I aritmetica: S0 S1 S2 S4, ResultSrc 00 ----
        iniciar("addi", 7'b0010011, 3'b000, 0, 0);   // ALUControl 000 (suma)
        ciclo(0, FETCH); ciclo(1, NADA); ciclo(2, NADA);
        senales(2'b00, 2'b00, 3'b000, 1, 3'b000, 0); ciclo(4, WB); ciclo(0, FETCH);

        iniciar("andi", 7'b0010011, 3'b111, 0, 0);   // ALUControl 010 (AND)
        ciclo(0, FETCH); ciclo(1, NADA); ciclo(2, NADA);
        senales(2'b00, 2'b00, 3'b000, 1, 3'b010, 0); ciclo(4, WB);

        iniciar("slli", 7'b0010011, 3'b001, 0, 0);   // ALUControl 011 (SLL)
        ciclo(0, FETCH); ciclo(1, NADA); ciclo(2, NADA);
        senales(2'b00, 2'b00, 3'b000, 1, 3'b011, 0); ciclo(4, WB);

        // ---- lw: S0 S1 S2 S3 S4, ResultSrc 01 (MDR) ----
        iniciar("lw", 7'b0000011, 3'b010, 0, 0);
        ciclo(0, FETCH); ciclo(1, NADA); ciclo(2, NADA); ciclo(3, NADA);
        senales(2'b00, 2'b01, 3'b000, 1, 3'b000, 0); ciclo(4, WB); ciclo(0, FETCH);

        // ---- tipo S: S0 S1 S2 S3, MemWrite y PCWrite en S3 ----
        iniciar("sw", 7'b0100011, 3'b010, 0, 0);   // StoreByte 0
        ciclo(0, FETCH); ciclo(1, NADA); ciclo(2, NADA);
        senales(2'b00, 2'b00, 3'b001, 1, 3'b000, 0); ciclo(3, ST); ciclo(0, FETCH);

        iniciar("sb", 7'b0100011, 3'b000, 0, 0);   // StoreByte 1
        ciclo(0, FETCH); ciclo(1, NADA); ciclo(2, NADA);
        senales(2'b00, 2'b00, 3'b001, 1, 3'b000, 1); ciclo(3, ST); ciclo(0, FETCH);

        // ---- tipo B: S0 S1 S2, PCWrite en S2, PCSrc = take ? 01 : 00 ----
        iniciar("bne salta", 7'b1100011, 3'b001, 0, 0);   // zero = 0 -> distintos
        ciclo(0, FETCH); ciclo(1, NADA);
        senales(2'b01, 2'b00, 3'b010, 0, 3'b001, 0); ciclo(2, BR); ciclo(0, FETCH);

        iniciar("bne no salta", 7'b1100011, 3'b001, 1, 0);   // zero = 1 -> iguales
        ciclo(0, FETCH); ciclo(1, NADA);
        senales(2'b00, 2'b00, 3'b010, 0, 3'b001, 0); ciclo(2, BR); ciclo(0, FETCH);

        iniciar("bge salta", 7'b1100011, 3'b101, 0, 0);   // lt = 0 -> rs1 >= rs2
        ciclo(0, FETCH); ciclo(1, NADA);
        senales(2'b01, 2'b00, 3'b010, 0, 3'b001, 0); ciclo(2, BR);

        iniciar("bge no salta", 7'b1100011, 3'b101, 0, 1);   // lt = 1 -> rs1 < rs2
        ciclo(0, FETCH); ciclo(1, NADA);
        senales(2'b00, 2'b00, 3'b010, 0, 3'b001, 0); ciclo(2, BR);

        // ---- tipo U y J: S0 S1 S4 (sin Execute) ----
        iniciar("lui", 7'b0110111, 3'b000, 0, 0);   // ResultSrc 11, ImmSrc 011
        ciclo(0, FETCH); ciclo(1, NADA);
        senales(2'b00, 2'b11, 3'b011, 1, 3'b000, 0); ciclo(4, WB); ciclo(0, FETCH);

        iniciar("jal", 7'b1101111, 3'b000, 0, 0);   // ResultSrc 10, PCSrc 01, ImmSrc 100
        ciclo(0, FETCH); ciclo(1, NADA);
        senales(2'b01, 2'b10, 3'b100, 1, 3'b000, 0); ciclo(4, WB); ciclo(0, FETCH);

        // ---- jalr: S0 S1 S2 S4, ResultSrc 10, PCSrc 10 ----
        iniciar("jalr", 7'b1100111, 3'b000, 0, 0);
        ciclo(0, FETCH); ciclo(1, NADA); ciclo(2, NADA);
        senales(2'b10, 2'b10, 3'b000, 1, 3'b000, 0); ciclo(4, WB); ciclo(0, FETCH);

        // ---- opcode no soportado: S0 S1 HALT HALT ... sin escrituras ----
        iniciar("HALT", 7'b0000000, 3'b000, 0, 0);
        ciclo(0, FETCH); ciclo(1, NADA); ciclo(5, NADA); ciclo(5, NADA); ciclo(5, NADA);
        // Con reset debe volver a S0
        reset = 1; @(negedge clk); reset = 0;
        #1;
        if (dut.state !== 3'd0) begin
            $display("ERROR  HALT: reset no devuelve a S0"); errores = errores + 1;
        end else
            $display("OK     HALT (se queda en HALT y sale con reset)");

        // ---------------- Resumen ----------------
        if (errores == 0) $display("tb_control_unit: TODAS LAS PRUEBAS PASARON");
        else              $display("tb_control_unit: %0d ERRORES", errores);
        $finish;
    end

endmodule
