`timescale 1ns / 1ps
// ============================================================================
// Módulo:  riscv_top
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Funcionalidad:
//   Módulo superior del procesador. Instancia todos los módulos y los conecta
//   según la tabla de conexiones (sección 4 del documento). No tiene lógica
//   propia, salvo el cable que pone en cero el bit 0 del destino de jalr.
//
// Entradas:
//   clk   - reloj
//   reset - reset síncrono, activo en alto (PC = 0, FSM en Fetch, registros
//           en 0)
// Salidas (solo para observar el resultado; el enunciado limita las
// entradas a clk y reset, no las salidas):
//   mem_we    - 1 cuando se escribe en la memoria de datos (sw o sb)
//   mem_byte  - 1 si la escritura es de un byte (sb), 0 si es palabra (sw)
//   mem_addr  - dirección de la escritura (ALUOut)
//   mem_wdata - dato que se escribe (registro B; en sb solo cuenta [7:0])
//   reg_we    - 1 cuando se escribe un registro (Writeback)
//   reg_wa    - número del registro que se escribe (rd)
//   reg_wd    - valor que se escribe en rd (Result)
//   done      - 1 en el ciclo en que se ejecuta el ret (jalr) de main
//   Las salidas también evitan que la síntesis elimine la lógica. El dump
//   completo de la memoria se sigue haciendo desde el testbench.
//
// Parámetros:
//   PROGRAMA - archivo hexadecimal que se carga en la memoria de
//              instrucciones (lo único que se cambia durante la evaluación)
//
// Por qué existe:
//   Es la solución completa que se evalúa: une la ruta de datos (PC, memorias,
//   IR, banco de registros, A, B, ALU, ALUOut, MDR, sumadores, multiplexores
//   y generador de inmediatos) con la unidad de control.
// ============================================================================
module riscv_top #(
    parameter PROGRAMA = "programa.hex"
)(
    input  wire        clk,
    input  wire        reset,
    output wire        mem_we,
    output wire        mem_byte,
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    output wire        reg_we,
    output wire [4:0]  reg_wa,
    output wire [31:0] reg_wd,
    output wire        done
);

    // ---------------- Cables de la ruta de datos ----------------
    wire [31:0] pc, pc_next, pc_plus4, pc_imm;
    wire [31:0] instr, ir;
    wire [31:0] rd1, rd2, a, b;
    wire [31:0] imm_ext, alu_b, alu_result, alu_out;
    wire [31:0] mem_rdata, mdr, result;
    wire        zero, lt;

    // ---------------- Señales de control ----------------
    wire        PCWrite, IRWrite, RegWrite, MemWrite, StoreByte, ALUSrc;
    wire [1:0]  PCSrc, ResultSrc;
    wire [2:0]  ImmSrc, ALUControl;

    // ---------------- Campos de la instrucción ----------------
    wire [6:0]  opcode = ir[6:0];
    wire [2:0]  funct3 = ir[14:12];
    wire [4:0]  rs1    = ir[19:15];
    wire [4:0]  rs2    = ir[24:20];
    wire [4:0]  rd     = ir[11:7];

    // ---------------- Camino del PC ----------------
    reg_en   #(32) u_pc       (.clk(clk), .reset(reset), .en(PCWrite), .d(pc_next), .q(pc));
    sumador        u_add_pc4  (.a(pc), .b(32'd4),   .y(pc_plus4));
    sumador        u_add_pcimm(.a(pc), .b(imm_ext), .y(pc_imm));
    mux3     #(32) u_mux_pc   (.sel(PCSrc), .d0(pc_plus4), .d1(pc_imm),
                               .d2({alu_out[31:1], 1'b0}), .y(pc_next));

    // ---------------- Fetch ----------------
    instr_mem #(.DEPTH(256), .FILE(PROGRAMA)) u_imem (.addr(pc), .data(instr));
    reg_en   #(32) u_ir       (.clk(clk), .reset(reset), .en(IRWrite), .d(instr), .q(ir));

    // ---------------- Decode ----------------
    regfile        u_regfile  (.clk(clk), .reset(reset), .we(RegWrite), .ra1(rs1), .ra2(rs2),
                               .wa(rd), .wd(result), .rd1(rd1), .rd2(rd2));
    imm_gen        u_imm_gen  (.instr(ir), .imm_src(ImmSrc), .imm_ext(imm_ext));
    reg_noen #(32) u_a        (.clk(clk), .reset(reset), .d(rd1), .q(a));
    reg_noen #(32) u_b        (.clk(clk), .reset(reset), .d(rd2), .q(b));

    // ---------------- Execute ----------------
    mux2     #(32) u_mux_alusrc(.sel(ALUSrc), .d0(b), .d1(imm_ext), .y(alu_b));
    alu            u_alu      (.a(a), .b(alu_b), .alu_control(ALUControl),
                               .result(alu_result), .zero(zero), .lt(lt));
    reg_noen #(32) u_aluout   (.clk(clk), .reset(reset), .d(alu_result), .q(alu_out));

    // ---------------- Memory ----------------
    data_mem #(.DEPTH(1024)) u_dmem (.clk(clk), .we(MemWrite), .store_byte(StoreByte),
                                     .addr(alu_out), .wdata(b), .rdata(mem_rdata));
    reg_noen #(32) u_mdr      (.clk(clk), .reset(reset), .d(mem_rdata), .q(mdr));

    // ---------------- Writeback ----------------
    mux4     #(32) u_mux_result(.sel(ResultSrc), .d0(alu_out), .d1(mdr), .d2(pc_plus4),
                                .d3(imm_ext), .y(result));

    // ---------------- Unidad de control ----------------
    control_unit   u_ctrl     (.clk(clk), .reset(reset), .opcode(opcode), .funct3(funct3),
                               .zero(zero), .lt(lt), .PCWrite(PCWrite), .IRWrite(IRWrite),
                               .RegWrite(RegWrite), .MemWrite(MemWrite), .StoreByte(StoreByte),
                               .PCSrc(PCSrc), .ResultSrc(ResultSrc), .ImmSrc(ImmSrc),
                               .ALUSrc(ALUSrc), .ALUControl(ALUControl));

    // ---------------- Salidas de observación ----------------
    assign mem_we    = MemWrite;
    assign mem_byte  = StoreByte;
    assign mem_addr  = alu_out;
    assign mem_wdata = b;
    assign reg_we    = RegWrite;
    assign reg_wa    = rd;
    assign reg_wd    = result;
    // En jalr, PCWrite solo se activa en S4: ese es el ciclo del ret
    assign done      = PCWrite && (opcode == 7'b1100111);

endmodule
