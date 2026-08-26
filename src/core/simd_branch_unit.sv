`timescale 1ns/1ps

module simd_branch_unit #(
    parameter int LANES = 4,
    parameter int DW = 32
) (
    input  minigpu_pkg::branch_op_e       op,
    input  logic [LANES-1:0]              exec_mask,
    input  logic [LANES-1:0][DW-1:0]      lhs,
    input  logic [LANES-1:0][DW-1:0]      rhs,
    output logic [LANES-1:0]              taken_mask,
    output logic [LANES-1:0]              valid_mask
);

  for (genvar lane = 0; lane < LANES; lane++) begin : gen_lanes
    logic lane_taken;
    logic lane_valid;

    branch_unit #(.DW(DW)) lane_branch (
      .op(op),
      .lhs(lhs[lane]),
      .rhs(rhs[lane]),
      .taken(lane_taken),
      .valid(lane_valid)
    );

    always_comb begin
      taken_mask[lane] = exec_mask[lane] & lane_taken;
      valid_mask[lane] = exec_mask[lane] & lane_valid;
    end
  end

endmodule
