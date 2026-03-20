# RTL Systolic Accelerator

![Hardware-Design](https://img.shields.io/badge/Hardware-SystemVerilog-blue)
![Status](https://img.shields.io/badge/Status-Completed-success)

A parameterized SystemVerilog implementation of a Tile-Based Systolic Array Accelerator for high-performance matrix multiplication. This project is heavily inspired by modern deep learning accelerators (like Google's TPU) and demonstrates how data can be orchestrated efficiently through a mesh of processing elements without relying on shared memory, effectively avoiding memory bandwidth bottlenecks.

## Overview

At its core, this design relies on an $N \times N$ network of Processing Elements (PEs) that perform parallel Multiply-Accumulate (MAC) operations in a continuous pipeline wavefront. By breaking large matrices into hardware-sized tiles, it supports computing arbitrarily sized matrices well beyond the physical array dimensions.

### Key Features
* **Parameterized Dimensions**: Easily adjust the systolic array size ($N \times N$) and memory depths via top-level parameters. 
* **Tile-Based Architecture**: Automatically breaks down large matrices ($M \times K$ and $K \times P$) into smaller $N \times N$ tiles.
* **Integrated Memory**: Features built-in Block RAM (BRAM) modules (`bram_A`, `bram_B`, `bram_C`) for isolated data fetching and result storing.
* **Data Skewing**: Includes internal input skewers that format memory-fetched vectors into the required diagonal wavefront pattern suitable for systolic routing.
* **Partial Sum Accumulation**: Built-in tile accumulator to correctly aggregate partial products across the $K$-dimension.

## Project Structure

* **`src/`**: RTL code directory
  * `systolic_accelerator.sv`: The top-level wrapper with Master FSM, BRAMs, and datapath instantiations.
  * `systolic_array.sv`: The $N \times N$ grid of interconnected Processing Elements.
  * `processing_element.sv`: The primitive MAC execution unit.
  * `tile_feeder.sv`: BRAM reader that streams $N \times N$ tiles sequentially.
  * `input_skewer.sv`: Delays rows and columns appropriately to form the staggered systolic data wavefront.
  * `tile_accumulator.sv`: Hardware to sum and store the partial tiled products into `bram_C`.
  * `matrix_bram.sv`: Parameterizable memory wrapper for storing input and output matrices.
* **`tb/`**: Contains verification testbenches for individual and integrated components.

## Further Documentation

For detailed information on how to integrate the hardware and understand its behavior, see the explicit documentation files:
- 📖 [**Detailed Workflow & Architecture**](WORKFLOW.md)
- 🚀 [**Real-World Applications**](APPLICATIONS.md)
