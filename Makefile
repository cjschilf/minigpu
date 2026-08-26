VERILATOR ?= verilator

BUILD_DIR := build
VERILATOR_FLAGS := --timing --trace -Wall

# FIXME: 
# Homebrew Verilator version I'm using passes a flag that Apple Clang 17 does not recognize
# It spams warnings about the flag and I do not like it so I asked Cursor to fix it
# This solution is only for macOS and I am unsure if the flags will be supported on Linux
ifeq ($(shell uname -s),Darwin)
VERILATOR_FLAGS += -CFLAGS -Wno-unknown-warning-option
endif

PKG := src/core/minigpu_pkg.sv
COMPUTE_RTL := \
	$(PKG) \
	src/core/alu.sv \
	src/core/branch_unit.sv \
	src/core/branch_resolver.sv \
	src/core/immediate_gen.sv \
	src/core/instruction_decoder.sv \
	src/core/simd_alu.sv \
	src/core/simd_branch_unit.sv \
	src/core/vgpr_file.sv \
	src/core/vector_datapath.sv \
	src/core/vector_lsu.sv \
	src/core/wavefront_state.sv \
	src/core/wavefront_controller.sv \
	src/core/compute_unit.sv

.PHONY: all test lint sim sim-alu sim-decode sim-simd-alu sim-vgpr \
	sim-vector-datapath sim-vector-lsu sim-wavefront sim-compute-unit \
	sim-lane-id sim-memory clean

all: test

test: lint sim

lint:
	$(VERILATOR) --lint-only -Wall --top-module compute_unit $(COMPUTE_RTL)

sim: sim-alu sim-decode sim-simd-alu sim-vgpr sim-vector-datapath \
	sim-vector-lsu sim-wavefront sim-compute-unit sim-lane-id sim-memory

sim-alu:
	mkdir -p $(BUILD_DIR)
	$(VERILATOR) --binary $(VERILATOR_FLAGS) \
		--Mdir $(BUILD_DIR)/obj_alu --top-module tb_alu \
		$(PKG) src/core/alu.sv tb/core/tb_alu.sv
	./$(BUILD_DIR)/obj_alu/Vtb_alu

sim-decode:
	mkdir -p $(BUILD_DIR)
	$(VERILATOR) --binary $(VERILATOR_FLAGS) \
		--Mdir $(BUILD_DIR)/obj_decode --top-module tb_decode \
		$(PKG) src/core/immediate_gen.sv src/core/instruction_decoder.sv \
		src/core/branch_unit.sv tb/core/tb_decode.sv
	./$(BUILD_DIR)/obj_decode/Vtb_decode

sim-simd-alu:
	mkdir -p $(BUILD_DIR)
	$(VERILATOR) --binary $(VERILATOR_FLAGS) \
		--Mdir $(BUILD_DIR)/obj_simd_alu --top-module tb_simd_alu \
		$(PKG) src/core/alu.sv src/core/simd_alu.sv \
		tb/core/tb_simd_alu.sv
	./$(BUILD_DIR)/obj_simd_alu/Vtb_simd_alu

sim-vgpr:
	mkdir -p $(BUILD_DIR)
	$(VERILATOR) --binary $(VERILATOR_FLAGS) \
		--Mdir $(BUILD_DIR)/obj_vgpr --top-module tb_vgpr_file \
		src/core/vgpr_file.sv tb/core/tb_vgpr_file.sv
	./$(BUILD_DIR)/obj_vgpr/Vtb_vgpr_file

sim-vector-datapath:
	mkdir -p $(BUILD_DIR)
	$(VERILATOR) --binary $(VERILATOR_FLAGS) \
		--Mdir $(BUILD_DIR)/obj_vector_datapath \
		--top-module tb_vector_datapath \
		$(PKG) src/core/alu.sv src/core/branch_unit.sv \
		src/core/branch_resolver.sv src/core/simd_alu.sv \
		src/core/simd_branch_unit.sv \
		src/core/vgpr_file.sv src/core/vector_datapath.sv \
		tb/core/tb_vector_datapath.sv
	./$(BUILD_DIR)/obj_vector_datapath/Vtb_vector_datapath

sim-vector-lsu:
	mkdir -p $(BUILD_DIR)
	$(VERILATOR) --binary $(VERILATOR_FLAGS) \
		--Mdir $(BUILD_DIR)/obj_vector_lsu --top-module tb_vector_lsu \
		$(PKG) src/core/vector_lsu.sv tb/core/tb_vector_lsu.sv
	./$(BUILD_DIR)/obj_vector_lsu/Vtb_vector_lsu

sim-wavefront:
	mkdir -p $(BUILD_DIR)
	$(VERILATOR) --binary $(VERILATOR_FLAGS) \
		--Mdir $(BUILD_DIR)/obj_wavefront --top-module tb_wavefront_state \
		src/core/wavefront_state.sv tb/core/tb_wavefront_state.sv
	./$(BUILD_DIR)/obj_wavefront/Vtb_wavefront_state

sim-compute-unit:
	mkdir -p $(BUILD_DIR)
	$(VERILATOR) --binary $(VERILATOR_FLAGS) \
		--Mdir $(BUILD_DIR)/obj_compute_unit --top-module tb_compute_unit \
		$(COMPUTE_RTL) tb/core/tb_compute_unit.sv
	./$(BUILD_DIR)/obj_compute_unit/Vtb_compute_unit

sim-lane-id:
	mkdir -p $(BUILD_DIR)
	$(VERILATOR) --binary $(VERILATOR_FLAGS) \
		--Mdir $(BUILD_DIR)/obj_lane_id --top-module tb_lane_id \
		$(COMPUTE_RTL) tb/core/tb_lane_id.sv
	./$(BUILD_DIR)/obj_lane_id/Vtb_lane_id

sim-memory:
	mkdir -p $(BUILD_DIR)
	$(VERILATOR) --binary $(VERILATOR_FLAGS) \
		--Mdir $(BUILD_DIR)/obj_memory --top-module tb_memory \
		$(COMPUTE_RTL) tb/core/tb_memory.sv
	./$(BUILD_DIR)/obj_memory/Vtb_memory

clean:
	rm -rf $(BUILD_DIR)
