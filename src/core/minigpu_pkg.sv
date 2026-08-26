`timescale 1ns/1ps

package minigpu_pkg;

  typedef logic [4:0] reg_idx_t;

  typedef enum logic [3:0] {
    ALU_INVALID = 4'd0,
    ALU_ADD     = 4'd1,
    ALU_SUB     = 4'd2,
    ALU_XOR     = 4'd3,
    ALU_OR      = 4'd4,
    ALU_AND     = 4'd5,
    ALU_MUL     = 4'd6
  } alu_op_e;

  typedef enum logic [2:0] {
    BR_NONE = 3'd0,
    BR_EQ   = 3'd1,
    BR_NE   = 3'd2,
    BR_LT   = 3'd3,
    BR_GE   = 3'd4,
    BR_LTU  = 3'd5,
    BR_GEU  = 3'd6
  } branch_op_e;

  typedef enum logic [1:0] {
    IMM_NONE = 2'd0,
    IMM_I    = 2'd1,
    IMM_S    = 2'd2,
    IMM_B    = 2'd3
  } imm_sel_e;

  typedef enum logic [1:0] {
    MEM_NONE  = 2'd0,
    MEM_LOAD  = 2'd1,
    MEM_STORE = 2'd2
  } mem_op_e;

  typedef enum logic [2:0] {
    COMPLETE_SUCCESS     = 3'd0,
    COMPLETE_ILLEGAL     = 3'd1,
    COMPLETE_UNSUPPORTED = 3'd2,
    COMPLETE_MEMORY_ERR  = 3'd3,
    COMPLETE_DIVERGENCE  = 3'd4,
    COMPLETE_MISALIGNED  = 3'd5
  } completion_status_e;

  typedef struct packed {
    alu_op_e    alu_op;
    branch_op_e branch_op;
    mem_op_e    mem_op;
    imm_sel_e    imm_sel;
    reg_idx_t   rs1;
    reg_idx_t   rs2;
    reg_idx_t   rd;
    logic        use_immediate;
    logic        use_lane_id;
    logic        register_write;
    logic        ebreak;
    logic        illegal;
  } decode_ctrl_t;

endpackage
