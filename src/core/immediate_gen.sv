`timescale 1ns/1ps

module immediate_gen (
    input  logic [11:0]             instruction_31_20,
    input  logic [4:0]              instruction_11_7,
    input  minigpu_pkg::imm_sel_e   select,
    output logic [31:0]             immediate
);

  import minigpu_pkg::*;

  always_comb begin
    unique case (select)
      IMM_I:    immediate = {{20{instruction_31_20[11]}}, instruction_31_20};
      IMM_S:    immediate = {{20{instruction_31_20[11]}},
                             instruction_31_20[11:5],
                             instruction_11_7};
      IMM_B:    immediate = {{19{instruction_31_20[11]}},
                             instruction_31_20[11],
                             instruction_11_7[0],
                             instruction_31_20[10:5],
                             instruction_11_7[4:1], 1'b0};
      default:  immediate = '0;
    endcase
  end

endmodule
