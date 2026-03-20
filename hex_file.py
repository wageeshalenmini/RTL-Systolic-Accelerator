import numpy as np
import os

# Matrix dimensions for testing (can be changed to test different sizes)
# For the hardware array size N=4, dims should be multiples of 4 for now
M = 8  # Rows of A and C
K = 8  # Cols of A, Rows of B
P = 8  # Cols of B and C
N = 4  # Hardware array size (don't change without changing RTL parameter)

print(f"Generating test vectors for {M}x{K} @ {K}x{P} multiplication (Tile size {N}x{N})...")

# Generate matrices (INT8 range: -128 to 127, or 0 to 255. We'll use 1 to 10 for simplicity)
mat_A = np.random.randint(1, 10, size=(M, K), dtype=np.int32)
mat_B = np.random.randint(1, 10, size=(K, P), dtype=np.int32)

# Calculate Golden Result
# The hardware calculates C = A @ B
golden_C = np.matmul(mat_A, mat_B)

# Save A to Hex (row-major)
with open("matrix_a.hex", "w") as f:
    for val in mat_A.flatten():
        # Mask to 8 bits (2 hex digits)
        val_8bit = val & 0xFF
        f.write(f"{val_8bit:02x}\n")

# Save B to Hex (row-major)
with open("matrix_b.hex", "w") as f:
    for val in mat_B.flatten():
        # Mask to 8 bits (2 hex digits)
        val_8bit = val & 0xFF
        f.write(f"{val_8bit:02x}\n")

# Save C to Hex (row-major)
with open("golden_c.hex", "w") as f:
    for val in golden_C.flatten():
        # Mask to 20 bits (5 hex digits)
        val_20bit = val & 0xFFFFF
        f.write(f"{val_20bit:05x}\n")

print("Success: 'matrix_a.hex', 'matrix_b.hex', and 'golden_c.hex' created.")
print(f"Max result value: {golden_C.max()} (needs {int(golden_C.max()).bit_length()} bits)")
