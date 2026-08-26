`timescale 1ns/1ps

module branch_unit #(
    parameter int DW = 32
) (
    input  minigpu_pkg::branch_op_e op,
    input  logic [DW-1:0]           lhs,
    input  logic [DW-1:0]           rhs,
    output logic                    taken,
    output logic                    valid
);

  import minigpu_pkg::*;

  always_comb begin
    taken = 1'b0;
    valid = 1'b1;

    unique case (op)
      BR_EQ:  taken = lhs == rhs;
      BR_NE:  taken = lhs != rhs;
      BR_LT:  taken = $signed(lhs) < $signed(rhs);
      BR_GE:  taken = $signed(lhs) >= $signed(rhs);
      BR_LTU: taken = lhs < rhs;
      BR_GEU: taken = lhs >= rhs;
      default: valid = 1'b0;
    endcase
  end

endmodule
