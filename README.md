# MiniGPU

MiniGPU is a learning-oriented, RV32-derived SIMT processor. The near-term
target is a verified, tileable compute unit: one instruction stream controls a
parameterized array of lanes, similar in role to an NVIDIA Streaming
Multiprocessor or AMD Compute Unit.

The project intentionally starts with a small custom subset rather than claiming
full RISC-V Vector Extension compatibility. See `docs/arch.md` and
`docs/isa.md` for the current contract.

## Directories
- **src/**: synthesizable SystemVerilog
- **tb/**: SystemVerilog testbenches
- **docs/**: architecture and ISA contracts

## Getting Started

Install Verilator and GNU Make, then run:

```sh
make test
```

Useful targets are `make lint`, `make sim`, and `make clean`.
