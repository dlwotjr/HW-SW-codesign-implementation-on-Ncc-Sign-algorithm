# High-Performance and Configurable SW/HW Co-design of Post-Quantum Signature NCC-Sign

This repository provides a hardware/software co-design framework for the post-quantum signature scheme **NCC-Sign**.  
The implementation is not only specialized for NCC-Sign, but can also be applied to other lattice-based cryptographic schemes that utilize NTT/INTT, PWM, and Keccak modules.

It hosts hardware accelerators and co-design code, including:

- **Parameterizable NTT/INTT modules** for polynomial transformation.  
- **Parameterizable PWM (Point-Wise Multiplication) module**.  
- **Keccak (SHA-3) module** for hashing and randomness.  

This repository provides a software/hardware co-design evaluation on Xilinx Zynq platforms.

---

## Pre-requisites

Here are the tools and devices we use for implementation and testing:

- **Xilinx Vivado 2020.2** for hardware code (Verilog) implementation.  
- **Xilinx Vitis 2020.2** for software implementation (C/C++) and system verification.  
- **Xilinx ZedBoard / Zynq platforms** for FPGA implementation and testing.  
- **MobaXterm** for serial communication and result output (instead of PuTTY).  

---

## Code Organization

1. **Hardware code**
   - `NIMS_HW/HW_vivado_made/`  
     - Contains the **XSA file**, **component.xml** (IP metadata), and **PS preset .tcl file** for Vivado integration.  
   - `NIMS_HW/rtl_verilog/`  
     - Contains all hardware design files, including:
       - IP core configuration files (`.xci`)  
       - Verilog source files (`.v`)  
       - Top-level modules for integrating NTT/INTT, PWM, and Keccak.  

2. **Software code**
   - `NIMS_HW/SWCODE_TC/`  
     - Contains software code for the **trinomial-cyclic** version of NCC-Sign.  
   - `NIMS_HW/SWCODE_NC/`  
     - Contains software code for the **non-cyclic** version of NCC-Sign.  
   - ⚠ **Note**: This repository does **not** provide standalone pure software benchmark code.  

---

## Code Implementation and Real Test On FPGAs

1. For the hardware implementation and Vivado system generation, use the `.xsa`, `component.xml`, and `.tcl` files under `HW_vivado_made`.  
2. For the SW/HW co-design evaluation, run the trinomial-cyclic or non-cyclic software under Vitis with the corresponding hardware accelerator bitstream.  
3. Use **MobaXterm** to open serial communication and print runtime results from the board.  

---
