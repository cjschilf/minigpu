`timescale 1ns/1ps

module tb_alu;

  localparam int DW = 32;

  import minigpu_pkg::*;

  alu_op_e      op;
  logic [DW-1:0] lhs, rhs;
  logic [DW-1:0] result;
  logic          valid;

  alu #(.DW(DW)) dut (
    .op(op),
    .lhs(lhs),
    .rhs(rhs),
    .result(result),
    .valid(valid)
  );

  initial begin
    $dumpfile("build/alu.vcd");
    $dumpvars(0, tb_alu);
  end

  task automatic do_check(
    string name,
    alu_op_e op_v,
    logic [DW-1:0] a_v,
    logic [DW-1:0] b_v,
    logic [DW-1:0] expected
  );
    begin
      op  = op_v;
      lhs = a_v;
      rhs = b_v;
      #1;

      if (!valid || result !== expected) begin
        $error("[%s] lhs=%08x rhs=%08x op=%0d valid=%b got=%08x expected=%08x",
               name, a_v, b_v, op_v, valid, result, expected);
        $fatal(1);
      end
    end
  endtask

  logic [DW-1:0] a, b;

  initial begin
    do_check("ADD", ALU_ADD, 32'd5,  32'd7,  32'd12);
    do_check("SUB", ALU_SUB, 32'd10, 32'd3,  32'd7);
    do_check("MUL", ALU_MUL, 32'd3,  32'd9,  32'd27);
    do_check("XOR", ALU_XOR, 32'hA5A5_F00F, 32'h0FF0_5A5A,
             32'hA5A5_F00F ^ 32'h0FF0_5A5A);
    do_check("OR",  ALU_OR, 32'h1234_0000, 32'h0000_5678,
             32'h1234_5678);
    do_check("AND", ALU_AND, 32'hFFFF_0000, 32'h00FF_FF00,
             32'h00FF_0000);

    for (int i = 0; i < 100; i++) begin
      a = $urandom();
      b = $urandom();
      do_check("ADD-rand", ALU_ADD, a, b, a + b);
      do_check("SUB-rand", ALU_SUB, a, b, a - b);
      do_check("MUL-rand", ALU_MUL, a, b, a * b);
      do_check("XOR-rand", ALU_XOR, a, b, a ^ b);
      do_check("OR-rand",  ALU_OR, a, b, a | b);
      do_check("AND-rand", ALU_AND, a, b, a & b);
    end

    op  = ALU_INVALID;
    lhs = '1;
    rhs = '1;
    #1;
    if (valid || result !== '0) begin
      $fatal(1, "Invalid ALU operation was accepted");
    end

    $display("ALU regression passed");
    $finish;
  end

endmodule
