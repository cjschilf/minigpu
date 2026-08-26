`timescale 1ns/1ps

module instruction_decoder (
    input  logic [31:0]                instruction,
    output minigpu_pkg::decode_ctrl_t  control
);

  import minigpu_pkg::*;

  localparam logic [6:0] OPCODE_OP     = 7'b0110011;
  localparam logic [6:0] OPCODE_OP_IMM = 7'b0010011;
  localparam logic [6:0] OPCODE_LOAD   = 7'b0000011;
  localparam logic [6:0] OPCODE_STORE  = 7'b0100011;
  localparam logic [6:0] OPCODE_BRANCH = 7'b1100011;
  localparam logic [6:0] OPCODE_SYSTEM = 7'b1110011;

  logic [6:0] opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;

  always_comb begin
    opcode = instruction[6:0];
    funct3 = instruction[14:12];
    funct7 = instruction[31:25];

    control = '0;
    control.rs1     = instruction[19:15];
    control.rs2     = instruction[24:20];
    control.rd      = instruction[11:7];
    control.illegal = 1'b1;

    unique case (opcode)
      OPCODE_OP: begin
        control.register_write = 1'b1;
        unique case ({funct7, funct3})
          10'b0000000_000: begin control.alu_op = ALU_ADD; control.illegal = 1'b0; end
          10'b0100000_000: begin control.alu_op = ALU_SUB; control.illegal = 1'b0; end
          10'b0000000_100: begin control.alu_op = ALU_XOR; control.illegal = 1'b0; end
          10'b0000000_110: begin control.alu_op = ALU_OR;  control.illegal = 1'b0; end
          10'b0000000_111: begin control.alu_op = ALU_AND; control.illegal = 1'b0; end
          10'b0000001_000: begin control.alu_op = ALU_MUL; control.illegal = 1'b0; end
          default: control.register_write = 1'b0;
        endcase
      end

      OPCODE_OP_IMM: begin
        control.imm_sel         = IMM_I;
        control.use_immediate   = 1'b1;
        control.register_write  = 1'b1;
        unique case (funct3)
          3'b000: begin control.alu_op = ALU_ADD; control.illegal = 1'b0; end
          3'b100: begin control.alu_op = ALU_XOR; control.illegal = 1'b0; end
          3'b110: begin control.alu_op = ALU_OR;  control.illegal = 1'b0; end
          3'b111: begin control.alu_op = ALU_AND; control.illegal = 1'b0; end
          default: control.register_write = 1'b0;
        endcase
      end

      OPCODE_LOAD: begin
        if (funct3 == 3'b010) begin
          control.alu_op          = ALU_ADD;
          control.mem_op          = MEM_LOAD;
          control.imm_sel         = IMM_I;
          control.use_immediate   = 1'b1;
          control.register_write  = 1'b1;
          control.illegal         = 1'b0;
        end
      end

      OPCODE_STORE: begin
        if (funct3 == 3'b010) begin
          control.alu_op        = ALU_ADD;
          control.mem_op        = MEM_STORE;
          control.imm_sel       = IMM_S;
          control.use_immediate = 1'b1;
          control.illegal       = 1'b0;
        end
      end

      OPCODE_BRANCH: begin
        control.imm_sel = IMM_B;
        unique case (funct3)
          3'b000: begin control.branch_op = BR_EQ;  control.illegal = 1'b0; end
          3'b001: begin control.branch_op = BR_NE;  control.illegal = 1'b0; end
          3'b100: begin control.branch_op = BR_LT;  control.illegal = 1'b0; end
          3'b101: begin control.branch_op = BR_GE;  control.illegal = 1'b0; end
          3'b110: begin control.branch_op = BR_LTU; control.illegal = 1'b0; end
          3'b111: begin control.branch_op = BR_GEU; control.illegal = 1'b0; end
          default: control.branch_op = BR_NONE;
        endcase
      end

      OPCODE_SYSTEM: begin
        if (instruction == 32'h0010_0073) begin
          control.ebreak  = 1'b1;
          control.illegal = 1'b0;
        end
      end

      default: begin
      end
    endcase
  end

endmodule
