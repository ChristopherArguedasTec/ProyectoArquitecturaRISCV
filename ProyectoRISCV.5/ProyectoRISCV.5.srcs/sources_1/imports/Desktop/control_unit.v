`timescale 1ns / 1ps
// ============================================================================
// Módulo:  control_unit  (Unidad de Control, FSM)
// Proyecto: Microarquitectura RISC-V RV32I multiciclo - MT-7003
//
// Funcionalidad:
//   Máquina de estados que genera todas las señales de control a partir del
//   estado actual, el opcode, funct3 y las banderas Zero y Lt de la ALU.
//
//   Estados (3 bits):
//     S0 FETCH     IR <- PRG MEM[PC]                      IRWrite = 1
//     S1 DECODE    A <- rs1, B <- rs2, se arma ImmExt     sin escrituras
//     S2 EXECUTE   la ALU opera; en branches se decide el salto
//     S3 MEMORY    lw: MDR <- memoria; sw/sb: se escribe la memoria
//     S4 WRITEBACK se escribe rd y se actualiza el PC
//     HALT         opcode no soportado: el procesador se detiene
//
//   Transiciones:
//     S0 -> S1 siempre
//     S1 -> S4 (lui, jal) | S2 (otros opcodes soportados) | HALT (no soportado)
//     S2 -> S3 (lw, sw, sb) | S4 (addi, andi, slli, jalr) | S0 (bne, bge)
//     S3 -> S0 (sw, sb) | S4 (lw)
//     S4 -> S0 siempre
//     HALT -> HALT (solo sale con reset)
//
//   Señales que dependen solo de opcode/funct3 (estables toda la instrucción):
//     ImmSrc, ALUSrc, ALUControl, ResultSrc, StoreByte, y PCSrc (en branches
//     también depende de take). Así ALUOut recaptura siempre el mismo valor.
//   Señales que dependen del estado (escrituras):
//     PCWrite, IRWrite, RegWrite, MemWrite.
//
//   Decisión de los branches (dentro de la UC):
//     take = funct3[2] ? !lt : !zero      (bne usa !zero, bge usa !lt)
//     En S2 de un branch PCWrite = 1 siempre; take solo elige PCSrc
//     (01 = PC + Imm si salta, 00 = PC + 4 si no).
//
// Entradas:
//   clk, reset - reloj y reset síncrono (lleva la FSM a S0)
//   opcode     - ir[6:0]
//   funct3     - ir[14:12]
//   zero, lt   - banderas de la ALU
// Salidas:
//   PCWrite, IRWrite, RegWrite, MemWrite, StoreByte (1 bit c/u)
//   PCSrc[1:0]      00 PC+4 · 01 PC+Imm · 10 ALUOut con bit 0 en cero (jalr)
//   ResultSrc[1:0]  00 ALUOut · 01 MDR · 10 PC+4 · 11 ImmExt
//   ImmSrc[2:0]     000 I · 001 S · 010 B · 011 U · 100 J
//   ALUSrc          0 = B · 1 = ImmExt
//   ALUControl[2:0] 000 suma · 001 resta · 010 AND · 011 SLL
//
// Por qué existe:
//   Decide qué camino recorren los datos en cada ciclo y cuándo se escribe
//   cada elemento (PC, IR, banco de registros, memoria de datos). Es lo que
//   permite que el mismo hardware ejecute las 11 instrucciones del programa.
// ============================================================================
module control_unit (
    input  wire       clk,
    input  wire       reset,
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire       zero,
    input  wire       lt,
    output reg        PCWrite,
    output reg        IRWrite,
    output reg        RegWrite,
    output reg        MemWrite,
    output reg        StoreByte,
    output reg  [1:0] PCSrc,
    output reg  [1:0] ResultSrc,
    output reg  [2:0] ImmSrc,
    output reg        ALUSrc,
    output reg  [2:0] ALUControl
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
    localparam S0_FETCH     = 3'd0;
    localparam S1_DECODE    = 3'd1;
    localparam S2_EXECUTE   = 3'd2;
    localparam S3_MEMORY    = 3'd3;
    localparam S4_WRITEBACK = 3'd4;
    localparam S_HALT       = 3'd5;

    reg [2:0] state, next_state;

    wire valido = (opcode == OP_IMM) || (opcode == LOAD) || (opcode == STORE) ||
                  (opcode == BRANCH) || (opcode == LUI)  || (opcode == JAL)   ||
                  (opcode == JALR);

    // Decisión del branch
    wire take = funct3[2] ? ~lt : ~zero;

    // ---------------- Bloque 1: registro de estado (secuencial) ----------------
    always @(posedge clk) begin
        if (reset) state <= S0_FETCH;
        else       state <= next_state;
    end

    // ---------------- Bloque 2: siguiente estado (combinacional) ----------------
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

    // ---------------- Señales que dependen solo de la instrucción ----------------
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
            LOAD:   begin ImmSrc = 3'b000; ALUSrc = 1'b1; ALUControl = 3'b000; ResultSrc = 2'b01; end
            STORE:  begin ImmSrc = 3'b001; ALUSrc = 1'b1; ALUControl = 3'b000;
                          StoreByte = (funct3 == 3'b000); end                    // sb = 000, sw = 010
            BRANCH: begin ImmSrc = 3'b010; ALUSrc = 1'b0; ALUControl = 3'b001;
                          PCSrc = take ? 2'b01 : 2'b00; end
            LUI:    begin ImmSrc = 3'b011; ResultSrc = 2'b11; PCSrc = 2'b00; end
            JAL:    begin ImmSrc = 3'b100; ResultSrc = 2'b10; PCSrc = 2'b01; end
            JALR:   begin ImmSrc = 3'b000; ALUSrc = 1'b1; ALUControl = 3'b000;
                          ResultSrc = 2'b10; PCSrc = 2'b10; end
            default: ;                                                         // valores por defecto
        endcase
    end

    // ---------------- Escrituras: dependen del estado ----------------
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
