`timescale 1ns/1ps

module wavefront_controller #(
    parameter int LANES = 4,
    parameter int XLEN = 32,
    parameter int ID_WIDTH = 8,
    parameter int REG_ADDR_WIDTH = 5
) (
    input  logic                                  clk,
    input  logic                                  reset_n,

    input  logic                                  wavefront_valid,
    input  logic [31:0]                           wavefront_pc,
    input  logic [LANES-1:0]                      wavefront_exec_mask,
    input  logic [ID_WIDTH-1:0]                   wavefront_id,

    output logic                                  instruction_request_valid,
    input  logic                                  instruction_request_ready,
    output logic [31:0]                           instruction_request_address,
    input  logic                                  instruction_response_valid,
    output logic                                  instruction_response_ready,
    input  logic [31:0]                           instruction_response_data,
    input  logic                                  instruction_response_error,

    output logic                                  vector_issue_valid,
    output minigpu_pkg::alu_op_e                  vector_issue_alu_op,
    output minigpu_pkg::branch_op_e               vector_issue_branch_op,
    output logic [REG_ADDR_WIDTH-1:0]             vector_issue_rs1,
    output logic [REG_ADDR_WIDTH-1:0]             vector_issue_rs2,
    output logic                                  vector_issue_use_immediate,
    output logic                                  vector_issue_use_lane_id,
    output logic [XLEN-1:0]                       vector_issue_immediate,
    output logic [LANES-1:0]                      vector_issue_exec_mask,
    input  logic [LANES-1:0][XLEN-1:0]            vector_execute_result,
    input  logic [LANES-1:0]                      vector_execute_valid_mask,
    input  logic [LANES-1:0]                      vector_branch_taken_mask,
    input  logic [LANES-1:0]                      vector_branch_valid_mask,
    input  logic [LANES-1:0][XLEN-1:0]            vector_store_data,

    output logic                                  vector_writeback_enable,
    output logic [REG_ADDR_WIDTH-1:0]             vector_writeback_rd,
    output logic [LANES-1:0]                      vector_writeback_mask,
    output logic [LANES-1:0][XLEN-1:0]            vector_writeback_data,

    output logic                                  lsu_issue_valid,
    input  logic                                  lsu_issue_ready,
    output minigpu_pkg::mem_op_e                  lsu_issue_mem_op,
    output logic [LANES-1:0]                      lsu_issue_mask,
    output logic [LANES-1:0][XLEN-1:0]            lsu_issue_address,
    output logic [LANES-1:0][XLEN-1:0]            lsu_issue_store_data,
    input  logic                                  lsu_done_valid,
    output logic                                  lsu_done_ready,
    input  logic [LANES-1:0]                      lsu_done_mask,
    input  logic [LANES-1:0][XLEN-1:0]            lsu_done_load_data,
    input  logic                                  lsu_done_error,
    input  logic                                  lsu_done_misaligned,

    output logic                                  wavefront_advance_valid,
    output logic [31:0]                           wavefront_advance_pc,
    output logic [LANES-1:0]                      wavefront_advance_exec_mask,
    output logic                                  wavefront_complete_valid,

    output logic                                  completion_valid,
    input  logic                                  completion_ready,
    output logic [ID_WIDTH-1:0]                   completion_wavefront_id,
    output minigpu_pkg::completion_status_e       completion_status,

    output logic                                  retire_valid,
    output logic [31:0]                           retire_pc,
    output logic [31:0]                           retire_instruction,
    output logic [REG_ADDR_WIDTH-1:0]             retire_rd,
    output logic [LANES-1:0]                      retire_write_mask,
    output logic [LANES-1:0][XLEN-1:0]            retire_data
);

  import minigpu_pkg::*;

  typedef enum logic [2:0] {
    STATE_IDLE,
    STATE_FETCH_REQUEST,
    STATE_FETCH_RESPONSE,
    STATE_EXECUTE,
    STATE_MEMORY_WAIT,
    STATE_COMPLETE
  } state_e;

  state_e state;
  logic [31:0] instruction;
  decode_ctrl_t decode;
  logic [31:0] immediate;
  completion_status_e status;
  logic alu_supported;
  logic branch_supported;
  logic memory_supported;
  logic alu_complete;
  logic branch_complete;
  logic address_complete;
  logic branch_all_taken;
  logic branch_divergent;
  logic execute_complete;
  logic memory_finish;

  instruction_decoder decoder (
    .instruction(instruction),
    .control(decode)
  );

  immediate_gen immediate_decoder (
    .instruction_31_20(instruction[31:20]),
    .instruction_11_7(instruction[11:7]),
    .select(decode.imm_sel),
    .immediate(immediate)
  );

  branch_resolver #(.LANES(LANES)) resolver (
    .exec_mask(wavefront_exec_mask),
    .taken_mask(vector_branch_taken_mask),
    .all_taken(branch_all_taken),
    .divergent(branch_divergent)
  );

  always_comb begin
    alu_supported = !decode.illegal &&
                    !decode.ebreak &&
                    (decode.mem_op == MEM_NONE) &&
                    (decode.branch_op == BR_NONE) &&
                    (decode.alu_op != ALU_INVALID);
    branch_supported = !decode.illegal &&
                       !decode.ebreak &&
                       (decode.mem_op == MEM_NONE) &&
                       (decode.branch_op != BR_NONE);
    memory_supported = !decode.illegal &&
                       !decode.ebreak &&
                       (decode.mem_op != MEM_NONE) &&
                       (decode.branch_op == BR_NONE) &&
                       (decode.alu_op == ALU_ADD);

    vector_issue_valid         = (state == STATE_EXECUTE) &&
                                 (alu_supported || branch_supported ||
                                  memory_supported);
    vector_issue_alu_op        = decode.alu_op;
    vector_issue_branch_op     = decode.branch_op;
    vector_issue_rs1           = decode.rs1;
    vector_issue_rs2           = decode.rs2;
    vector_issue_use_immediate = decode.use_immediate;
    vector_issue_use_lane_id   = decode.use_lane_id;
    vector_issue_immediate     = immediate;
    vector_issue_exec_mask     = wavefront_exec_mask;
  end

  always_comb begin
    instruction_request_valid   = state == STATE_FETCH_REQUEST;
    instruction_request_address = wavefront_pc;
    instruction_response_ready  = state == STATE_FETCH_RESPONSE;

    alu_complete               = vector_issue_valid &&
                                 alu_supported &&
                                 (vector_execute_valid_mask ==
                                  wavefront_exec_mask);
    branch_complete            = vector_issue_valid &&
                                 branch_supported &&
                                 (vector_branch_valid_mask ==
                                  wavefront_exec_mask);
    address_complete           = vector_issue_valid &&
                                 memory_supported &&
                                 (vector_execute_valid_mask ==
                                  wavefront_exec_mask);
    lsu_done_ready             = state == STATE_MEMORY_WAIT;
    execute_complete           = alu_complete ||
                                 (branch_complete && !branch_divergent);
    memory_finish              = (state == STATE_MEMORY_WAIT) &&
                                 lsu_done_valid &&
                                 lsu_done_ready &&
                                 !lsu_done_error &&
                                 !lsu_done_misaligned;

    vector_writeback_enable = ((state == STATE_EXECUTE) &&
                               alu_complete &&
                               decode.register_write) ||
                              (memory_finish &&
                               (decode.mem_op == MEM_LOAD));
    vector_writeback_rd     = decode.rd;
    vector_writeback_mask   = memory_finish
                              ? lsu_done_mask
                              : wavefront_exec_mask;
    vector_writeback_data   = memory_finish
                              ? lsu_done_load_data
                              : vector_execute_result;

    lsu_issue_valid      = (state == STATE_EXECUTE) && address_complete;
    lsu_issue_mem_op     = decode.mem_op;
    lsu_issue_mask       = wavefront_exec_mask;
    lsu_issue_address    = vector_execute_result;
    lsu_issue_store_data = vector_store_data;

    wavefront_advance_valid     = ((state == STATE_EXECUTE) &&
                                   execute_complete) ||
                                  memory_finish;
    wavefront_advance_pc        = branch_all_taken
                                  ? wavefront_pc + immediate
                                  : wavefront_pc + 32'd4;
    wavefront_advance_exec_mask = wavefront_exec_mask;
    wavefront_complete_valid    = (state == STATE_COMPLETE) &&
                                  completion_ready;

    completion_valid        = state == STATE_COMPLETE;
    completion_wavefront_id = wavefront_id;
    completion_status       = status;

    retire_valid       = ((state == STATE_EXECUTE) && execute_complete) ||
                         memory_finish;
    retire_pc          = wavefront_pc;
    retire_instruction = instruction;
    retire_rd          = decode.rd;
    if (memory_finish) begin
      retire_write_mask = (decode.mem_op == MEM_LOAD) ? lsu_done_mask : '0;
      retire_data       = lsu_done_load_data;
    end else begin
      retire_write_mask = decode.register_write ? wavefront_exec_mask : '0;
      retire_data       = vector_execute_result;
    end
  end

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      state       <= STATE_IDLE;
      instruction <= '0;
      status      <= COMPLETE_SUCCESS;
    end else begin
      unique case (state)
        STATE_IDLE: begin
          if (wavefront_valid) begin
            status <= COMPLETE_SUCCESS;
            state  <= STATE_FETCH_REQUEST;
          end
        end

        STATE_FETCH_REQUEST: begin
          if (instruction_request_valid && instruction_request_ready) begin
            state <= STATE_FETCH_RESPONSE;
          end
        end

        STATE_FETCH_RESPONSE: begin
          if (instruction_response_valid && instruction_response_ready) begin
            if (instruction_response_error) begin
              status <= COMPLETE_MEMORY_ERR;
              state  <= STATE_COMPLETE;
            end else begin
              instruction <= instruction_response_data;
              state       <= STATE_EXECUTE;
            end
          end
        end

        STATE_EXECUTE: begin
          if (decode.illegal) begin
            status <= COMPLETE_ILLEGAL;
            state  <= STATE_COMPLETE;
          end else if (decode.ebreak) begin
            status <= COMPLETE_SUCCESS;
            state  <= STATE_COMPLETE;
          end else if (branch_supported) begin
            if (branch_complete) begin
              if (branch_divergent) begin
                status <= COMPLETE_DIVERGENCE;
                state  <= STATE_COMPLETE;
              end else begin
                state <= STATE_FETCH_REQUEST;
              end
            end
          end else if (alu_supported) begin
            if (alu_complete) begin
              state <= STATE_FETCH_REQUEST;
            end
          end else if (memory_supported) begin
            if (address_complete && lsu_issue_ready) begin
              state <= STATE_MEMORY_WAIT;
            end
          end else begin
            status <= COMPLETE_UNSUPPORTED;
            state  <= STATE_COMPLETE;
          end
        end

        STATE_MEMORY_WAIT: begin
          if (lsu_done_valid && lsu_done_ready) begin
            if (lsu_done_misaligned) begin
              status <= COMPLETE_MISALIGNED;
              state  <= STATE_COMPLETE;
            end else if (lsu_done_error) begin
              status <= COMPLETE_MEMORY_ERR;
              state  <= STATE_COMPLETE;
            end else begin
              state <= STATE_FETCH_REQUEST;
            end
          end
        end

        STATE_COMPLETE: begin
          if (completion_valid && completion_ready) begin
            state <= STATE_IDLE;
          end
        end

        default: state <= STATE_IDLE;
      endcase
    end
  end

endmodule
