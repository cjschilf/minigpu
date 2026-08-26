`timescale 1ns/1ps

module tb_wavefront_state;

  localparam int LANES = 4;
  localparam int ID_WIDTH = 8;

  logic clk;
  logic reset_n;
  logic dispatch_valid, dispatch_ready;
  logic [31:0] dispatch_pc;
  logic [LANES-1:0] dispatch_exec_mask;
  logic [ID_WIDTH-1:0] dispatch_wavefront_id;
  logic advance_valid;
  logic [31:0] advance_pc;
  logic [LANES-1:0] advance_exec_mask;
  logic complete_valid;
  logic valid;
  logic [31:0] pc;
  logic [LANES-1:0] exec_mask;
  logic [ID_WIDTH-1:0] wavefront_id;

  wavefront_state #(
    .LANES(LANES),
    .ID_WIDTH(ID_WIDTH)
  ) dut (
    .clk(clk),
    .reset_n(reset_n),
    .dispatch_valid(dispatch_valid),
    .dispatch_ready(dispatch_ready),
    .dispatch_pc(dispatch_pc),
    .dispatch_exec_mask(dispatch_exec_mask),
    .dispatch_wavefront_id(dispatch_wavefront_id),
    .advance_valid(advance_valid),
    .advance_pc(advance_pc),
    .advance_exec_mask(advance_exec_mask),
    .complete_valid(complete_valid),
    .valid(valid),
    .pc(pc),
    .exec_mask(exec_mask),
    .wavefront_id(wavefront_id)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  initial begin
    reset_n = 1'b0;
    dispatch_valid = 1'b0;
    dispatch_pc = '0;
    dispatch_exec_mask = '0;
    dispatch_wavefront_id = '0;
    advance_valid = 1'b0;
    advance_pc = '0;
    advance_exec_mask = '0;
    complete_valid = 1'b0;

    repeat (2) @(posedge clk);
    reset_n = 1'b1;
    #1;

    if (valid || !dispatch_ready) begin
      $fatal(1, "Wavefront state did not reset idle");
    end

    dispatch_pc = 32'h0000_0100;
    dispatch_exec_mask = 4'b1111;
    dispatch_wavefront_id = 8'h2a;
    dispatch_valid = 1'b1;
    @(posedge clk);
    #1;
    dispatch_valid = 1'b0;

    if (!valid || dispatch_ready || pc != 32'h0000_0100 ||
        exec_mask != 4'b1111 || wavefront_id != 8'h2a) begin
      $fatal(1, "Wavefront dispatch failed");
    end

    advance_pc = 32'h0000_0104;
    advance_exec_mask = 4'b1011;
    advance_valid = 1'b1;
    @(posedge clk);
    #1;
    advance_valid = 1'b0;

    if (pc != 32'h0000_0104 || exec_mask != 4'b1011) begin
      $fatal(1, "Wavefront advance failed");
    end

    complete_valid = 1'b1;
    @(posedge clk);
    #1;
    complete_valid = 1'b0;

    if (valid || !dispatch_ready || exec_mask != '0) begin
      $fatal(1, "Wavefront completion failed");
    end

    $display("Wavefront state regression passed");
    $finish;
  end

endmodule
