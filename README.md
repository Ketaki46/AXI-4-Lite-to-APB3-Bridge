# AXI-4-Lite-to-APB3-Bridge
This project implements an AXI-4 Lite to APB3 bridge design, enabling smooth data transfer between the two protocol interfaces.
# AXI4-Lite to APB3 Bridge

## Overview
This project provides a hardware bridge to interface an AXI4-Lite master with an APB3 slave. The bridge translates AXI4-Lite protocol signals to APB3 protocol signals, nabling smooth data transfer using these two different bus standards.

## Features
- Supports AXI4-Lite read and write transactions
- Converts to APB3 protocol with minimal latency
- Configurable address and data widths
- Supports single transactions (no burst support)
- Error handling for invalid addresses or responses
- Synthesizable Verilog RTL code

## Repository Structure
- `src/`: Verilog source files for the bridge
- `tb/`: Testbenches for functional verification
- `docs/`: Documentation, including block diagrams and timing details


## Requirements
- Verilog/SystemVerilog simulator (e.g., QuestaSim, Vivado Simulator)
- Synthesis tool for FPGA or ASIC (e.g., Vivado)
- AXI4-Lite master and APB3 slave interfaces in the target system
