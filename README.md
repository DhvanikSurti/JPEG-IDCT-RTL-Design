# JPEG-IDCT-RTL-Design
Compact RTL implementation of JPEG 2D IDCT for 8×8 blocks using fixed-point arithmetic. Efficient row and column transforms share hardware for low LUT usage (&lt;20K LUT4). Includes modular Verilog, pipeline-friendly design, output scaling to 8-bit pixels, and a functional testbench validating standard JPEG test vectors.
This repository contains a compact RTL implementation of the Inverse Discrete Cosine Transform (IDCT) as part of a JPEG decoder. The design focuses on hardware efficiency, fixed-point arithmetic, and real-time performance suitable for FPGA deployment.
The IDCT module reconstructs pixel values from 8×8 blocks of JPEG DCT coefficients. The 2D IDCT is implemented as two sequential 1D IDCT operations: first along rows, then along columns. The design uses integer approximations and precomputed cosine tables to reduce resource usage while maintaining high accuracy.

Key Features
2D IDCT for 8×8 blocks with fixed-point arithmetic.
Resource-efficient design: single multiplier/accumulator reused for row and column transformations.
Pipeline-friendly and low LUT usage: fits within 20K LUT4 on FPGA.
Scalable and modular RTL: separate modules for row and column transformations.
Output scaling: produces 8-bit pixel values (0–255) with rounding and JPEG-standard offset.
Functional testbench: validates correctness using standard JPEG test vectors.

Optimization Techniques:
Shared hardware: single multiplier and accumulator for both row and column transforms.
Approximation: integer-based cosine coefficients for hardware efficiency.
Precomputed LUTs for cosine values to reduce real-time computation.
Clock gating and resource-sharing to minimize LUT and power usage.
Controller FSM: manages row/column transforms and synchronizes data flow.
Output: scaled 8-bit pixel values, suitable for direct display or further JPEG processing.
