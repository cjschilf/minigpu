`timescale 1ns/1ps

module tb_compute_unit;

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
  logic completion_valid, completion_ready;
  logic [ID_WIDTH-1:0] completion_wavefront_id;
  completion_status_e completion_status;
  logic retire_valid;
  logic [31:0] retire_pc, retire_instruction;
  logic [4:0] retire_rd;
  logic [LANES-1:0] retire_write_mask;
  logic [LANES-1:0][XLEN-1:0] retire_data;

  logic [31:0] instruction_memory [0:6];
  int retire_count;
  logic completed;

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

  function automatic logic [31:0] encode_r(
      logic [6:0] funct7,
      logic [4:0] rs2,
      logic [4:0] rs1,
      logic [2:0] funct3,
      logic [4:0] rd
  );
    return {funct7, rs2, rs1, funct3, rd, 7'b0110011};
  endfunction

  function automatic logic [31:0] encode_i(
      logic signed [11:0] imm,
      logic [4:0] rs1,
      logic [2:0] funct3,
      logic [4:0] rd
  );
    return {imm, rs1, funct3, rd, 7'b0010011};
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
          32'h0000_0008: instruction_response_data <= instruction_memory[2];
          32'h0000_000c: instruction_response_data <= instruction_memory[3];
          32'h0000_0010: instruction_response_data <= instruction_memory[4];
          32'h0000_0014: instruction_response_data <= instruction_memory[5];
          32'h0000_0018: instruction_response_data <= instruction_memory[6];
          default:       instruction_response_data <= 32'hffff_ffff;
        endcase
      end
    end
  end

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      retire_count <= 0;
      completed    <= 1'b0;
    end else begin
      if (retire_valid) begin
        unique case (retire_count)
          0: begin
            if (retire_pc != 32'h0 ||
                retire_instruction != instruction_memory[0] ||
                retire_write_mask != {LANES{1'b1}}) begin
              $fatal(1, "Unexpected first ADDI retirement");
            end
            if (retire_rd != 5'd1) $fatal(1, "Expected x1 write");
            for (int lane = 0; lane < LANES; lane++) begin
              if (retire_data[lane] != 32'd5) $fatal(1, "ADDI x1 failed");
            end
          end
          1: begin
            if (retire_pc != 32'h4 ||
                retire_instruction != instruction_memory[1] ||
                retire_write_mask != '0) begin
              $fatal(1, "Taken branch retirement failed");
            end
          end
          2: begin
            if (retire_pc != 32'hc ||
                retire_instruction != instruction_memory[3] ||
                retire_write_mask != {LANES{1'b1}}) begin
              $fatal(1, "Unexpected second ADDI retirement");
            end
            if (retire_rd != 5'd2) $fatal(1, "Expected x2 write");
            for (int lane = 0; lane < LANES; lane++) begin
              if (retire_data[lane] != 32'd12) $fatal(1, "ADDI x2 failed");
            end
          end
          3: begin
            if (retire_pc != 32'h10 ||
                retire_instruction != instruction_memory[4] ||
                retire_write_mask != '0) begin
              $fatal(1, "Not-taken branch retirement failed");
            end
          end
          4: begin
            if (retire_pc != 32'h14 ||
                retire_instruction != instruction_memory[5] ||
                retire_write_mask != {LANES{1'b1}}) begin
              $fatal(1, "Unexpected ADD retirement");
            end
            if (retire_rd != 5'd3) $fatal(1, "Expected x3 write");
            for (int lane = 0; lane < LANES; lane++) begin
              if (retire_data[lane] != 32'd17) $fatal(1, "ADD x3 failed");
            end
          end
          default: $fatal(1, "Too many retired instructions");
        endcase

        retire_count <= retire_count + 1;
      end

      if (completion_valid && completion_ready) begin
        if (completion_wavefront_id != 8'h2a ||
            completion_status != COMPLETE_SUCCESS) begin
          $fatal(1, "Unexpected completion result");
        end
        completed <= 1'b1;
      end
    end
  end

  initial begin
    instruction_memory[0] = encode_i(12'sd5, 5'd0, 3'b000, 5'd1);
    instruction_memory[1] = encode_b(13'sd8, 5'd1, 5'd1, 3'b000);
    instruction_memory[2] = encode_i(12'sd99, 5'd0, 3'b000, 5'd2);
    instruction_memory[3] = encode_i(12'sd7, 5'd1, 3'b000, 5'd2);
    instruction_memory[4] = encode_b(13'sd8, 5'd1, 5'd1, 3'b001);
    instruction_memory[5] =
      encode_r(7'b0000000, 5'd2, 5'd1, 3'b000, 5'd3);
    instruction_memory[6] = 32'h0010_0073;

    reset_n = 1'b0;
    dispatch_valid = 1'b0;
    dispatch_pc = '0;
    dispatch_exec_mask = '1;
    dispatch_wavefront_id = 8'h2a;

    repeat (2) @(posedge clk);
    reset_n = 1'b1;
    #1;

    if (!dispatch_ready) begin
      $fatal(1, "Compute unit was not ready for dispatch");
    end

    dispatch_valid = 1'b1;
    @(posedge clk);
    #1;
    dispatch_valid = 1'b0;

    for (int cycle = 0; cycle < 100 && !completed; cycle++) begin
      @(posedge clk);
    end

    if (!completed || retire_count != 5) begin
      $fatal(1, "Compute unit did not complete the kernel");
    end

    $display("Compute unit regression passed");
    $finish;
  end

endmodule
