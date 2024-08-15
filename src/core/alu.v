// ALU supporting basic math operations
// handles addition, subtraction, division, and, or, xor
// shift operations NOT currently implemented

module ALU #(
    parameter dw = 32 // default 32 bit data width
) (
    input wire [dw - 1 : 0] rs1, // input operand 1
    input wire [dw - 1 : 0] rs2, // input operand 2
    input wire [2 : 0] f3, // function 3 code
    input wire [6 : 0] f7, // function 7 code
    output reg [dw - 1 : 0] rd // output result
);

    always @(*) begin
        case (f3)
            3'b000: begin
                if (f7 == 7'b0000000) result = rs1 + rs2; // ADD
                else if (f7 == 7'b0100000) result = rs1 - rs2; // SUB
                else if (f7 == 7'b0000001) result = rs1 * rs2; // MUL
            end
            3'b100: result = rs1 ^ rs2; // XOR
            3'b110: result = rs1 | rs2; // OR
            3'b111: result = rs1 & rs2; // AND
            default: result = {dw{1'b0}}; // default to all 0's
        endcase
    end

endmodule