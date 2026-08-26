`timescale 1ns/1ps

module tb_vgpr_file;

  localparam int LANES = 4;
  localparam int XLEN = 32;

  logic clk;
  logic reset_n;
  logic [4:0] rs1_addr, rs2_addr, rd_addr;
  logic [LANES-1:0][XLEN-1:0] rs1_data, rs2_data, write_data;
  logic write_enable;
  logic [LANES-1:0] write_mask;

  vgpr_file #(
    .LANES(LANES),
    .XLEN(XLEN)
  ) dut (
    .clk(clk),
    .reset_n(reset_n),
    .rs1_addr(rs1_addr),
    .rs2_addr(rs2_addr),
    .rs1_data(rs1_data),
    .rs2_data(rs2_data),
    .write_enable(write_enable),
    .write_mask(write_mask),
    .rd_addr(rd_addr),
    .write_data(write_data)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  task automatic commit_write;
    begin
      @(posedge clk);
      #1;
      write_enable = 1'b0;
    end
  endtask

  initial begin
    reset_n = 1'b0;
    rs1_addr = '0;
    rs2_addr = '0;
    rd_addr = '0;
    write_enable = 1'b0;
    write_mask = '0;
    write_data = '0;

    repeat (2) @(posedge clk);
    reset_n = 1'b1;

    rd_addr = 5'd5;
    write_enable = 1'b1;
    write_mask = '1;
    for (int lane = 0; lane < LANES; lane++) begin
      write_data[lane] = 32'h1000 + lane;
    end
    commit_write();

    rs1_addr = 5'd5;
    #1;
    for (int lane = 0; lane < LANES; lane++) begin
      if (rs1_data[lane] != 32'h1000 + lane) begin
        $fatal(1, "VGPR lane %0d initial write failed", lane);
      end
    end

    rd_addr = 5'd5;
    write_enable = 1'b1;
    write_mask = 4'b0101;
    for (int lane = 0; lane < LANES; lane++) begin
      write_data[lane] = 32'h2000 + lane;
    end
    commit_write();

    for (int lane = 0; lane < LANES; lane++) begin
      logic [31:0] expected;
      expected = write_mask[lane] ? 32'h2000 + lane : 32'h1000 + lane;
      if (rs1_data[lane] != expected) begin
        $fatal(1, "VGPR lane %0d masked write failed", lane);
      end
    end

    rd_addr = 5'd0;
    write_enable = 1'b1;
    write_mask = '1;
    write_data = '1;
    commit_write();

    rs1_addr = 5'd0;
    rs2_addr = 5'd0;
    #1;
    if (rs1_data != '0 || rs2_data != '0) begin
      $fatal(1, "VGPR x0 is not hardwired to zero");
    end

    $display("VGPR regression passed");
    $finish;
  end

endmodule
