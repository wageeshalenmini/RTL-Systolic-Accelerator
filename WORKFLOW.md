# Systolic Accelerator Workflow

This accelerator efficiently computes matrix multiplication $C = A \times B$ by breaking the operation into smaller, iterative operations managed by a central hardware state machine in `systolic_accelerator.sv`. Here is the detailed step-by-step workflow:

## 1. Matrix Initialization
Initially, the host processor or testbench populates the on-board memories (`bram_A` and `bram_B`) with 8-bit matrices $A$ and $B$. The exact dimensions ($dim\_M$, $dim\_K$, $dim\_P$) for the operation are configured via the module's input pins.

## 2. Trigger
The operation is kicked off by driving the `start` signal high. The top-level state machine computes the number of $N \times N$ tiles needed based on the matrix dimensions and parameter $N$.

## 3. Tile Fetching
The state machine moves to the **`ST_LOAD_TILE`** state.
- The `tile_feeder` module reads raw data representing the current subset from $A$ and $B$.
- It pulls chunks (rows/columns) linearly and prepares them for the next stage.

## 4. Input Skewing
Systolic arrays require matrix data to arrive in a diagonal wave sequence, rather than all elements at once. 
- Data pulled by the feeder is passed through the `input_skewer` modules.
- The skewer applies cascading register delays: Row 0 implies 0 delays, Row 1 takes 1 delay, Row 2 takes 2 delays, and so on.

## 5. Systolic Multiplication Wavefront
As the skewed data funnels into the `systolic_array`:
- Information travels linearly. The top inputs pass down vertically, and side inputs pass across horizontally.
- Each `processing_element` multiplies the simultaneous vertical and horizontal data elements and adds it to its internal accumulator.
- The state machine simply waits (`ST_WAIT_ARRAY`) for $3N-2$ cycles, mathematically guaranteed to equal the propagation latency of the $N \times N$ array mesh.

## 6. Tile Accumulation
Once the physical array has finished the inner wave product for that tile:
- The `tile_accumulator` reads the array's raw snapshot (`sa_out`).
- Large matrices are handled by iteratively summing smaller internal tiles. If the operation belongs to an overlapping $K$ index, the accumulator fetches the previously stored value from `bram_C` and adds the new $N \times N$ sums to it.
- Finally, it writes the updated 20-bit tile segments permanently back to `bram_C`.

## 7. Next Tile & Completion
The system steps sequentially through the sub-tiles. It traverses the $K$ dimension iteratively to finish overlapping partial sums, then walks through columns, then rows. 
Once all bounds are met, the FSM transitions to **`ST_DONE`**, asserting the `done` signal, indicating that the full resultant matrix multiplication result can be read from `bram_C`.
