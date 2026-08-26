`timescale 1ns/1ps

module tb_vector_lsu;

  localparam int LANES = 4;
  localparam int XLEN = 32;

  import minigpu_pkg::*;

  logic clk;
  logic reset_n;
  logic issue_valid, issue_ready;
  mem_op_e issue_mem_op;
  logic [LANES-1:0] issue_mask;
  logic [LANES-1:0][XLEN-1:0] issue_address;
  logic [LANES-1:0][XLEN-1:0] issue_store_data;
  logic memory_request_valid, memory_request_ready, memory_request_write;
  logic [XLEN-1:0] memory_request_address, memory_request_write_data;
  logic [3:0] memory_request_strobe;
  logic memory_response_valid, memory_response_ready;
  logic [XLEN-1:0] memory_response_read_data;
  logic memory_response_error;
  logic done_valid, done_ready;
  logic [LANES-1:0] done_mask;
  logic [LANES-1:0][XLEN-1:0] done_load_data;
  logic done_error, done_misaligned;

  logic [31:0] memory [0:15];
  logic inject_error;
  int cycle_count;
  int request_count;

  vector_lsu #(
    .LANES(LANES),
    .XLEN(XLEN)
  ) dut (
    .clk(clk),
    .reset_n(reset_n),
    .issue_valid(issue_valid),
    .issue_ready(issue_ready),
    .issue_mem_op(issue_mem_op),
    .issue_mask(issue_mask),
    .issue_address(issue_address),
    .issue_store_data(issue_store_data),
    .memory_request_valid(memory_request_valid),
    .memory_request_ready(memory_request_ready),
    .memory_request_write(memory_request_write),
    .memory_request_address(memory_request_address),
    .memory_request_write_data(memory_request_write_data),
    .memory_request_strobe(memory_request_strobe),
    .memory_response_valid(memory_response_valid),
    .memory_response_ready(memory_response_ready),
    .memory_response_read_data(memory_response_read_data),
    .memory_response_error(memory_response_error),
    .done_valid(done_valid),
    .done_ready(done_ready),
    .done_mask(done_mask),
    .done_load_data(done_load_data),
    .done_error(done_error),
    .done_misaligned(done_misaligned)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  initial begin
    #5000;
    $fatal(1,
           "LSU timeout: issue=%b/%b req=%b/%b rsp=%b/%b done=%b/%b count=%0d",
           issue_valid, issue_ready,
           memory_request_valid, memory_request_ready,
           memory_response_valid, memory_response_ready,
           done_valid, done_ready, request_count);
  end

  assign memory_request_ready = cycle_count[0];
  assign memory_response_error = inject_error;

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      cycle_count              <= 0;
      request_count            <= 0;
      memory_response_valid    <= 1'b0;
      memory_response_read_data <= '0;
    end else begin
      cycle_count <= cycle_count + 1;

      if (memory_response_valid && memory_response_ready) begin
        memory_response_valid <= 1'b0;
      end

      if (memory_request_valid && memory_request_ready) begin
        if (memory_request_address > 32'd60 ||
            memory_request_address[1:0] != 2'b00 ||
            memory_request_strobe != 4'b1111) begin
          $fatal(1, "Invalid LSU memory request");
        end

        request_count <= request_count + 1;
        memory_response_valid <= 1'b1;
        memory_response_read_data <= memory[memory_request_address[5:2]];
        if (memory_request_write) begin
          memory[memory_request_address[5:2]] <= memory_request_write_data;
        end
      end
    end
  end

  task automatic issue_operation(
      mem_op_e operation,
      logic [LANES-1:0] mask
  );
    begin
      issue_mem_op = operation;
      issue_mask = mask;
      issue_valid = 1'b1;
      while (!issue_ready) @(negedge clk);
      @(posedge clk);
      #1;
      issue_valid = 1'b0;
    end
  endtask

  task automatic accept_done;
    begin
      while (!done_valid) @(negedge clk);
      done_ready = 1'b1;
      @(posedge clk);
      #1;
      done_ready = 1'b0;
    end
  endtask

  initial begin
    for (int index = 0; index < 16; index++) begin
      memory[index] = '0;
    end
    memory[0] = 32'd10;
    memory[1] = 32'd20;
    memory[2] = 32'd30;
    memory[3] = 32'd40;

    reset_n = 1'b0;
    issue_valid = 1'b0;
    issue_mem_op = MEM_NONE;
    issue_mask = '0;
    issue_address = '0;
    issue_store_data = '0;
    done_ready = 1'b0;
    inject_error = 1'b0;

    repeat (2) @(posedge clk);
    reset_n = 1'b1;

    for (int lane = 0; lane < LANES; lane++) begin
      issue_address[lane] = 4 * lane;
    end
    issue_operation(MEM_LOAD, 4'b1011);
    while (!done_valid) @(posedge clk);

    if (done_error || done_misaligned || done_mask != 4'b1011 ||
        done_load_data[0] != 32'd10 ||
        done_load_data[1] != 32'd20 ||
        done_load_data[2] != 32'd0 ||
        done_load_data[3] != 32'd40 ||
        request_count != 3) begin
      $fatal(1, "Masked vector load failed");
    end
    accept_done();

    for (int lane = 0; lane < LANES; lane++) begin
      issue_address[lane] = 32'd16 + (4 * lane);
      issue_store_data[lane] = 32'd100 + lane;
    end
    issue_operation(MEM_STORE, 4'b0101);
    while (!done_valid) @(posedge clk);

    if (done_error || done_misaligned || request_count != 5 ||
        memory[4] != 32'd100 || memory[5] != 32'd0 ||
        memory[6] != 32'd102 || memory[7] != 32'd0) begin
      $fatal(1, "Masked vector store failed");
    end
    accept_done();

    issue_address = '0;
    issue_address[1] = 32'd3;
    issue_operation(MEM_LOAD, 4'b0010);
    while (!done_valid) @(posedge clk);

    if (!done_misaligned || done_error || request_count != 5) begin
      $fatal(1, "Misaligned operation was not rejected atomically");
    end
    accept_done();

    for (int lane = 0; lane < LANES; lane++) begin
      issue_address[lane] = 4 * lane;
    end
    inject_error = 1'b1;
    issue_operation(MEM_LOAD, 4'b1111);
    while (!done_valid) @(posedge clk);

    if (!done_error || done_misaligned || request_count != 6) begin
      $fatal(1, "Memory response error did not stop the vector operation");
    end
    inject_error = 1'b0;
    accept_done();

    $display("Vector LSU regression passed");
    $finish;
  end

endmodule
