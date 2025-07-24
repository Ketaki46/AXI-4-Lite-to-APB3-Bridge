# AXI4-Lite to APB3 Bridge

## Overview

This project provides a hardware bridge to interface an AXI4-Lite master with an APB3 slave.The AXI to APB bridge serves as a protocol converter between two widely used bus standards in SoC design—AXI4-Lite and APB. 
While AXI provides high-performance, high-bandwidth access typically used by processors or DMA controllers, APB is optimized for low-power, low-complexity peripheral communication. This bridge allows an AXI master to seamlessly access APB-based slave devices by translating AXI transactions into APB-compliant operations.

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


Use-Case Scenarios

Peripheral Access from CPU: 
Enable processors interfacing via AXI to communicate with APB-based peripherals like UARTs, timers, or GPIOs.

System Integration: 
Useful in designs where IP cores use AXI interfaces but peripheral IPs are only available in APB form.

Clock Domain Isolation: 
When AXI and APB operate on different clocks, the bridge helps manage clock domain crossings (especially relevant if future designs integrate asynchronous FIFOs).

Simplifying Control Logic: 
APB's simplified transaction structure helps reduce complexity for devices that don’t need burst transfers or pipelining.


AXI APB Bridge block diagram 

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/45e06393-844b-4144-8df5-20f97e344067" />




## AXI4-Lite Slave Interface

Acts as the entry point for AXI read/write transactions from the master. Captures requests and pushes them into appropriate FIFOs for further processing by the APB side.


## Flow
Write address & data captured → sent to write FIFO → response sent back to master
Read address captured → sent to read FIFO → data fetched from APB → returned to master

## APB Master Interface
Manages communication with APB slave peripherals by issuing read and write operations based on data received from the FIFOs. Handles APB handshaking and forwards results back into the appropriate path (either back to AXI master or stored in a FIFO).

## Flow
Write data popped from write FIFO → APB write transaction initiated → data transferred to APB slave
Read address popped from read FIFO → APB read transaction initiated → data fetched from APB slave → pushed into read FIFO

## Address FIFO
Temporarily stores read addresses issued by the AXI master before transferring them to the APB master for processing. Helps in decoupling timing between AXI and APB domains.

## Flow
AXI read address captured → pushed into Address FIFO → popped by APB master → used to initiate APB read transaction

## Write FIFO
Buffers AXI write transactions containing address and data. Ensures orderly transfer to APB during write operations and enables clock decoupling if needed.

## Flow
AXI write address and data captured → combined and pushed into Write FIFO → popped by APB master → APB write transaction initiated

## Read FIFO
Stores data fetched from APB read operations. Makes read responses available to the AXI slave interface for returning to the master.

## Flow
APB read completed → data pushed into Read FIFO → popped by AXI slave → delivered to AXI master

