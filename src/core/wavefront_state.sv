`timescale 1ns/1ps

module wavefront_state #(
    parameter int LANES = 4,
    parameter int ID_WIDTH = 8
) (
    input  logic                    clk,
    input  logic                    reset_n,

    input  logic                    dispatch_valid,
    output logic                    dispatch_ready,
    input  logic [31:0]             dispatch_pc,
    input  logic [LANES-1:0]        dispatch_exec_mask,
    input  logic [ID_WIDTH-1:0]     dispatch_wavefront_id,

    input  logic                    advance_valid,
    input  logic [31:0]             advance_pc,
    input  logic [LANES-1:0]        advance_exec_mask,
    input  logic                    complete_valid,

    output logic                    valid,
    output logic [31:0]             pc,
    output logic [LANES-1:0]        exec_mask,
    output logic [ID_WIDTH-1:0]     wavefront_id
);

  always_comb begin
    dispatch_ready = !valid;
  end

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      valid        <= 1'b0;
      pc           <= '0;
      exec_mask    <= '0;
      wavefront_id <= '0;
    end else if (complete_valid && valid) begin
      valid     <= 1'b0;
      exec_mask <= '0;
    end else if (dispatch_valid && dispatch_ready) begin
      valid        <= 1'b1;
      pc           <= dispatch_pc;
      exec_mask    <= dispatch_exec_mask;
      wavefront_id <= dispatch_wavefront_id;
    end else if (advance_valid && valid) begin
      pc        <= advance_pc;
      exec_mask <= advance_exec_mask;
    end
  end

endmodule
