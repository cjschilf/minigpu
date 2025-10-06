// tb_alu.sv
`timescale 1ns/1ps

module tb_alu;

  localparam int DW = 32;

  // DUT I/O
  logic [DW-1:0] rs1, rs2;
  logic [2:0]    f3;
  logic [6:0]    f7;
  logic [DW-1:0] rd;

  // Instantiate DUT
  alu #(.dw(DW)) dut (
    .rs1(rs1),
    .rs2(rs2),
    .f3(f3),
    .f7(f7),
    .rd(rd)
  );

  // Optional waveform dump
  initial begin
    $dumpfile("alu.vcd");
    $dumpvars(0, tb);
  end

  // Helper task
  task automatic do_check(string name,
                          logic [2:0] f3_v,
                          logic [6:0] f7_v,
                          logic [DW-1:0] a,
                          logic [DW-1:0] b,
                          logic [DW-1:0] exp);
    begin
      f3  = f3_v;
      f7  = f7_v;
      rs1 = a;
      rs2 = b;
      #1; // allow combinational to settle
      if (rd !== exp) begin
        $error("[%s] Mismatch: rs1=%0d rs2=%0d f3=%b f7=%b got=%0d exp=%0d",
               name, a, b, f3, f7, rd, exp);
        $fatal(1);
      end else begin
        $display("[%s] OK: rs1=%0d rs2=%0d -> %0d", name, a, b, rd);
      end
    end
  endtask

  // Reusable temps for random checks
  logic [DW-1:0] a, b;

  // Tests
  initial begin
    // Directed
    do_check("ADD", 3'b000, 7'b0000000, 32'd5,  32'd7,  32'd12);
    do_check("SUB", 3'b000, 7'b0100000, 32'd10, 32'd3,  32'd7);
    do_check("MUL", 3'b000, 7'b0000001, 32'd3,  32'd9,  32'd27);
    do_check("XOR", 3'b100, 7'b0000000, 32'hA5A5_F00F, 32'h0FF0_5A5A, (32'hA5A5_F00F ^ 32'h0FF0_5A5A));
    do_check("OR ", 3'b110, 7'b0000000, 32'h1234_0000, 32'h0000_5678, 32'h1234_5678);
    do_check("AND", 3'b111, 7'b0000000, 32'hFFFF_0000, 32'h00FF_FF00, 32'h00FF_0000);

    // Random quickchecks
    for (int i = 0; i < 100; i++) begin
      a = $urandom();
      b = $urandom();
      do_check("ADD-rand", 3'b000, 7'b0000000, a, b, a + b);
      do_check("SUB-rand", 3'b000, 7'b0100000, a, b, a - b);
      do_check("MUL-rand", 3'b000, 7'b0000001, a, b, a * b);
      do_check("XOR-rand", 3'b100, 7'b0000000, a, b, a ^ b);
      do_check("OR -rand", 3'b110, 7'b0000000, a, b, a | b);
      do_check("AND-rand", 3'b111, 7'b0000000, a, b, a & b);
    end

    $display("All tests passed ✅");
    $finish;
  end

endmodule
