`timescale 1ns/1ps

module simd_alu #(
    parameter int LANES = 4,
    parameter int DW = 32
) (
    input  minigpu_pkg::alu_op_e          op,
    input  logic [LANES-1:0]              exec_mask,
    input  logic [LANES-1:0][DW-1:0]      lhs,
    input  logic [LANES-1:0][DW-1:0]      rhs,
    output logic [LANES-1:0][DW-1:0]      result,
    output logic [LANES-1:0]              valid_mask
);

  for (genvar lane = 0; lane < LANES; lane++) begin : gen_lanes
    logic [DW-1:0] lane_result;
    logic          lane_valid;

    alu #(.DW(DW)) lane_alu (
      .op(op),
      .lhs(lhs[lane]),
      .rhs(rhs[lane]),
      .result(lane_result),
      .valid(lane_valid)
    );

    always_comb begin
      result[lane]     = exec_mask[lane] ? lane_result : '0;
      valid_mask[lane] = exec_mask[lane] & lane_valid;
    end
  end

endmodule
