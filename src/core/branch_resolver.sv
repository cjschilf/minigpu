`timescale 1ns/1ps

module branch_resolver #(
    parameter int LANES = 4
) (
    input  logic [LANES-1:0] exec_mask,
    input  logic [LANES-1:0] taken_mask,
    output logic             all_taken,
    output logic             divergent
);

  logic [LANES-1:0] active_taken;

  always_comb begin
    active_taken = taken_mask & exec_mask;
    all_taken = (exec_mask != '0) && (active_taken == exec_mask);
    divergent = !all_taken && (active_taken != '0);
  end

endmodule
