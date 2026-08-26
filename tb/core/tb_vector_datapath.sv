`timescale 1ns/1ps

module tb_vector_datapath;

  localparam int LANES = 4;
  localparam int XLEN = 32;

  import minigpu_pkg::*;

  logic clk;
  logic reset_n;
  logic issue_valid;
  alu_op_e issue_alu_op;
  logic [4:0] issue_rs1, issue_rs2;
  logic issue_use_immediate;
  logic [XLEN-1:0] issue_immediate;
  logic [LANES-1:0] issue_exec_mask;
  logic writeback_enable;
  logic [4:0] writeback_rd;
  logic [LANES-1:0] writeback_mask;
  logic [LANES-1:0][XLEN-1:0] writeback_data;
  logic [LANES-1:0][XLEN-1:0] execute_result;
  logic [LANES-1:0] execute_valid_mask;

  vector_datapath #(
    .LANES(LANES),
    .XLEN(XLEN)
  ) dut (
    .clk(clk),
    .reset_n(reset_n),
    .issue_valid(issue_valid),
    .issue_alu_op(issue_alu_op),
    .issue_rs1(issue_rs1),
    .issue_rs2(issue_rs2),
    .issue_use_immediate(issue_use_immediate),
    .issue_immediate(issue_immediate),
    .issue_exec_mask(issue_exec_mask),
    .writeback_enable(writeback_enable),
    .writeback_rd(writeback_rd),
    .writeback_mask(writeback_mask),
    .writeback_data(writeback_data),
    .execute_result(execute_result),
    .execute_valid_mask(execute_valid_mask)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  task automatic write_vgpr(
      logic [4:0] rd,
      logic [31:0] base
  );
    begin
      writeback_rd = rd;
      writeback_mask = '1;
      for (int lane = 0; lane < LANES; lane++) begin
        writeback_data[lane] = base + lane;
      end
      writeback_enable = 1'b1;
      @(posedge clk);
      #1;
      writeback_enable = 1'b0;
    end
  endtask

  initial begin
    reset_n = 1'b0;
    issue_valid = 1'b0;
    issue_alu_op = ALU_INVALID;
    issue_rs1 = '0;
    issue_rs2 = '0;
    issue_use_immediate = 1'b0;
    issue_immediate = '0;
    issue_exec_mask = '0;
    writeback_enable = 1'b0;
    writeback_rd = '0;
    writeback_mask = '0;
    writeback_data = '0;

    repeat (2) @(posedge clk);
    reset_n = 1'b1;

    write_vgpr(5'd1, 32'd10);
    write_vgpr(5'd2, 32'd20);

    issue_valid = 1'b1;
    issue_alu_op = ALU_ADD;
    issue_rs1 = 5'd1;
    issue_rs2 = 5'd2;
    issue_use_immediate = 1'b0;
    issue_exec_mask = '1;
    #1;

    if (execute_valid_mask != '1) begin
      $fatal(1, "Vector register ADD was not valid");
    end
    for (int lane = 0; lane < LANES; lane++) begin
      if (execute_result[lane] != 32'd30 + (2 * lane)) begin
        $fatal(1, "Vector datapath register operation failed on lane %0d", lane);
      end
    end

    issue_use_immediate = 1'b1;
    issue_immediate = 32'hffff_ffff;
    issue_exec_mask = 4'b1011;
    #1;

    if (execute_valid_mask != 4'b1011) begin
      $fatal(1, "Vector datapath EXEC mask failed");
    end
    for (int lane = 0; lane < LANES; lane++) begin
      if (issue_exec_mask[lane]) begin
        if (execute_result[lane] != 32'd9 + lane) begin
          $fatal(1, "Vector immediate operation failed on lane %0d", lane);
        end
      end else if (execute_result[lane] != '0) begin
        $fatal(1, "Inactive vector lane produced a result");
      end
    end

    issue_valid = 1'b0;
    #1;
    if (execute_valid_mask != '0) begin
      $fatal(1, "Invalid issue produced a valid result");
    end

    $display("Vector datapath regression passed");
    $finish;
  end

endmodule
