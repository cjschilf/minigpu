`timescale 1ns/1ps

module tb_lane_id;

  localparam int LANES = 4;
  localparam int XLEN = 32;
  localparam int ID_WIDTH = 8;

  import minigpu_pkg::*;

  logic clk;
  logic reset_n;
  logic dispatch_valid, dispatch_ready;
  logic [31:0] dispatch_pc;
  logic [LANES-1:0] dispatch_exec_mask;
  logic [ID_WIDTH-1:0] dispatch_wavefront_id;
  logic instruction_request_valid, instruction_request_ready;
  logic [31:0] instruction_request_address;
  logic instruction_response_valid, instruction_response_ready;
  logic [31:0] instruction_response_data;
  logic instruction_response_error;
  logic data_request_valid, data_request_ready, data_request_write;
  logic [31:0] data_request_address, data_request_write_data;
  logic [3:0] data_request_strobe;
  logic data_response_valid, data_response_ready;
  logic [31:0] data_response_read_data;
  logic data_response_error;
  logic completion_valid, completion_ready;
  logic [ID_WIDTH-1:0] completion_wavefront_id;
  completion_status_e completion_status;
  logic retire_valid;
  logic [31:0] retire_pc, retire_instruction;
  logic [4:0] retire_rd;
  logic [LANES-1:0] retire_write_mask;
  logic [LANES-1:0][XLEN-1:0] retire_data;

  logic [31:0] instruction_memory [0:1];
  logic lane_id_retired;
  logic divergence_completed;

  compute_unit #(
    .LANES(LANES),
    .XLEN(XLEN),
    .ID_WIDTH(ID_WIDTH)
  ) dut (
    .clk(clk),
    .reset_n(reset_n),
    .dispatch_valid(dispatch_valid),
    .dispatch_ready(dispatch_ready),
    .dispatch_pc(dispatch_pc),
    .dispatch_exec_mask(dispatch_exec_mask),
    .dispatch_wavefront_id(dispatch_wavefront_id),
    .instruction_request_valid(instruction_request_valid),
    .instruction_request_ready(instruction_request_ready),
    .instruction_request_address(instruction_request_address),
    .instruction_response_valid(instruction_response_valid),
    .instruction_response_ready(instruction_response_ready),
    .instruction_response_data(instruction_response_data),
    .instruction_response_error(instruction_response_error),
    .data_request_valid(data_request_valid),
    .data_request_ready(data_request_ready),
    .data_request_write(data_request_write),
    .data_request_address(data_request_address),
    .data_request_write_data(data_request_write_data),
    .data_request_strobe(data_request_strobe),
    .data_response_valid(data_response_valid),
    .data_response_ready(data_response_ready),
    .data_response_read_data(data_response_read_data),
    .data_response_error(data_response_error),
    .completion_valid(completion_valid),
    .completion_ready(completion_ready),
    .completion_wavefront_id(completion_wavefront_id),
    .completion_status(completion_status),
    .retire_valid(retire_valid),
    .retire_pc(retire_pc),
    .retire_instruction(retire_instruction),
    .retire_rd(retire_rd),
    .retire_write_mask(retire_write_mask),
    .retire_data(retire_data)
  );

  function automatic logic [31:0] encode_lane_id(logic [4:0] rd);
    return {20'b0, rd, 7'b0001011};
  endfunction

  function automatic logic [31:0] encode_b(
      logic signed [12:0] imm,
      logic [4:0] rs2,
      logic [4:0] rs1,
      logic [2:0] funct3
  );
    if (imm[0]) begin
      return 'x;
    end else begin
      return {imm[12], imm[10:5], rs2, rs1, funct3,
              imm[4:1], imm[11], 7'b1100011};
    end
  endfunction

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  assign instruction_request_ready = 1'b1;
  assign instruction_response_error = 1'b0;
  assign data_request_ready = 1'b1;
  assign data_response_valid = 1'b0;
  assign data_response_read_data = '0;
  assign data_response_error = 1'b0;
  assign completion_ready = 1'b1;

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      instruction_response_valid <= 1'b0;
      instruction_response_data  <= '0;
    end else begin
      if (instruction_response_valid && instruction_response_ready) begin
        instruction_response_valid <= 1'b0;
      end

      if (instruction_request_valid && instruction_request_ready) begin
        instruction_response_valid <= 1'b1;
        unique case (instruction_request_address)
          32'h0000_0000: instruction_response_data <= instruction_memory[0];
          32'h0000_0004: instruction_response_data <= instruction_memory[1];
          default:       instruction_response_data <= 32'hffff_ffff;
        endcase
      end
    end
  end

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      lane_id_retired      <= 1'b0;
      divergence_completed <= 1'b0;
    end else begin
      if (data_request_valid || data_response_ready) begin
        $fatal(1, "Unexpected data request: write=%b addr=%08x data=%08x strb=%b",
               data_request_write, data_request_address,
               data_request_write_data, data_request_strobe);
      end

      if (retire_valid) begin
        if (lane_id_retired || retire_pc != 32'h0 ||
            retire_instruction != instruction_memory[0] ||
            retire_rd != 5'd1 ||
            retire_write_mask != {LANES{1'b1}}) begin
          $fatal(1, "Unexpected LANEID retirement");
        end

        for (int lane = 0; lane < LANES; lane++) begin
          if (retire_data[lane] != lane) begin
            $fatal(1, "Lane %0d returned the wrong static ID", lane);
          end
        end
        lane_id_retired <= 1'b1;
      end

      if (completion_valid && completion_ready) begin
        if (completion_wavefront_id != 8'h55 ||
            completion_status != COMPLETE_DIVERGENCE) begin
          $fatal(1, "Expected divergence completion");
        end
        divergence_completed <= 1'b1;
      end
    end
  end

  initial begin
    instruction_memory[0] = encode_lane_id(5'd1);
    instruction_memory[1] = encode_b(13'sd8, 5'd0, 5'd1, 3'b000);

    reset_n = 1'b0;
    dispatch_valid = 1'b0;
    dispatch_pc = '0;
    dispatch_exec_mask = '1;
    dispatch_wavefront_id = 8'h55;

    repeat (2) @(posedge clk);
    reset_n = 1'b1;
    #1;

    dispatch_valid = 1'b1;
    @(posedge clk);
    #1;
    dispatch_valid = 1'b0;

    for (int cycle = 0;
         cycle < 100 && !divergence_completed;
         cycle++) begin
      @(posedge clk);
    end

    if (!lane_id_retired || !divergence_completed || !dispatch_ready) begin
      $fatal(1, "Lane-ID divergence kernel did not complete correctly");
    end

    $display("Lane-ID regression passed");
    $finish;
  end

endmodule
