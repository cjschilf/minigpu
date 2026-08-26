`timescale 1ns/1ps

module tb_memory;

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

  logic [31:0] instruction_memory [0:6];
  logic [31:0] data_memory [0:15];
  int cycle_count;
  int request_count;
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
      logic [4:0] rd,
      logic [6:0] opcode
  );
    return {imm, rs1, funct3, rd, opcode};
  endfunction

  function automatic logic [31:0] encode_s(
      logic signed [11:0] imm,
      logic [4:0] rs2,
      logic [4:0] rs1,
      logic [2:0] funct3
  );
    return {imm[11:5], rs2, rs1, funct3, imm[4:0], 7'b0100011};
  endfunction

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  assign instruction_request_ready = 1'b1;
  assign instruction_response_error = 1'b0;
  assign data_request_ready = cycle_count[0];
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
      cycle_count            <= 0;
      request_count          <= 0;
      data_response_valid    <= 1'b0;
      data_response_read_data <= '0;
    end else begin
      cycle_count <= cycle_count + 1;

      if (data_response_valid && data_response_ready) begin
        data_response_valid <= 1'b0;
      end

      if (data_request_valid && data_request_ready) begin
        if (data_request_address > 32'd60 ||
            data_request_address[1:0] != 2'b00 ||
            data_request_strobe != 4'b1111) begin
          $fatal(1, "Invalid data-memory request");
        end

        request_count <= request_count + 1;
        data_response_valid <= 1'b1;
        data_response_read_data <= data_memory[data_request_address[5:2]];
        if (data_request_write) begin
          data_memory[data_request_address[5:2]] <= data_request_write_data;
        end
      end
    end
  end

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      retire_count <= 0;
      completed    <= 1'b0;
    end else begin
      if (retire_valid) begin
        if (retire_pc != (retire_count * 4) ||
            retire_instruction != instruction_memory[retire_count]) begin
          $fatal(1, "Unexpected memory-kernel retirement");
        end

        unique case (retire_count)
          0: begin
            for (int lane = 0; lane < LANES; lane++) begin
              if (retire_data[lane] != lane) $fatal(1, "LANEID failed");
            end
          end
          1: begin
            for (int lane = 0; lane < LANES; lane++) begin
              if (retire_data[lane] != 32'd4) $fatal(1, "ADDI failed");
            end
          end
          2: begin
            for (int lane = 0; lane < LANES; lane++) begin
              if (retire_data[lane] != 4 * lane) $fatal(1, "MUL failed");
            end
          end
          3: begin
            for (int lane = 0; lane < LANES; lane++) begin
              if (retire_data[lane] != 10 * (lane + 1)) $fatal(1, "LW failed");
            end
          end
          4: begin
            for (int lane = 0; lane < LANES; lane++) begin
              if (retire_data[lane] != (10 * (lane + 1)) + 1) begin
                $fatal(1, "Post-load ADDI failed");
              end
            end
          end
          5: begin
            if (retire_write_mask != '0) $fatal(1, "SW wrote a VGPR");
          end
          default: $fatal(1, "Too many retired instructions");
        endcase

        if (retire_count < 5 &&
            (retire_rd == '0 || retire_write_mask != {LANES{1'b1}})) begin
          $fatal(1, "Expected masked VGPR writeback");
        end
        retire_count <= retire_count + 1;
      end

      if (completion_valid && completion_ready) begin
        if (completion_wavefront_id != 8'h33 ||
            completion_status != COMPLETE_SUCCESS) begin
          $fatal(1, "Memory kernel completed with an error");
        end
        completed <= 1'b1;
      end
    end
  end

  initial begin
    instruction_memory[0] = encode_lane_id(5'd1);
    instruction_memory[1] =
      encode_i(12'sd4, 5'd0, 3'b000, 5'd2, 7'b0010011);
    instruction_memory[2] =
      encode_r(7'b0000001, 5'd2, 5'd1, 3'b000, 5'd1);
    instruction_memory[3] =
      encode_i(12'sd0, 5'd1, 3'b010, 5'd3, 7'b0000011);
    instruction_memory[4] =
      encode_i(12'sd1, 5'd3, 3'b000, 5'd3, 7'b0010011);
    instruction_memory[5] = encode_s(12'sd16, 5'd3, 5'd1, 3'b010);
    instruction_memory[6] = 32'h0010_0073;

    for (int index = 0; index < 16; index++) begin
      data_memory[index] = '0;
    end
    data_memory[0] = 32'd10;
    data_memory[1] = 32'd20;
    data_memory[2] = 32'd30;
    data_memory[3] = 32'd40;

    reset_n = 1'b0;
    dispatch_valid = 1'b0;
    dispatch_pc = '0;
    dispatch_exec_mask = '1;
    dispatch_wavefront_id = 8'h33;

    repeat (2) @(posedge clk);
    reset_n = 1'b1;
    #1;

    if (!dispatch_ready) begin
      $fatal(1, "Compute unit was not ready for memory kernel");
    end

    dispatch_valid = 1'b1;
    @(posedge clk);
    #1;
    dispatch_valid = 1'b0;

    for (int cycle = 0; cycle < 300 && !completed; cycle++) begin
      @(posedge clk);
    end

    if (!completed || retire_count != 6 || request_count != 8 ||
        data_memory[4] != 32'd11 || data_memory[5] != 32'd21 ||
        data_memory[6] != 32'd31 || data_memory[7] != 32'd41) begin
      $fatal(1, "Memory kernel produced incorrect results");
    end

    $display("Memory regression passed");
    $finish;
  end

endmodule
