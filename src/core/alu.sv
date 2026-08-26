`timescale 1ns/1ps

module alu #(
    parameter int DW = 32
) (
    input  minigpu_pkg::alu_op_e op,
    input  logic [DW-1:0]        lhs,
    input  logic [DW-1:0]        rhs,
    output logic [DW-1:0]        result,
    output logic                 valid
);

  import minigpu_pkg::*;

  always_comb begin
    result = '0;
    valid  = 1'b1;

    unique case (op)
      ALU_ADD: result = lhs + rhs;
      ALU_SUB: result = lhs - rhs;
      ALU_XOR: result = lhs ^ rhs;
      ALU_OR:  result = lhs | rhs;
      ALU_AND: result = lhs & rhs;
      ALU_MUL: result = lhs * rhs;
      default: valid = 1'b0;
    endcase
  end

endmodule
