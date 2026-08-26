# MiniGPU Architecture

## Objective

MiniGPU is a learning-oriented SIMT processor. Its primary deliverable is a
verified compute-unit datapath that can be instantiated multiple times behind
stable command and memory interfaces. It is similar in role, not scale or ISA
compatibility, to an NVIDIA Streaming Multiprocessor or AMD Compute Unit.

The first implementation prioritizes observable state transitions and
verification over throughput. It is single-issue and multicycle; pipelining is
deferred until the architectural model and tests are stable.

## Terminology

- **Lane:** one 32-bit integer execution datapath and its register state.
- **Wavefront:** lanes executing one instruction in lockstep under an active
  mask. This is equivalent to a warp in NVIDIA terminology.
- **Compute unit:** fetch, control, lane array, and local-memory interfaces for
  one or more resident wavefronts.
- **Tile:** one compute-unit instance with dispatch, completion, and memory
  ports. The terms tile and compute unit are interchangeable in this project.

## AMD-Inspired Decomposition

The module hierarchy follows the major boundaries of an AMD-style compute unit
without reproducing a specific commercial design:

1. A command processor outside the tile dispatches wavefronts.
2. A wavefront scheduler owns each resident wavefront's PC and `EXEC` mask.
3. A scalar front end fetches and decodes one instruction for the wavefront.
4. Vector instructions read a VGPR file and issue across a SIMD lane array.
5. A load/store unit serializes or coalesces active-lane memory requests.
6. A local data share provides explicitly managed tile-local scratchpad memory.

The first RTL slice implements the shared decoder/control types, wavefront
state, VGPR file, SIMD integer ALUs, and their vector execution datapath.
Scalar registers, scheduling, load/store, and local data share are separate
blocks so they can evolve without changing lane execution semantics.

## Initial Configuration

All sizes must remain parameters, but the verification baseline is:

- `XLEN = 32`
- `LANES = 4`
- `WAVEFRONTS = 1`
- 32 integer registers per lane
- one static zero-based ID per physical lane
- one shared PC and active mask per wavefront
- one instruction issued at a time
- little-endian, byte-addressed memory

Register `x0` always reads as zero and ignores writes. At dispatch, the host
initializes the software-visible argument registers:

- `x10`: global thread ID (`base_thread_id + lane index`)
- `x11`: wavefront ID
- `x12`: tile ID

This is a kernel ABI, not a change to RISC-V register semantics.

## Execution Model

The controller selects one valid wavefront and advances it through:

1. **Fetch:** request the 32-bit instruction at the wavefront PC.
2. **Decode:** validate the instruction and produce typed control signals.
3. **Read:** read each active lane's source registers.
4. **Execute:** perform integer ALU, branch comparison, or address generation.
5. **Memory:** issue active-lane loads or stores; the implementation may
   serialize lane requests.
6. **Writeback:** update destination registers and architectural state.
7. **Retire:** emit a verification event and advance or redirect the PC.

Every state transition is qualified by valid/ready handshakes. Backpressure must
hold requests and architectural state stable. An instruction retires exactly
once.

The initial implementation requires branch decisions to be uniform across all
active lanes. A non-uniform branch raises an unsupported-divergence trap.
Mask-stack reconvergence is a later milestone, but the active-mask state is
present from the first lane-array implementation.

## Memory Model

- Instruction and data addresses are 32-bit byte addresses.
- `LW` and `SW` require four-byte alignment; misaligned accesses trap.
- Active lanes may access different addresses.
- Lane memory operations appear in ascending lane order when serialized.
- A lane's memory operations are observed in program order.
- No caches, coherence, atomics, or virtual memory are in the initial target.
- Scratchpad memory may be added behind the same request/response contract.

The abandoned `alee-ram` branch is not an architectural dependency. Memory
blocks will be reimplemented against these interfaces and verified separately.

## Tile Interfaces

Exact packed types will be introduced with the RTL. The required semantics are:

### Dispatch input

- `valid` / `ready`
- entry PC
- wavefront ID
- base thread ID
- tile ID

### Completion output

- `valid` / `ready`
- wavefront ID
- completion status or trap cause

### Instruction and data memory

- independent request and response channels
- `valid` / `ready` on every channel
- address, write data, byte enables, and transaction ID as applicable
- responses may be delayed arbitrarily while preserving request identity

No module may depend on a global tile count. IDs are explicit, and all external
channels tolerate backpressure so multiple tiles can share an interconnect.

## Traps and Completion

The initial trap causes are illegal instruction, instruction-address
misalignment, data-address misalignment, unsupported divergence, and memory
response error. Traps stop the affected wavefront and produce a completion
event. `EBREAK` is the normal kernel-completion instruction for the first
software tests.

## Verification Contract

The RTL must emit a retire record containing enough state for differential
checking:

- wavefront ID
- instruction PC and instruction word
- active mask
- destination register index, write mask, and lane values
- memory operation, lane mask, addresses, data, and byte enables
- next PC
- trap valid and cause

Verification is layered:

1. Unit tests for combinational and state-holding modules.
2. Differential instruction tests against an executable reference model.
3. Assembly-kernel integration tests with randomized memory backpressure.
4. Local formal properties for control exclusivity, stable handshakes, `x0`,
   mask confinement, and exactly-once retirement.

The baseline must pass at `LANES = 1, 2, 4, 8` before multi-wavefront scheduling
or multiple tiles are introduced.

## Explicit Non-Goals for the First Tile

- full RVV compliance
- floating point
- caches or cache coherence
- graphics fixed-function hardware
- out-of-order execution
- preemption
- more than one resident wavefront