`timescale 1ns/1ps

module vector_datapath #(
    parameter int LANES = 4,
    parameter int XLEN = 32,
    parameter int REGS = 32,
    parameter int ADDR_WIDTH = $clog2(REGS)
) (
    input  logic                              clk,
    input  logic                              reset_n,

    input  logic                              issue_valid,
    input  minigpu_pkg::alu_op_e              issue_alu_op,
    input  logic [ADDR_WIDTH-1:0]             issue_rs1,
    input  logic [ADDR_WIDTH-1:0]             issue_rs2,
    input  logic                              issue_use_immediate,
    input  logic [XLEN-1:0]                   issue_immediate,
    input  logic [LANES-1:0]                  issue_exec_mask,

    input  logic                              writeback_enable,
    input  logic [ADDR_WIDTH-1:0]             writeback_rd,
    input  logic [LANES-1:0]                  writeback_mask,
    input  logic [LANES-1:0][XLEN-1:0]        writeback_data,

    output logic [LANES-1:0][XLEN-1:0]        execute_result,
    output logic [LANES-1:0]                  execute_valid_mask
);

  logic [LANES-1:0][XLEN-1:0] rs1_data;
  logic [LANES-1:0][XLEN-1:0] rs2_data;
  logic [LANES-1:0][XLEN-1:0] rhs;
  logic [LANES-1:0] alu_valid_mask;

  vgpr_file #(
    .LANES(LANES),
    .XLEN(XLEN),
    .REGS(REGS),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) vgprs (
    .clk(clk),
    .reset_n(reset_n),
    .rs1_addr(issue_rs1),
    .rs2_addr(issue_rs2),
    .rs1_data(rs1_data),
    .rs2_data(rs2_data),
    .write_enable(writeback_enable),
    .write_mask(writeback_mask),
    .rd_addr(writeback_rd),
    .write_data(writeback_data)
  );

  always_comb begin
    for (int lane = 0; lane < LANES; lane++) begin
      rhs[lane] = issue_use_immediate ? issue_immediate : rs2_data[lane];
    end
    execute_valid_mask = issue_valid ? alu_valid_mask : '0;
  end

  simd_alu #(
    .LANES(LANES),
    .DW(XLEN)
  ) vector_alu (
    .op(issue_alu_op),
    .exec_mask(issue_exec_mask),
    .lhs(rs1_data),
    .rhs(rhs),
    .result(execute_result),
    .valid_mask(alu_valid_mask)
  );

endmodule
