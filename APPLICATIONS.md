# Real-World Applications

Systolic arrays are a fundamental architectural pattern used when high-bandwidth compute operations vastly outscale memory access speeds. The `RTL-Systolic-Accelerator` structure specifically tackles heavy Matrix-Matrix Multiplication (GEMM) tasks, making it a critical pattern in the following fields:

## 1. Deep Learning Accelerators
The most prominent modern application of 2D systolic arrays is inside Machine Learning ASICs. Google's Tensor Processing Unit (TPU) famously relies on a massive systolic array matrix multiplier to accelerate deep neural network inference and training. 
- **Applications:** Accelerating Convolutional Neural Networks (CNNs), Transformers, and Multi-Layer Perceptrons (MLPs).
- **Why Systolic?** Neural networks rely almost entirely on continuous vector-matrix operations. Systolic arrays allow data weights and activations to pass from one Processing Element to the next without requiring excessive RAM access, lowering power consumption while maximizing parallel throughput.

## 2. Digital Signal Processing (DSP)
Signal processing heavily features continuous convolution, which can be computationally intensive over large windows of variables.
- **Applications:** High-speed Finite Impulse Response (FIR) filtering, Infinite Impulse Response (IIR) filtering, and Discrete Fourier Transforms (DFT).
- **Why Systolic?** It is ideal for continuous filtering elements where multiple taps of previous inputs need to be constantly multiplied and accumulated against steady state coefficients.

## 3. High-Performance Scientific Computing
Scientific models resolving real-world physics problems (like weather modeling, fluid dynamics, and quantum mechanics) require extreme numerical crunching.
- **Applications:** Solving vast linear equation systems and simulating molecular structures.
- **Why Systolic?** Systolic arrays permit these intense parallel math problems to be structured linearly or in a 2D mesh, offering significant gains over standard CPU architectures for mathematical workloads.

## 4. Video & Image Processing
Multimedia tasks deal with data formatted entirely in arrays (pixels).
- **Applications:** Real-time video encoding/decoding, image filtering (e.g., blurring, edge detection), and compression algorithms like JPEG/MPEG.
- **Why Systolic?** These routines require identical mathematical operations repeated over every pixel cluster (matrix) of an image, matching beautifully with the hardware tile-based flow in our array. 
