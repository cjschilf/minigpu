`timescale 1ns/1ps

module tb_simd_alu;

  localparam int LANES = 4;
  localparam int DW = 32;

  import minigpu_pkg::*;

  alu_op_e op;
  logic [LANES-1:0] exec_mask;
  logic [LANES-1:0][DW-1:0] lhs, rhs, result;
  logic [LANES-1:0] valid_mask;

  simd_alu #(
    .LANES(LANES),
    .DW(DW)
  ) dut (
    .op(op),
    .exec_mask(exec_mask),
    .lhs(lhs),
    .rhs(rhs),
    .result(result),
    .valid_mask(valid_mask)
  );

  initial begin
    op = ALU_ADD;
    exec_mask = 4'b1011;
    for (int lane = 0; lane < LANES; lane++) begin
      lhs[lane] = lane;
      rhs[lane] = 32'd10 + lane;
    end
    #1;

    if (valid_mask != 4'b1011) begin
      $fatal(1, "SIMD valid mask did not follow EXEC");
    end

    for (int lane = 0; lane < LANES; lane++) begin
      if (exec_mask[lane]) begin
        if (result[lane] != (32'd10 + (2 * lane))) begin
          $fatal(1, "Lane %0d ADD failed", lane);
        end
      end else if (result[lane] != '0) begin
        $fatal(1, "Inactive lane %0d produced a result", lane);
      end
    end

    op = ALU_MUL;
    exec_mask = '1;
    #1;
    for (int lane = 0; lane < LANES; lane++) begin
      if (!valid_mask[lane] || result[lane] != lhs[lane] * rhs[lane]) begin
        $fatal(1, "Lane %0d MUL failed", lane);
      end
    end

    op = ALU_INVALID;
    #1;
    if (valid_mask != '0 || result != '0) begin
      $fatal(1, "Invalid SIMD operation was accepted");
    end

    $display("SIMD ALU regression passed");
    $finish;
  end

endmodule
