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
    output logic [REG_ADDR_WIDTH-1:0]             vector_issue_rs1,
    output logic [REG_ADDR_WIDTH-1:0]             vector_issue_rs2,
    output logic                                  vector_issue_use_immediate,
    output logic [XLEN-1:0]                       vector_issue_immediate,
    output logic [LANES-1:0]                      vector_issue_exec_mask,
    input  logic [LANES-1:0][XLEN-1:0]            vector_execute_result,
    input  logic [LANES-1:0]                      vector_execute_valid_mask,

    output logic                                  vector_writeback_enable,
    output logic [REG_ADDR_WIDTH-1:0]             vector_writeback_rd,
    output logic [LANES-1:0]                      vector_writeback_mask,
    output logic [LANES-1:0][XLEN-1:0]            vector_writeback_data,

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
    STATE_COMPLETE
  } state_e;

  state_e state;
  logic [31:0] instruction;
  decode_ctrl_t decode;
  logic [31:0] immediate;
  completion_status_e status;
  logic execute_supported;
  logic execute_complete;

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

  always_comb begin
    execute_supported = !decode.illegal &&
                        !decode.ebreak &&
                        (decode.mem_op == MEM_NONE) &&
                        (decode.branch_op == BR_NONE) &&
                        (decode.alu_op != ALU_INVALID);

    instruction_request_valid   = state == STATE_FETCH_REQUEST;
    instruction_request_address = wavefront_pc;
    instruction_response_ready  = state == STATE_FETCH_RESPONSE;

    vector_issue_valid         = (state == STATE_EXECUTE) && execute_supported;
    vector_issue_alu_op        = decode.alu_op;
    vector_issue_rs1           = decode.rs1;
    vector_issue_rs2           = decode.rs2;
    vector_issue_use_immediate = decode.use_immediate;
    vector_issue_immediate     = immediate;
    vector_issue_exec_mask     = wavefront_exec_mask;
    execute_complete           = vector_issue_valid &&
                                 (vector_execute_valid_mask ==
                                  wavefront_exec_mask);

    vector_writeback_enable = (state == STATE_EXECUTE) &&
                              execute_complete &&
                              decode.register_write;
    vector_writeback_rd     = decode.rd;
    vector_writeback_mask   = wavefront_exec_mask;
    vector_writeback_data   = vector_execute_result;

    wavefront_advance_valid     = (state == STATE_EXECUTE) && execute_complete;
    wavefront_advance_pc        = wavefront_pc + 32'd4;
    wavefront_advance_exec_mask = wavefront_exec_mask;
    wavefront_complete_valid    = (state == STATE_COMPLETE) &&
                                  completion_ready;

    completion_valid        = state == STATE_COMPLETE;
    completion_wavefront_id = wavefront_id;
    completion_status       = status;

    retire_valid       = (state == STATE_EXECUTE) && execute_complete;
    retire_pc          = wavefront_pc;
    retire_instruction = instruction;
    retire_rd          = decode.rd;
    retire_write_mask  = decode.register_write ? wavefront_exec_mask : '0;
    retire_data        = vector_execute_result;
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
          end else if (!execute_supported) begin
            status <= COMPLETE_UNSUPPORTED;
            state  <= STATE_COMPLETE;
          end else if (execute_complete) begin
            state <= STATE_FETCH_REQUEST;
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
