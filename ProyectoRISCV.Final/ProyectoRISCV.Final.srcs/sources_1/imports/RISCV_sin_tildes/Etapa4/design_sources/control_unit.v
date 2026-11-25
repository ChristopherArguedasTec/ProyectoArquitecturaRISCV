`timescale 1ns / 1ps
// ============================================================================
// Modulo:   control_unit  (Unidad de Control, FSM)
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Maquina de estados que genera todas las senales de control a partir del
// estado actual, el opcode, funct3 y las banderas zero y lt de la ALU.
// Decide que camino recorren los datos en cada ciclo y cuando se escribe
// cada elemento (PC, IR, banco de registros, memoria de datos). Es lo que
// permite que el mismo hardware ejecute las 11 instrucciones del programa.
// Esta organizada en cuatro bloques:
//   1. registro de estado          (secuencial)
//   2. siguiente estado            (combinacional)
//   3. senales de seleccion        (dependen solo de la instruccion)
//   4. senales de escritura        (dependen del estado)
// ============================================================================
module control_unit (
    input  wire       clk,                  // reloj
    input  wire       reset,                // reset sincrono: lleva la FSM a S0
    input  wire [6:0] opcode,               // ir[6:0]
    input  wire [2:0] funct3,               // ir[14:12]
    input  wire       zero,                 // bandera de cero de la ALU
    input  wire       lt,                   // bandera "menor que" con signo de la ALU
    // Escrituras (dependen del estado)
    output reg        PCWrite,              // escribe el PC
    output reg        IRWrite,              // escribe el IR
    output reg        RegWrite,             // escribe el banco de registros
    output reg        MemWrite,             // escribe la memoria de datos
    // Selecciones (dependen solo de la instruccion)
    output reg        StoreByte,            // 1 = sb, 0 = sw
    output reg  [1:0] PCSrc,                // 00 PC+4, 01 PC+Imm, 10 destino jalr
    output reg  [1:0] ResultSrc,            // 00 ALUOut, 01 MDR, 10 PC+4, 11 ImmExt
    output reg  [2:0] ImmSrc,               // 000 I, 001 S, 010 B, 011 U, 100 J
    output reg        ALUSrc,               // 0 = B, 1 = ImmExt
    output reg  [2:0] ALUControl            // 000 suma, 001 resta, 010 AND, 011 SLL
);

    // ---------------- Opcodes soportados ----------------
    localparam OP_IMM = 7'b0010011;   // addi, andi, slli
    localparam LOAD   = 7'b0000011;   // lw
    localparam STORE  = 7'b0100011;   // sw, sb
    localparam BRANCH = 7'b1100011;   // bne, bge
    localparam LUI    = 7'b0110111;   // lui
    localparam JAL    = 7'b1101111;   // jal
    localparam JALR   = 7'b1100111;   // jalr

    // ---------------- Estados ----------------
    localparam S0_FETCH     = 3'd0;   // IR <- PRG MEM[PC]
    localparam S1_DECODE    = 3'd1;   // A <- rs1, B <- rs2, se arma ImmExt
    localparam S2_EXECUTE   = 3'd2;   // la ALU opera; en branches se decide el salto
    localparam S3_MEMORY    = 3'd3;   // lw: MDR <- memoria; sw/sb: escribe memoria
    localparam S4_WRITEBACK = 3'd4;   // se escribe rd y se actualiza el PC
    localparam S_HALT       = 3'd5;   // opcode no soportado: el procesador se detiene

    reg [2:0] state, next_state;      // estado actual y siguiente

    // valido = 1 si el opcode es uno de los siete soportados
    wire valido = (opcode == OP_IMM) || (opcode == LOAD) || (opcode == STORE) ||
                  (opcode == BRANCH) || (opcode == LUI)  || (opcode == JAL)   ||
                  (opcode == JALR);

    // Decision del branch: bne (funct3 = 001) usa ~zero, bge (funct3 = 101) usa ~lt
    wire take = funct3[2] ? ~lt : ~zero;

    // ---------------- Bloque 1: registro de estado (secuencial) ----------------
    always @(posedge clk) begin
        if (reset) state <= S0_FETCH;
        else       state <= next_state;
    end

    // ---------------- Bloque 2: siguiente estado (combinacional) ----------------
    // Fetch siempre pasa a Decode. HALT se queda en HALT y solo sale con reset.
    always @(*) begin
        case (state)
            S0_FETCH:  next_state = S1_DECODE;
            S1_DECODE: begin
                if (!valido)                               next_state = S_HALT;
                else if (opcode == LUI || opcode == JAL)   next_state = S4_WRITEBACK;
                else                                       next_state = S2_EXECUTE;
            end
            S2_EXECUTE: begin
                if (opcode == LOAD || opcode == STORE)     next_state = S3_MEMORY;
                else if (opcode == BRANCH)                 next_state = S0_FETCH;
                else                                       next_state = S4_WRITEBACK;
            end
            S3_MEMORY: begin
                if (opcode == LOAD)                        next_state = S4_WRITEBACK;
                else                                       next_state = S0_FETCH;
            end
            S4_WRITEBACK:                                  next_state = S0_FETCH;
            S_HALT:                                        next_state = S_HALT;
            default:                                       next_state = S0_FETCH;
        endcase
    end

    // ---------- Bloque 3: senales que dependen solo de la instruccion ----------
    // Son estables durante toda la instruccion; asi ALUOut recaptura siempre
    // el mismo valor. En branches PCSrc tambien depende de take.
    always @(*) begin
        // valores por defecto
        ImmSrc     = 3'b000;
        ALUSrc     = 1'b1;
        ALUControl = 3'b000;
        ResultSrc  = 2'b00;
        PCSrc      = 2'b00;
        StoreByte  = 1'b0;

        case (opcode)
            OP_IMM: begin
                ImmSrc = 3'b000; ALUSrc = 1'b1; ResultSrc = 2'b00;
                case (funct3)
                    3'b000:  ALUControl = 3'b000;   // addi -> suma
                    3'b111:  ALUControl = 3'b010;   // andi -> AND
                    3'b001:  ALUControl = 3'b011;   // slli -> SLL
                    default: ALUControl = 3'b000;
                endcase
            end
            // lw: direccion rs1 + imm, rd <- MDR
            LOAD:   begin ImmSrc = 3'b000; ALUSrc = 1'b1; ALUControl = 3'b000; ResultSrc = 2'b01; end
            // sw/sb: direccion rs1 + imm
            STORE:  begin ImmSrc = 3'b001; ALUSrc = 1'b1; ALUControl = 3'b000;
                          StoreByte = (funct3 == 3'b000); end                    // sb = 000, sw = 010
            // bne/bge: resta rs1 - rs2; si salta PC <- PC+Imm, si no PC <- PC+4
            BRANCH: begin ImmSrc = 3'b010; ALUSrc = 1'b0; ALUControl = 3'b001;
                          PCSrc = take ? 2'b01 : 2'b00; end
            // lui: rd <- inmediato
            LUI:    begin ImmSrc = 3'b011; ResultSrc = 2'b11; PCSrc = 2'b00; end
            // jal: rd <- PC+4, PC <- PC+Imm
            JAL:    begin ImmSrc = 3'b100; ResultSrc = 2'b10; PCSrc = 2'b01; end
            // jalr: rd <- PC+4, PC <- rs1+imm
            JALR:   begin ImmSrc = 3'b000; ALUSrc = 1'b1; ALUControl = 3'b000;
                          ResultSrc = 2'b10; PCSrc = 2'b10; end
            default: ;                                                         // valores por defecto
        endcase
    end

    // ---------------- Bloque 4: escrituras, dependen del estado ---------------
    // PCWrite se activa en el ultimo estado de cada instruccion. En S2 de un
    // branch PCWrite = 1 siempre; take solo elige PCSrc.
    always @(*) begin
        PCWrite  = 1'b0;
        IRWrite  = 1'b0;
        RegWrite = 1'b0;
        MemWrite = 1'b0;
        case (state)
            S0_FETCH:     IRWrite = 1'b1;
            S2_EXECUTE:   if (opcode == BRANCH) PCWrite = 1'b1;
            S3_MEMORY:    if (opcode == STORE) begin MemWrite = 1'b1; PCWrite = 1'b1; end
            S4_WRITEBACK: begin RegWrite = 1'b1; PCWrite = 1'b1; end
            default: ;                                   // S1 y HALT: sin escrituras
        endcase
    end

endmodule
