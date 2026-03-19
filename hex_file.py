import numpy as np

N = 4
# Your current test matrices (values fit in INT8: 0-255)
mat_A = np.arange(1, N*N + 1, dtype=np.int32).reshape(N, N)
mat_B = np.arange(1, N*N + 1, dtype=np.int32).reshape(N, N)

# Calculate the Golden Result
# Note: Based on your TB feed raw_col_in[i] = mat_B[cycle][i]
# The hardware calculates A @ B
golden_matrix = np.matmul(mat_A, mat_B)

# Flatten and save as Hex for SystemVerilog
# We use 5-digit hex because your result is 20-bit (final_matrix)
with open("golden_results.hex", "w") as f:
    for val in golden_matrix.flatten():
        f.write(f"{val:05x}\n")

print("Success: 'golden_results.hex' created.")
print(f"Matrix size: {N}x{N}")
print(f"Max result value: {golden_matrix.max()} (needs {int(golden_matrix.max()).bit_length()} bits)")
