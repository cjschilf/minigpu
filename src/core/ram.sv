// it should be an array of memory that can be arbitrarily resized, so like N elements each M bits (we will use it as like 1024 x 1 byte)
// write port to feed new data, write address to say where its going, write enable signal to signal when we want to write, so that if enabled that data will be written to the array at N position
// read port to get out an element, read address to say where we are reading, read enable to signal when we want to read, so if enabled we will receive data from the array at N position
// reset_n port that when set low wipes the memory
// writes should be clocked but reads shouldn't be for now
//
// need these not to be hardcoded and be an interface
typedef struct packed {
  logic [3:0] addr;
  logic [7:0] data;
} Packet_t;

module ram_struct #(
    parameter ADDR_WIDTH = 4,
    DATA_WIDTH = 8
) (
    input clk,
    input Packet_t din,
    output Packet_t dout,
    input we,
    input re,
    input reset_n
);

  // idk if this is the right way to do this :)
  logic [DATA_WIDTH - 1] mem[2**ADDR_WIDTH - 1:0];

  // write in data if not resetting
  always_ff @(posedge clk) begin
    if (!reset_n) begin
      dout <= '0;
    end else begin
      if (we) begin
        mem[din.addr] <= din.data;
      end
      dout <= '{addr: mem[din.addr], data: din.data};
    end
  end

  //
  always_ff @(posedge clk) begin
    if (!reset_n) dout <= '0;
    else mem[din.addr] <= din.data;
    dout <= '{addr: mem[din.addr], data: din.data};
  end

  always_comb begin
    if (re) dout = mem[din.addr];
    else dout = '0;
  end

endmodule

