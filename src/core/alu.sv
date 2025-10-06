// ALU supporting basic math operations
// handles addition, subtraction, multiply, and, or, xor
// shift operations NOT currently implemented

module alu #(
    parameter int dw = 32 // default 32-bit data width
) (
    input  logic [dw-1:0] rs1,  // input operand 1
    input  logic [dw-1:0] rs2,  // input operand 2
    input  logic [2:0]    f3,   // function 3 code
    input  logic [6:0]    f7,   // function 7 code
    output logic [dw-1:0] rd    // output result
);

    // Combinational ALU
    always_comb begin
        rd = '0;
        unique case (f3)
            3'b000: begin
                if      (f7 == 7'b0000000) rd = rs1 + rs2; // ADD
                else if (f7 == 7'b0100000) rd = rs1 - rs2; // SUB
                else if (f7 == 7'b0000001) rd = rs1 * rs2; // MUL
                else                        rd = '0;
            end
            3'b100: rd = rs1 ^ rs2; // XOR
            3'b110: rd = rs1 | rs2; // OR
            3'b111: rd = rs1 & rs2; // AND
            default: rd = '0;
        endcase
    end

endmodule
