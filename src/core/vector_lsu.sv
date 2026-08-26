`timescale 1ns/1ps

module vector_lsu #(
    parameter int LANES = 4,
    parameter int XLEN = 32,
    parameter int LANE_WIDTH = (LANES <= 1) ? 1 : $clog2(LANES)
) (
    input  logic                              clk,
    input  logic                              reset_n,

    input  logic                              issue_valid,
    output logic                              issue_ready,
    input  minigpu_pkg::mem_op_e              issue_mem_op,
    input  logic [LANES-1:0]                  issue_mask,
    input  logic [LANES-1:0][XLEN-1:0]        issue_address,
    input  logic [LANES-1:0][XLEN-1:0]        issue_store_data,

    output logic                              memory_request_valid,
    input  logic                              memory_request_ready,
    output logic                              memory_request_write,
    output logic [XLEN-1:0]                   memory_request_address,
    output logic [XLEN-1:0]                   memory_request_write_data,
    output logic [(XLEN/8)-1:0]               memory_request_strobe,

    input  logic                              memory_response_valid,
    output logic                              memory_response_ready,
    input  logic [XLEN-1:0]                   memory_response_read_data,
    input  logic                              memory_response_error,

    output logic                              done_valid,
    input  logic                              done_ready,
    output logic [LANES-1:0]                  done_mask,
    output logic [LANES-1:0][XLEN-1:0]        done_load_data,
    output logic                              done_error,
    output logic                              done_misaligned
);

  import minigpu_pkg::*;

  typedef enum logic [2:0] {
    STATE_IDLE,
    STATE_REQUEST,
    STATE_RESPONSE,
    STATE_COMPLETE
  } state_e;

  state_e state;
  mem_op_e operation;
  logic [LANES-1:0] operation_mask;
  logic [LANES-1:0] pending_mask;
  logic [LANES-1:0][XLEN-1:0] addresses;
  logic [LANES-1:0][XLEN-1:0] store_data;
  logic [LANES-1:0][XLEN-1:0] load_data;
  logic [LANE_WIDTH-1:0] current_lane;
  logic error_reg;
  logic misaligned_reg;
  logic issue_misaligned;
  logic [LANES-1:0] pending_after_response;

  function automatic logic [LANE_WIDTH-1:0] first_active(
      input logic [LANES-1:0] mask
  );
    logic found;
    begin
      first_active = '0;
      found = 1'b0;
      for (int lane = 0; lane < LANES; lane++) begin
        if (mask[lane] && !found) begin
          first_active = LANE_WIDTH'(lane);
          found = 1'b1;
        end
      end
    end
  endfunction

  always_comb begin
    issue_misaligned = 1'b0;
    for (int lane = 0; lane < LANES; lane++) begin
      if (issue_mask[lane] && (issue_address[lane][1:0] != 2'b00)) begin
        issue_misaligned = 1'b1;
      end
    end

    pending_after_response = pending_mask;
    pending_after_response[current_lane] = 1'b0;

    issue_ready = state == STATE_IDLE;

    memory_request_valid      = state == STATE_REQUEST;
    memory_request_write      = operation == MEM_STORE;
    memory_request_address    = addresses[current_lane];
    memory_request_write_data = store_data[current_lane];
    memory_request_strobe     = '1;
    memory_response_ready     = state == STATE_RESPONSE;

    done_valid      = state == STATE_COMPLETE;
    done_mask       = operation_mask;
    done_load_data  = load_data;
    done_error      = error_reg;
    done_misaligned = misaligned_reg;
  end

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      state           <= STATE_IDLE;
      operation       <= MEM_NONE;
      operation_mask  <= '0;
      pending_mask    <= '0;
      addresses       <= '0;
      store_data      <= '0;
      load_data       <= '0;
      current_lane    <= '0;
      error_reg       <= 1'b0;
      misaligned_reg  <= 1'b0;
    end else begin
      unique case (state)
        STATE_IDLE: begin
          if (issue_valid && issue_ready) begin
            operation      <= issue_mem_op;
            operation_mask <= issue_mask;
            pending_mask   <= issue_mask;
            addresses      <= issue_address;
            store_data     <= issue_store_data;
            load_data      <= '0;
            error_reg      <= 1'b0;
            misaligned_reg <= issue_misaligned;
            current_lane   <= first_active(issue_mask);

            if (issue_misaligned || (issue_mask == '0)) begin
              state <= STATE_COMPLETE;
            end else begin
              state <= STATE_REQUEST;
            end
          end
        end

        STATE_REQUEST: begin
          if (memory_request_valid && memory_request_ready) begin
            state <= STATE_RESPONSE;
          end
        end

        STATE_RESPONSE: begin
          if (memory_response_valid && memory_response_ready) begin
            if (memory_response_error) begin
              error_reg <= 1'b1;
              state     <= STATE_COMPLETE;
            end else begin
              if (operation == MEM_LOAD) begin
                load_data[current_lane] <= memory_response_read_data;
              end

              pending_mask <= pending_after_response;
              if (pending_after_response == '0) begin
                state <= STATE_COMPLETE;
              end else begin
                current_lane <= first_active(pending_after_response);
                state        <= STATE_REQUEST;
              end
            end
          end
        end

        STATE_COMPLETE: begin
          if (done_valid && done_ready) begin
            state <= STATE_IDLE;
          end
        end

        default: state <= STATE_IDLE;
      endcase
    end
  end

endmodule
