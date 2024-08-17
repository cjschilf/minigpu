# MiniGPU ISA

The ISA for this system is a reduced set of the standard RV32I specification from RISC V, with additional functionality for vector handling from RISC V extension V. The following instructions are available:

### Instructions from RV32I ###

|Instruction|Type|Opcode|f3|f7|Description|
|---|---|---|---|---|---|
|ADD|R|0110011|000|0000000|rd = rs1 + rs2|
|SUB|R|0110011|000|0100000|rd = rs1 - rs2|
|XOR|R|0110011|100|0000000|rd = rs1 ^ rs2|
|OR|R|0110011|110|0000000|rd = rs1 \| rs2|
|AND|R|0110011|111|0000000|rd = rs1 & rs2|
|ADDI|R|0010011|000|N/A|rd = rs1 - imm|
|XORI|R|0010011|100|N/A|rd = rs1 ^ imm|
|ORI|R|0010011|110|N/A|rd = rs1 \| imm|
|ANDI|R|0010011|111|N/A|rd = rs1 & imm|
|LW|I|0000011|010|N/A|rd = M\[rs1 + imm\] \[0:31\]|
|SW|S|0100011|010|N/A|M\[rs1 + imm\] \[0:31\] = rs2\[0:31\]|
|BEQ|B|1100011|000|N/A|if(rs1 == rs2) PC += imm|
|BNE|B|1100011|001|N/A|if(rs1 != rs2) PC += imm|
|BLT|B|1100011|100|N/A|if(rs1 < rs2) PC += imm|
|BGE|B|1100011|101|N/A|if(rs1 >= rs2) PC += imm|
|BLTU|B|1100011|110|N/A|if(u(rs1) < u(rs2)) PC += imm|
|BGEU|B|1100011|111|N/A|if(u(rs1) >= u(rs2)) PC += imm|

Currently not supporting shifts or set-less-than instructions, wouldn't be difficult to add?

### Instructions from RV32 M Extension ###

### Instructions from RV32 V Extension ###