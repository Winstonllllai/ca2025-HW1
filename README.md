# Computer Architecture 2025 - Homework 1
[Detailed Report](https://hackmd.io/@Winstonllllai/arch2025-homework1)

This repository contains solutions for the Homework 1 assignment of the Computer Architecture course. The assignment involves implementing and optimizing several algorithms in RISC-V assembly language, covering bit manipulation, custom floating-point formats, and generic data structures in C.

## Project Structure

The repository is organized into several directories, each corresponding to a specific problem:

```
.
├── Leetcode190/
│   ├── reverse_bits.c             # C implementation of bit reversal
│   ├── reverse_bits.s             # Basic assembly implementation
│   ├── reverse_bits_clz.c         # C implementation using CLZ
│   ├── reverse_bits_clz.s         # Assembly implementation using CLZ
│   └── reverse_bits_clz_unroll.s  # Optimized assembly with CLZ and unrolling
│
├── Problem_B/
│   ├── q1-uf8.c                   # C implementation and test suite for UF8
│   ├── uf8.s                      # Basic assembly implementation of UF8
│   └── uf8_optim.s                # Optimized assembly implementation of UF8
│
├── Problem_C/
│   ├── q1-bfloat16.c              # C implementation and test suite for Bfloat16
│   ├── bfloat16.s                 # Basic assembly implementation of Bfloat16
│   └── bfloat16_optim.s           # Optimized assembly implementation of Bfloat16
│
├── q1-vector.c                    # C implementation of a generic vector
├── test_case.s                    # Standalone assembly test cases for UF8 and Bfloat16
├── Makefile                       # Makefile to compile C source files
└── LICENSE                        # Project license
```

## Problems Overview

### 1\. LeetCode 190: Reverse Bits

This problem focuses on reversing the bits of a 32-bit unsigned integer. Several optimization strategies were implemented in RISC-V assembly:

  - `reverse_bits.s`: A straightforward iterative implementation.
  - `reverse_bits_clz.s`: An optimized version that uses the `clz` (count leading zeros) instruction to reduce the number of loop iterations.
  - `reverse_bits_clz_unroll.s`: A further optimized version where the `clz` function itself is implemented with loop unrolling for better performance.

### 2\. Problem B: UF8 Encode/Decode

UF8 is a custom 8-bit floating-point format. This problem involves implementing the `uf8_encode` and `uf8_decode` functions in RISC-V assembly.

  - **`uf8_decode(uint8_t)`**: Converts an 8-bit UF8 value to a 32-bit unsigned integer.
  - **`uf8_encode(uint32_t)`**: Converts a 32-bit unsigned integer to the closest 8-bit UF8 representation.

The `uf8_optim.s` file provides an optimized implementation that includes an unrolled `clz` function to speed up the encoding process.

### 3\. Problem C: Bfloat16 Arithmetic

Bfloat16 (Brain Floating Point) is a 16-bit floating-point format. This problem required implementing a comprehensive set of arithmetic and comparison functions in RISC-V assembly.

The implemented functions include:

  - **Conversions**: `f32_to_bf16` and `bf16_to_f32`.
  - **Arithmetic**: `bf16_add`, `bf16_sub`, `bf16_mul`, `bf16_div`.
  - **Special Functions**: `bf16_sqrt`.
  - **Comparisons**: `bf16_eq`, `bf16_lt`, `bf16_gt`.
  - **Type Checking**: `bf16_isnan`, `bf16_isinf`, `bf16_iszero`.

The `bfloat16_optim.s` file contains optimized versions of these functions.

### 4\. Generic Vector Implementation

The file `q1-vector.c` contains a C implementation of a generic, dynamic vector (dynamic array). It supports operations like `push`, `pop`, `get_at`, `delete_at`, and automatic resizing. A full test suite is included within the file to verify its functionality.

## How to Build and Run

### Compiling C Files

The C language reference implementations (`q1-*.c`) can be compiled using the provided Makefile.

```bash
# Compile all C source files
make all

# Clean up compiled binaries
make clean
```

### Running Assembly Code

The RISC-V assembly files (`.s`) are designed to be run in the [**Ripes**](https://github.com/mortbopet/Ripes) visual CPU simulator.

1.  Open the Ripes simulator.
2.  Go to the **Editor** tab.
3.  Load the desired assembly file (e.g., `Problem_B/uf8_optim.s` or `test_case.s`).
4.  The code is automatically assembled. You can switch to the **Processor** tab to visualize the CPU pipeline.
5.  Run the simulation to completion (press the "run" button or auto-run at a high speed).
6.  The program's output will be displayed in the **I/O** console tab at the bottom of the window.

## Testing

This project includes several layers of testing:

  - **C-based Test Suites**: `q1-uf8.c` and `q1-bfloat16.c` contain comprehensive test functions that validate correctness, edge cases, and rounding for their respective modules. These serve as the reference for the assembly implementations.
  - **Assembly Test Suites**: `uf8_optim.s` and `bfloat16_optim.s` include their own embedded test suites that run automatically when the files are executed.
  - **Standalone Test Case (`test_case.s`)**: This file provides a simple, visual confirmation of the UF8 and Bfloat16 functionalities.
      - **UF8 Test**: Performs a round-trip encode/decode test for all 256 possible values and prints the results.
      - **Bfloat16 Test**: Executes a series of conversions and arithmetic operations, printing the results in human-readable float format to verify correctness.

## License

This project is licensed under the terms specified in the [LICENSE](https://www.google.com/search?q=LICENSE) file.
