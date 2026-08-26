# MiniGPU ISA

MiniGPU uses standard encodings for a deliberately small subset of RV32I and
the `MUL` instruction from RV32M. Scalar RISC-V instructions are executed in
SIMT fashion: every active lane applies the same instruction to its own
registers and data.

This document defines the first-tile contract. MiniGPU does not currently claim
RV32I, RV32M, or RVV compliance.

## General Semantics

- Registers and addresses are 32 bits.
- Arithmetic wraps modulo 2^32.
- Immediates are sign-extended to 32 bits unless specified otherwise.
- `x0` always reads zero and discards writes.
- The default next PC is `PC + 4`.
- Unsupported encodings raise an illegal-instruction trap.
- Instructions execute only in active lanes.
- A branch target is `PC + immediate`.
- Branch decisions must initially be uniform across active lanes. Mixed
  decisions raise an unsupported-divergence trap.

## Integer Register Instructions

|Instruction|Type|Opcode|funct3|funct7|Operation|
|---|---|---|---|---|---|
|ADD|R|0110011|000|0000000|`rd = rs1 + rs2`|
|SUB|R|0110011|000|0100000|`rd = rs1 - rs2`|
|XOR|R|0110011|100|0000000|`rd = rs1 ^ rs2`|
|OR|R|0110011|110|0000000|`rd = rs1 \| rs2`|
|AND|R|0110011|111|0000000|`rd = rs1 & rs2`|

## Integer Immediate Instructions

|Instruction|Type|Opcode|funct3|Operation|
|---|---|---|---|---|
|ADDI|I|0010011|000|`rd = rs1 + sext(imm[11:0])`|
|XORI|I|0010011|100|`rd = rs1 ^ sext(imm[11:0])`|
|ORI|I|0010011|110|`rd = rs1 \| sext(imm[11:0])`|
|ANDI|I|0010011|111|`rd = rs1 & sext(imm[11:0])`|

## Memory Instructions

|Instruction|Type|Opcode|funct3|Operation|
|---|---|---|---|---|
|LW|I|0000011|010|`rd = M32[rs1 + sext(imm[11:0])]`|
|SW|S|0100011|010|`M32[rs1 + sext(imm[11:0])] = rs2`|

`LW` and `SW` use little-endian memory and require four-byte alignment.
Misaligned effective addresses trap. Active lanes may use different effective
addresses; the implementation may serialize those requests without changing
their architectural result.

## Branch Instructions

|Instruction|Type|Opcode|funct3|Condition|
|---|---|---|---|---|
|BEQ|B|1100011|000|`rs1 == rs2`|
|BNE|B|1100011|001|`rs1 != rs2`|
|BLT|B|1100011|100|`signed(rs1) < signed(rs2)`|
|BGE|B|1100011|101|`signed(rs1) >= signed(rs2)`|
|BLTU|B|1100011|110|`unsigned(rs1) < unsigned(rs2)`|
|BGEU|B|1100011|111|`unsigned(rs1) >= unsigned(rs2)`|

If the condition is true, the next PC is `PC + sext(branch immediate)`;
otherwise it is `PC + 4`.

## RV32M Subset

|Instruction|Type|Opcode|funct3|funct7|Operation|
|---|---|---|---|---|---|
|MUL|R|0110011|000|0000001|`rd = (rs1 * rs2)[31:0]`|

`MUL` returns the low 32 bits of the two's-complement product. Its initial
implementation may be combinational; latency is not architectural.

## Kernel Completion

`EBREAK` uses its standard encoding, `0x00100073`. In the initial runtime it
ends the current wavefront successfully and emits a completion event rather
than entering a debug environment.

## Deferred Instructions

Shifts, set-less-than, jumps, upper-immediate operations, byte and halfword
memory accesses, remaining RV32M operations, atomics, floating point, and CSRs
are not part of the first-tile contract.

## Vector Extension Position

The first tile uses SIMT execution of scalar encodings and does not decode RVV
instructions. The lane array, active mask, and per-lane register state provide
the parallel execution mechanism. RVV compatibility can be evaluated later,
after `vl`, `vtype`, mask, tail, and vector-memory semantics can be implemented
and verified as a complete contract.