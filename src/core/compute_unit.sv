`timescale 1ns/1ps

module compute_unit #(
    parameter int LANES = 4,
    parameter int XLEN = 32,
    parameter int ID_WIDTH = 8
) (
    input  logic                                  clk,
    input  logic                                  reset_n,

    input  logic                                  dispatch_valid,
    output logic                                  dispatch_ready,
    input  logic [31:0]                           dispatch_pc,
    input  logic [LANES-1:0]                      dispatch_exec_mask,
    input  logic [ID_WIDTH-1:0]                   dispatch_wavefront_id,

    output logic                                  instruction_request_valid,
    input  logic                                  instruction_request_ready,
    output logic [31:0]                           instruction_request_address,
    input  logic                                  instruction_response_valid,
    output logic                                  instruction_response_ready,
    input  logic [31:0]                           instruction_response_data,
    input  logic                                  instruction_response_error,

    output logic                                  completion_valid,
    input  logic                                  completion_ready,
    output logic [ID_WIDTH-1:0]                   completion_wavefront_id,
    output minigpu_pkg::completion_status_e       completion_status,

    output logic                                  retire_valid,
    output logic [31:0]                           retire_pc,
    output logic [31:0]                           retire_instruction,
    output logic [4:0]                            retire_rd,
    output logic [LANES-1:0]                      retire_write_mask,
    output logic [LANES-1:0][XLEN-1:0]            retire_data
);

  logic wavefront_valid;
  logic [31:0] wavefront_pc;
  logic [LANES-1:0] wavefront_exec_mask;
  logic [ID_WIDTH-1:0] wavefront_id;
  logic wavefront_advance_valid;
  logic [31:0] wavefront_advance_pc;
  logic [LANES-1:0] wavefront_advance_exec_mask;
  logic wavefront_complete_valid;

  logic vector_issue_valid;
  minigpu_pkg::alu_op_e vector_issue_alu_op;
  logic [4:0] vector_issue_rs1;
  logic [4:0] vector_issue_rs2;
  logic vector_issue_use_immediate;
  logic [XLEN-1:0] vector_issue_immediate;
  logic [LANES-1:0] vector_issue_exec_mask;
  logic [LANES-1:0][XLEN-1:0] vector_execute_result;
  logic [LANES-1:0] vector_execute_valid_mask;

  logic vector_writeback_enable;
  logic [4:0] vector_writeback_rd;
  logic [LANES-1:0] vector_writeback_mask;
  logic [LANES-1:0][XLEN-1:0] vector_writeback_data;

  wavefront_state #(
    .LANES(LANES),
    .ID_WIDTH(ID_WIDTH)
  ) state (
    .clk(clk),
    .reset_n(reset_n),
    .dispatch_valid(dispatch_valid),
    .dispatch_ready(dispatch_ready),
    .dispatch_pc(dispatch_pc),
    .dispatch_exec_mask(dispatch_exec_mask),
    .dispatch_wavefront_id(dispatch_wavefront_id),
    .advance_valid(wavefront_advance_valid),
    .advance_pc(wavefront_advance_pc),
    .advance_exec_mask(wavefront_advance_exec_mask),
    .complete_valid(wavefront_complete_valid),
    .valid(wavefront_valid),
    .pc(wavefront_pc),
    .exec_mask(wavefront_exec_mask),
    .wavefront_id(wavefront_id)
  );

  wavefront_controller #(
    .LANES(LANES),
    .XLEN(XLEN),
    .ID_WIDTH(ID_WIDTH)
  ) controller (
    .clk(clk),
    .reset_n(reset_n),
    .wavefront_valid(wavefront_valid),
    .wavefront_pc(wavefront_pc),
    .wavefront_exec_mask(wavefront_exec_mask),
    .wavefront_id(wavefront_id),
    .instruction_request_valid(instruction_request_valid),
    .instruction_request_ready(instruction_request_ready),
    .instruction_request_address(instruction_request_address),
    .instruction_response_valid(instruction_response_valid),
    .instruction_response_ready(instruction_response_ready),
    .instruction_response_data(instruction_response_data),
    .instruction_response_error(instruction_response_error),
    .vector_issue_valid(vector_issue_valid),
    .vector_issue_alu_op(vector_issue_alu_op),
    .vector_issue_rs1(vector_issue_rs1),
    .vector_issue_rs2(vector_issue_rs2),
    .vector_issue_use_immediate(vector_issue_use_immediate),
    .vector_issue_immediate(vector_issue_immediate),
    .vector_issue_exec_mask(vector_issue_exec_mask),
    .vector_execute_result(vector_execute_result),
    .vector_execute_valid_mask(vector_execute_valid_mask),
    .vector_writeback_enable(vector_writeback_enable),
    .vector_writeback_rd(vector_writeback_rd),
    .vector_writeback_mask(vector_writeback_mask),
    .vector_writeback_data(vector_writeback_data),
    .wavefront_advance_valid(wavefront_advance_valid),
    .wavefront_advance_pc(wavefront_advance_pc),
    .wavefront_advance_exec_mask(wavefront_advance_exec_mask),
    .wavefront_complete_valid(wavefront_complete_valid),
    .completion_valid(completion_valid),
    .completion_ready(completion_ready),
    .completion_wavefront_id(completion_wavefront_id),
    .completion_status(completion_status),
    .retire_valid(retire_valid),
    .retire_pc(retire_pc),
    .retire_instruction(retire_instruction),
    .retire_rd(retire_rd),
    .retire_write_mask(retire_write_mask),
    .retire_data(retire_data)
  );

  vector_datapath #(
    .LANES(LANES),
    .XLEN(XLEN)
  ) vector_unit (
    .clk(clk),
    .reset_n(reset_n),
    .issue_valid(vector_issue_valid),
    .issue_alu_op(vector_issue_alu_op),
    .issue_rs1(vector_issue_rs1),
    .issue_rs2(vector_issue_rs2),
    .issue_use_immediate(vector_issue_use_immediate),
    .issue_immediate(vector_issue_immediate),
    .issue_exec_mask(vector_issue_exec_mask),
    .writeback_enable(vector_writeback_enable),
    .writeback_rd(vector_writeback_rd),
    .writeback_mask(vector_writeback_mask),
    .writeback_data(vector_writeback_data),
    .execute_result(vector_execute_result),
    .execute_valid_mask(vector_execute_valid_mask)
  );

endmodule
