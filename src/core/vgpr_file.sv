`timescale 1ns/1ps

module vgpr_file #(
    parameter int LANES = 4,
    parameter int XLEN = 32,
    parameter int REGS = 32,
    parameter int ADDR_WIDTH = $clog2(REGS)
) (
    input  logic                           clk,
    input  logic                           reset_n,
    input  logic [ADDR_WIDTH-1:0]          rs1_addr,
    input  logic [ADDR_WIDTH-1:0]          rs2_addr,
    output logic [LANES-1:0][XLEN-1:0]     rs1_data,
    output logic [LANES-1:0][XLEN-1:0]     rs2_data,
    input  logic                           write_enable,
    input  logic [LANES-1:0]               write_mask,
    input  logic [ADDR_WIDTH-1:0]          rd_addr,
    input  logic [LANES-1:0][XLEN-1:0]     write_data
);

  logic [XLEN-1:0] registers [LANES][REGS];

  always_comb begin
    for (int lane = 0; lane < LANES; lane++) begin
      rs1_data[lane] = (rs1_addr == '0) ? '0 : registers[lane][rs1_addr];
      rs2_data[lane] = (rs2_addr == '0) ? '0 : registers[lane][rs2_addr];
    end
  end

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      for (int lane = 0; lane < LANES; lane++) begin
        for (int reg_index = 0; reg_index < REGS; reg_index++) begin
          registers[lane][reg_index] <= '0;
        end
      end
    end else if (write_enable && (rd_addr != '0)) begin
      for (int lane = 0; lane < LANES; lane++) begin
        if (write_mask[lane]) begin
          registers[lane][rd_addr] <= write_data[lane];
        end
      end
    end
  end

endmodule
