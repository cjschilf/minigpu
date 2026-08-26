`timescale 1ns/1ps

module tb_decode;

  import minigpu_pkg::*;

  logic [31:0] instruction;
  decode_ctrl_t control;
  logic [31:0] immediate;

  branch_op_e branch_op;
  logic [31:0] branch_lhs, branch_rhs;
  logic branch_taken, branch_valid;

  instruction_decoder decoder (
    .instruction(instruction),
    .control(control)
  );

  immediate_gen immediate_decoder (
    .instruction_31_20(instruction[31:20]),
    .instruction_11_7(instruction[11:7]),
    .select(control.imm_sel),
    .immediate(immediate)
  );

  branch_unit branch_compare (
    .op(branch_op),
    .lhs(branch_lhs),
    .rhs(branch_rhs),
    .taken(branch_taken),
    .valid(branch_valid)
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

  task automatic check_branch(
      branch_op_e op,
      logic [31:0] lhs,
      logic [31:0] rhs,
      logic expected
  );
    begin
      branch_op  = op;
      branch_lhs = lhs;
      branch_rhs = rhs;
      #1;
      if (!branch_valid || branch_taken !== expected) begin
        $fatal(1, "Branch comparison failed: op=%0d lhs=%08x rhs=%08x",
               op, lhs, rhs);
      end
    end
  endtask

  initial begin
    instruction = encode_r(7'b0000000, 5'd2, 5'd1, 3'b000, 5'd3);
    #1;
    if (control.illegal || control.alu_op != ALU_ADD ||
        !control.register_write || control.rs1 != 5'd1 ||
        control.rs2 != 5'd2 || control.rd != 5'd3) begin
      $fatal(1, "ADD decode failed");
    end

    instruction = encode_r(7'b0000001, 5'd6, 5'd5, 3'b000, 5'd7);
    #1;
    if (control.illegal || control.alu_op != ALU_MUL) begin
      $fatal(1, "MUL decode failed");
    end

    instruction = encode_i(-12'sd4, 5'd1, 3'b000, 5'd3, 7'b0010011);
    #1;
    if (control.illegal || control.alu_op != ALU_ADD ||
        !control.use_immediate || immediate != 32'hffff_fffc) begin
      $fatal(1, "ADDI decode or immediate failed");
    end

    instruction = encode_i(12'sd8, 5'd1, 3'b010, 5'd3, 7'b0000011);
    #1;
    if (control.illegal || control.mem_op != MEM_LOAD ||
        !control.register_write || immediate != 32'd8) begin
      $fatal(1, "LW decode failed");
    end

    instruction = encode_s(-12'sd16, 5'd2, 5'd1, 3'b010);
    #1;
    if (control.illegal || control.mem_op != MEM_STORE ||
        control.register_write || immediate != 32'hffff_fff0) begin
      $fatal(1, "SW decode failed");
    end

    instruction = encode_b(13'sd12, 5'd2, 5'd1, 3'b000);
    #1;
    if (control.illegal || control.branch_op != BR_EQ ||
        immediate != 32'd12) begin
      $fatal(1, "BEQ decode failed");
    end

    instruction = 32'h0010_0073;
    #1;
    if (control.illegal || !control.ebreak || control.register_write) begin
      $fatal(1, "EBREAK decode failed");
    end

    instruction = 32'hffff_ffff;
    #1;
    if (!control.illegal || control.register_write) begin
      $fatal(1, "Illegal instruction was accepted");
    end

    check_branch(BR_EQ, 32'd4, 32'd4, 1'b1);
    check_branch(BR_NE, 32'd4, 32'd5, 1'b1);
    check_branch(BR_LT, 32'hffff_ffff, 32'd1, 1'b1);
    check_branch(BR_GE, 32'd1, 32'hffff_ffff, 1'b1);
    check_branch(BR_LTU, 32'd1, 32'hffff_ffff, 1'b1);
    check_branch(BR_GEU, 32'hffff_ffff, 32'd1, 1'b1);

    branch_op = BR_NONE;
    #1;
    if (branch_valid) begin
      $fatal(1, "Invalid branch operation was accepted");
    end

    $display("Decode regression passed");
    $finish;
  end

endmodule
