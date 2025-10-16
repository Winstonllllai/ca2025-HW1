# Assignment 1: RISC-V Assembly and Instruction Pipeline
contributed by <[Wei-Chen Lai](https://github.com/Winstonllllai)> [`code`](https://github.com/Winstonllllai/ca2025-HW1)
:::spoiler **Table of Content**
[TOC]
:::
## Problem B
### uf8
`uf8` is a specialized 8-bit unsigned numerical representation designed for data compression. This scheme enables the storage of a dynamic range far exceeding that of a standard `uint8_t` (0-255) within a single byte (8 bits). Its core principle involves a non-linear quantization strategy that allocates the limited bits between an exponent and a mantissa, achieving a balance between numerical dynamic range and resolution precision.
* **Bit Layout**
    ```
    ┌──────────────┬──────────────┐
    │ Exponent (4) │ Mantissa (4) │
    └──────────────┴──────────────┘
    E: Exponent bits (4 bits)
    M: Mantissa/fraction bits (4 bits)
    ```
* **Decoding**
    
    $D(b) = m \cdot 2^e + (2^e - 1) \cdot 16$
    where $e = \lfloor b/16 \rfloor$ and $m = b \bmod 16$
* **Encoding**
    
    $E(v) = \begin{cases}
v, & \text{if } v < 16 \\
16e + \lfloor(v - \text{offset}(e))/2^e\rfloor, & \text{otherwise}
\end{cases}$
Where $\text{offset}(e) = (2^e - 1) \cdot 16$
### `clz` optimization
It is a processor instruction that counts the number of consecutive zero bits in a binary number, starting from the most significant bit (the left side) until the first 1 is found.
Its main purpose is to quickly determine a number's magnitude or to normalize it for floating-point operations.

The clz function was optimized using loop unrolling.
The original iterative loop was replaced with a linear sequence of instructions that explicitly performs each step. This improves performance by eliminating loop control overhead and branch instructions, at the cost of a slight increase in code size.
* **Original**
    ```assembly=
    clz:
        # Input: a0 = 32-bit unsigned integer.
        # Output: a0 = number of leading zeros in x's binary representation
        li t0, 32    # n = t0 = 32
        li t1, 16    # c = t1 = 16
    clz.loop:
        srl t2, a0, t1    # y = t2 = x >> c
        beq t2, zero, clz.skip    # if (y == 0) goto clz.skip
        sub t0, t0, t1    # n -= c
        mv a0, t2   # x = y
    clz.skip:
        srli t1, t1, 1
        bne t1, zero, clz.loop # while (c != 0) goto clz.loop
        sub a0, t0, a0    # return n - x
        ret    # End of clz function
    ```
* **Unroll loop**
    ```assembly=
    clz:
        # Input: a0 = 32-bit unsigned integer.
        # Output: a0 = number of leading zeros in x's binary representation
        li t0, 32           # n = t0 = 32
        srli t2, a0, 16      # y = t2 = x >> 16
        beq t2, zero, clz.L_c8 # if (y == 0) goto clz.L_c8
        addi t0, t0, -16      # n -= 16
        mv a0, t2           # x = y
    clz.L_c8:
        srli t2, a0, 8       # y = t2 = x >> 8
        beq t2, zero, clz.L_c4 # if (y == 0) goto clz.L_c4
        addi t0, t0, -8       # n -= 8
        mv a0, t2           # x = y
    clz.L_c4:
        srli t2, a0, 4       # y = t2 = x >> 4
        beq t2, zero, clz.L_c2 # if (y == 0) goto clz.L_c2
        addi t0, t0, -4       # n -= 4
        mv a0, t2           # x = y
    clz.L_c2:
        srli t2, a0, 2       # y = t2 = x >> 2
        beq t2, zero, clz.L_c1 # if (y == 0) goto .L_c1
        addi t0, t0, -2       # n -= 2
        mv a0, t2           # x = y
    clz.L_c1:
        srli t2, a0, 1       # y = t2 = x >> 1
        beq t2, zero, clz.L_final # if (y == 0) goto clz.L_final
        addi t0, t0, -1       # n -= 1
        mv a0, t2           # x = y
    clz.L_final:
        sub a0, t0, a0      # return n - x
        ret
    ```
* **Analysis**
    

| | best case clz(0) | worst case clz(0x80000000)|
| -------- | -------- | -------- |
|**Original**|![image](https://hackmd.io/_uploads/SJWUrYDTll.png)|![image](https://hackmd.io/_uploads/S1FGStDplx.png)|
|**Unrolled**|![image](https://hackmd.io/_uploads/HyytEtvTee.png)|![image](https://hackmd.io/_uploads/rymkSFvale.png)



### C Code
:::spoiler C Code (Click to unfold)
``` clike=
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

typedef uint8_t uf8;

static inline unsigned clz(uint32_t x)
{
    int n = 32, c = 16;
    do {
        uint32_t y = x >> c;
        if (y) {
            n -= c;
            x = y;
        }
        c >>= 1;
    } while (c);
    return n - x;
}

/* Decode uf8 to uint32_t */
uint32_t uf8_decode(uf8 fl)
{
    uint32_t mantissa = fl & 0x0f;
    uint8_t exponent = fl >> 4;
    uint32_t offset = (0x7FFF >> (15 - exponent)) << 4;
    return (mantissa << exponent) + offset;
}

/* Encode uint32_t to uf8 */
uf8 uf8_encode(uint32_t value)
{
    /* Use CLZ for fast exponent calculation */
    if (value < 16)
        return value;

    /* Find appropriate exponent using CLZ hint */
    int lz = clz(value);
    int msb = 31 - lz;

    /* Start from a good initial guess */
    uint8_t exponent = 0;
    uint32_t overflow = 0;

    if (msb >= 5) {
        /* Estimate exponent - the formula is empirical */
        exponent = msb - 4;
        if (exponent > 15)
            exponent = 15;

        /* Calculate overflow for estimated exponent */
        for (uint8_t e = 0; e < exponent; e++)
            overflow = (overflow << 1) + 16;

        /* Adjust if estimate was off */
        while (exponent > 0 && value < overflow) {
            overflow = (overflow - 16) >> 1;
            exponent--;
        }
    }

    /* Find exact exponent */
    while (exponent < 15) {
        uint32_t next_overflow = (overflow << 1) + 16;
        if (value < next_overflow)
            break;
        overflow = next_overflow;
        exponent++;
    }

    uint8_t mantissa = (value - overflow) >> exponent;
    return (exponent << 4) | mantissa;
}

/* Test encode/decode round-trip */
static bool test(void)
{
    int32_t previous_value = -1;
    bool passed = true;

    for (int i = 0; i < 256; i++) {
        uint8_t fl = i;
        int32_t value = uf8_decode(fl);
        uint8_t fl2 = uf8_encode(value);

        if (fl != fl2) {
            printf("%02x: produces value %d but encodes back to %02x\n", fl,
                   value, fl2);
            passed = false;
        }

        if (value <= previous_value) {
            printf("%02x: value %d <= previous_value %d\n", fl, value,
                   previous_value);
            passed = false;
        }

        previous_value = value;
    }

    return passed;
}

int main(void)
{
    if (test()) {
        printf("All tests passed.\n");
        return 0;
    }
    return 1;
}
```
:::

### Assembly Code
::: spoiler Assembly Code (Click to unfold)
```assembly=
.data
str1: .string ": produces value "
str2: .string " but encodes back to "
str3: .string ": value "
str4: .string " <= previous_value "
str5: .string "All tests passed.\n"
str6: .string "\n"


.text
# ======================================
# Function: main
# ======================================
main:
    # Input: void
    # Output: a0 = exit code
    addi sp, sp, -4  # Allocate stack space
    sw ra, 0(sp)     # Save return address
    jal test     # a0 = test()
    lw ra, 0(sp)     # Restore return address
    addi sp, sp, 4   # Deallocate stack space
    beq a0, zero, main.end  # if (a0 == 0) goto main.end
    la a0, str5  # Load address of str5
    li a7, 4  # syscall: print string
    ecall
main.end:
    li a7, 10  # exit code = 10
    ecall

# ======================================
# Function: clz (Optimized with Unrolling)
# ======================================
clz:
    # Input: a0 = 32-bit unsigned integer.
    # Output: a0 = number of leading zeros in x's binary representation
    li t0, 32           # n = t0 = 32
    srli t2, a0, 16      # y = t2 = x >> 16
    beq t2, zero, clz.L_c8 # if (y == 0) goto clz.L_c8
    addi t0, t0, -16      # n -= 16
    mv a0, t2           # x = y
clz.L_c8:
    srli t2, a0, 8       # y = t2 = x >> 8
    beq t2, zero, clz.L_c4 # if (y == 0) goto clz.L_c4
    addi t0, t0, -8       # n -= 8
    mv a0, t2           # x = y
clz.L_c4:
    srli t2, a0, 4       # y = t2 = x >> 4
    beq t2, zero, clz.L_c2 # if (y == 0) goto clz.L_c2
    addi t0, t0, -4       # n -= 4
    mv a0, t2           # x = y
clz.L_c2:
    srli t2, a0, 2       # y = t2 = x >> 2
    beq t2, zero, clz.L_c1 # if (y == 0) goto .L_c1
    addi t0, t0, -2       # n -= 2
    mv a0, t2           # x = y
clz.L_c1:
    srli t2, a0, 1       # y = t2 = x >> 1
    beq t2, zero, clz.L_final # if (y == 0) goto clz.L_final
    addi t0, t0, -1       # n -= 1
    mv a0, t2           # x = y
clz.L_final:
    sub a0, t0, a0      # return n - x
    ret
    
# ======================================
# Function: uf8_decode
# ======================================
uf8_decode:
    # Input: a0 = 8-bit unsigned integer
    # Output: a0 = 32-bit unsigned integer
    andi t0, a0, 0x0f  # mantissa = t0 = fl & 0x0f
    srli t1, a0, 4     # exponent = t1 = fl >> 4
    li t2, 0x7fff   # offset = t2 = 0x7fff
    li t3, 15      # t3 dummy = 15
    sub t3, t3, t1  # t3 = 15 - exponent
    srl t2, t2, t3  # offset >>= (15 - exponent)
    slli t2, t2, 4  # offset <<= 4
    sll t0, t0, t1  # mantissa <<= exponent
    add a0, t0, t2  # return mantissa + offset
    ret # End of uf8_decode function

# ======================================
# Function: uf8_encode
# ======================================
uf8_encode:
    # Input: a = 32-bit unsigned integer
    # Output: a0 = 8-bit unsigned integer
    li t0, 16    # t0 dummy = 16
    blt a0, t0, uf8_encode.end    # if (value < 16) return value
    addi sp, sp, -8  # Allocate stack space
    sw ra, 0(sp)     # Save return address
    sw a0, 4(sp)     # Save value
    jal clz      # Call clz function
    mv t1, a0   # lz = t1 = clz(value)
    lw a0, 4(sp)     # Restore value
    lw ra, 0(sp)     # Restore return address
    addi sp, sp, 8   # Deallocate stack space
    li t2, 31   # msb = t2 = 31
    sub t2, t2, t1   # msb = 31 - lz
    li t3, 0    # exponent = t3 = 0
    li t4, 0    # overflow = t4 = 24
    li t0, 5   # t0 dummy = 5
    blt t2, t0, uf8_encode.loop3    # if (msb < 5) goto loop
    addi t3, t2, -4  # exponent = msb - 4
    li t0, 15  # t0 dummy = 15
    bge t0, t3, uf8_encode.skip1    # if (exponent <= 15) goto skip1
    li t3, 15  # exponent = 15
uf8_encode.skip1:
    li t0, 0  # e = t0 = 0
uf8_encode.loop1:
    bge t0, t3, uf8_encode.loop2
    slli t4, t4,1  # overflow <<= 1
    addi t4, t4, 16 # overflow += 16
    addi t0, t0, 1 # e += 1
    j uf8_encode.loop1
uf8_encode.loop2:
    bge zero, t3, uf8_encode.loop2_end # if (0 >= exponent) goto loop2_end
    bge a0, t4, uf8_encode.loop2_end  # if (value >= overflow) goto loop2_end
    addi t4, t4, -16 # overflow -= 16
    srli t4, t4, 1  # overflow >>= 1
    addi t3, t3, -1  # exponent -= 1
    j uf8_encode.loop2
uf8_encode.loop2_end:
    li t0, 15 # t0 dummy = 15
uf8_encode.loop3:
    bge t3, t0, uf8_encode.skip2  # if (exponent >= 15) goto skip1
    slli t2, t4, 1  # next_overflow = overflow << 1
    addi t2, t2, 16 # next_overflow += 16
    blt a0, t2, uf8_encode.skip2  # if (value < next_overflow) goto skip1
    mv t4, t2 # overflow = next_overflow
    addi t3, t3, 1  # exponent += 1
    j uf8_encode.loop3
uf8_encode.skip2:
    sub t2, a0, t4  # mantissa = value - overflow
    srl t2, t2, t3 # mantissa >>= exponent
    slli a0, t3,4  # a0 = exponent << 4
    or a0, a0, t2  # a0 |= mantissa
uf8_encode.end:
    ret # End of uf8_encode function

# ======================================
# Function: Test
# ======================================
test:
    # Input: void
    # Output: a0 = boolean (1 = pass, 0 = fail)
    addi sp, sp, -20  # Allocate stack space
    sw ra, 0(sp)  # Save return address
    sw s0, 4(sp)  # Save previous_value
    sw s1, 8(sp)  # Save passed
    sw s2, 12(sp)  # Save i
    sw s3, 16(sp)  # Save max
    li s0, -1   # previous_value = -1
    li s1, 1    # s1 = passed = 1
    li s2, 0    # s2 = i = 0
    li s3, 256  # s3 = max = 256
test.loop:
    bge s2, s3, test.end   # if (i >= max) goto end
    mv a0, s2  # a0 = fl
    jal uf8_decode  # a0 = uf8_decode(fl)
    mv t5, a0  # value = t5 = uf8_decode(fl)
    jal uf8_encode  # a0 = uf8_encode(value)
    mv t6, a0  # fl2 = t6 = uf8_encode(value)
    mv t4, s2  # fl = t4 = i
    beq t4, t6, test.skip1  # if (fl == fl2) goto skip1
    mv a0, t4  # a0 = fl
    li a7, 34  # syscall: print integer
    ecall
    la a0, str1  # Load address of str1
    li a7, 4  # syscall: print string
    ecall
    mv a0, t5  # a0 = value
    li a7, 1  # syscall: print integer
    ecall
    la a0, str2  # Load address of str2
    li a7, 4  # syscall: print string
    ecall
    mv a0, t6  # a0 = fl2
    li a7, 34  # syscall: print integer
    ecall
    la a0, str6  # Load address of str6
    li a7, 4  # syscall: print string
    ecall
    li s1, 0  # passed = 0
test.skip1:
    blt s0, t5, test.skip2  # if (previous_value < value) goto skip2
    mv a0, t4  # a0 = fl
    li a7, 34  # syscall: print integer
    ecall
    la a0, str3  # Load address of str3
    li a7, 4  # syscall: print string
    ecall
    mv a0, t5  # a0 = value
    li a7, 1  # syscall: print integer
    ecall
    la a0, str4  # Load address of str4
    li a7, 4  # syscall: print string
    ecall
    mv a0, s0  # a0 = previous_value
    li a7, 1  # syscall: print integer
    ecall
    la a0, str6  # Load address of str6
    li a7, 4  # syscall: print string
    ecall
    li s1, 0  # passed = 0
    mv a0, s1  # return passed
test.skip2:
    mv s0, t5  # previous_value = value
    addi s2, s2, 1  # i++
    j test.loop
test.end:
    lw s3, 16(sp)  # Restore max
    lw s2, 12(sp)  # Restore i
    lw s1, 8(sp)   # Restore passed
    lw s0, 4(sp)   # Restore previous_value
    lw ra, 0(sp)   # Restore return address
    addi sp, sp, 20  # Deallocate stack space
    ret  # End of test function

```
:::
### Test result
![image](https://hackmd.io/_uploads/r1KUpQ9ple.png)





| Console |Compiled C code |Original Assembly |Optimized Assembly|
| -------- | -------- | -------- |-------- |
| ![image](https://hackmd.io/_uploads/rkRNDKPpel.png)| ![image](https://hackmd.io/_uploads/SJYZuYPTgx.png)   |![image](https://hackmd.io/_uploads/SJmCPYPalg.png)     |![image](https://hackmd.io/_uploads/HkZ3vtDTlx.png)

## Problem C
### bfloat16
bfloat16 (Brain Floating Point) is a 16-bit floating-point format designed specifically for Machine Learning (ML) and Artificial Intelligence (AI) applications. It is considered a clever compromise between the standard 32-bit (float32) and 16-bit half-precision (float16) floating-point formats.
* **Bit Layout**
    * float32
        ```
        ┌────────┬──────────────┬──────────────────────────────────────┐
        │Sign (1)│ Exponent (8) │             Mantissa (23)            │
        └────────┴──────────────┴──────────────────────────────────────┘
        31      30             22                                      0

        S: Sign bit (0 = positive, 1 = negative)
        E: Exponent bits (8 bits, bias = 127)
        M: Mantissa/fraction bits (23 bits)
        ```
    * bfloat16
        ```
        ┌─────────┬──────────────┬──────────────┐
        │Sign (1) │ Exponent (8) │ Mantissa (7) │
        └─────────┴──────────────┴──────────────┘
        15       14              6              0

        S: Sign bit (0 = positive, 1 = negative)
        E: Exponent bits (8 bits, bias = 127)
        M: Mantissa/fraction bits (7 bits)
        ```
* **Format Conversion**
    * `f32_to_bf16(float val)`: Converts a standard 32-bit float to a `bfloat16`. This involves more than simple truncation; it requires proper Rounding to minimize precision loss.

        $v = (-1)^S \times 2^{E-127} \times \left(1 + \frac{M}{128}\right)$

    * `bf16_to_f32(bf16_t val)`: Converts a `bfloat16` back to a 32-bit float. This process is relatively simpler, mainly involving padding the mantissa with zeros.
* **Arithmetic Operations**
    * `bf16_add(a, b)`: Addition
    * `bf16_sub(a, b)`: Subtraction
    * `bf16_mul(a, b)`: Multiplication
    * `bf16_div(a, b)`: Division
    * `bf16_sqrt(a)`: Square Root $\sqrt{a} = \sqrt{2^{e_a} \times m_a} = 2^{e_a/2} \times \sqrt{m_a}$
* **Comparison Operations and Special Value Checks**
    * `bf16_eq`, `bf16_lt`, `bf16_gt`: Implement comparison functions. Pay special attention to the rule that any comparison involving NaN must return false.
    * `bf16_isnan`, `bf16_isinf`, `bf16_iszero`: Implement helper functions to check for special values.
        * $\sqrt{+0} = +0$
        * $\sqrt{-0} = 0$
        * $\sqrt{+\infty} = +\infty$
        * $\sqrt{-\infty} = \text{NaN}$
        * $\sqrt{\text{NaN}} = \text{NaN}$
        * $\sqrt{x} = \text{NaN}$ for all $x < 0$
### C Code
:::spoiler C Code (Click to unfold)
```clike=
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

typedef struct {
    uint16_t bits;
} bf16_t;

#define BF16_SIGN_MASK 0x8000U
#define BF16_EXP_MASK 0x7F80U
#define BF16_MANT_MASK 0x007FU
#define BF16_EXP_BIAS 127

#define BF16_NAN() ((bf16_t) {.bits = 0x7FC0})
#define BF16_ZERO() ((bf16_t) {.bits = 0x0000})

static inline bool bf16_isnan(bf16_t a)
{
    return ((a.bits & BF16_EXP_MASK) == BF16_EXP_MASK) &&
           (a.bits & BF16_MANT_MASK);
}

static inline bool bf16_isinf(bf16_t a)
{
    return ((a.bits & BF16_EXP_MASK) == BF16_EXP_MASK) &&
           !(a.bits & BF16_MANT_MASK);
}

static inline bool bf16_iszero(bf16_t a)
{
    return !(a.bits & 0x7FFF);
}

static inline bf16_t f32_to_bf16(float val)
{
    uint32_t f32bits;
    memcpy(&f32bits, &val, sizeof(float));
    if (((f32bits >> 23) & 0xFF) == 0xFF)
        return (bf16_t) {.bits = (f32bits >> 16) & 0xFFFF};
    f32bits += ((f32bits >> 16) & 1) + 0x7FFF;
    return (bf16_t) {.bits = f32bits >> 16};
}

static inline float bf16_to_f32(bf16_t val)
{
    uint32_t f32bits = ((uint32_t) val.bits) << 16;
    float result;
    memcpy(&result, &f32bits, sizeof(float));
    return result;
}

static inline bf16_t bf16_add(bf16_t a, bf16_t b)
{
    uint16_t sign_a = (a.bits >> 15) & 1;
    uint16_t sign_b = (b.bits >> 15) & 1;
    int16_t exp_a = ((a.bits >> 7) & 0xFF);
    int16_t exp_b = ((b.bits >> 7) & 0xFF);
    uint16_t mant_a = a.bits & 0x7F;
    uint16_t mant_b = b.bits & 0x7F;

    if (exp_a == 0xFF) {
        if (mant_a)
            return a;
        if (exp_b == 0xFF)
            return (mant_b || sign_a == sign_b) ? b : BF16_NAN();
        return a;
    }
    if (exp_b == 0xFF)
        return b;
    if (!exp_a && !mant_a)
        return b;
    if (!exp_b && !mant_b)
        return a;
    if (exp_a)
        mant_a |= 0x80;
    if (exp_b)
        mant_b |= 0x80;

    int16_t exp_diff = exp_a - exp_b;
    uint16_t result_sign;
    int16_t result_exp;
    uint32_t result_mant;

    if (exp_diff > 0) {
        result_exp = exp_a;
        if (exp_diff > 8)
            return a;
        mant_b >>= exp_diff;
    } else if (exp_diff < 0) {
        result_exp = exp_b;
        if (exp_diff < -8)
            return b;
        mant_a >>= -exp_diff;
    } else {
        result_exp = exp_a;
    }

    if (sign_a == sign_b) {
        result_sign = sign_a;
        result_mant = (uint32_t) mant_a + mant_b;

        if (result_mant & 0x100) {
            result_mant >>= 1;
            if (++result_exp >= 0xFF)
                return (bf16_t) {.bits = (result_sign << 15) | 0x7F80};
        }
    } else {
        if (mant_a >= mant_b) {
            result_sign = sign_a;
            result_mant = mant_a - mant_b;
        } else {
            result_sign = sign_b;
            result_mant = mant_b - mant_a;
        }

        if (!result_mant)
            return BF16_ZERO();
        while (!(result_mant & 0x80)) {
            result_mant <<= 1;
            if (--result_exp <= 0)
                return BF16_ZERO();
        }
    }

    return (bf16_t) {
        .bits = (result_sign << 15) | ((result_exp & 0xFF) << 7) |
                (result_mant & 0x7F),
    };
}

static inline bf16_t bf16_sub(bf16_t a, bf16_t b)
{
    b.bits ^= BF16_SIGN_MASK;
    return bf16_add(a, b);
}

static inline bf16_t bf16_mul(bf16_t a, bf16_t b)
{
    uint16_t sign_a = (a.bits >> 15) & 1;
    uint16_t sign_b = (b.bits >> 15) & 1;
    int16_t exp_a = ((a.bits >> 7) & 0xFF);
    int16_t exp_b = ((b.bits >> 7) & 0xFF);
    uint16_t mant_a = a.bits & 0x7F;
    uint16_t mant_b = b.bits & 0x7F;

    uint16_t result_sign = sign_a ^ sign_b;

    if (exp_a == 0xFF) {
        if (mant_a)
            return a;
        if (!exp_b && !mant_b)
            return BF16_NAN();
        return (bf16_t) {.bits = (result_sign << 15) | 0x7F80};
    }
    if (exp_b == 0xFF) {
        if (mant_b)
            return b;
        if (!exp_a && !mant_a)
            return BF16_NAN();
        return (bf16_t) {.bits = (result_sign << 15) | 0x7F80};
    }
    if ((!exp_a && !mant_a) || (!exp_b && !mant_b))
        return (bf16_t) {.bits = result_sign << 15};

    int16_t exp_adjust = 0;
    if (!exp_a) {
        while (!(mant_a & 0x80)) {
            mant_a <<= 1;
            exp_adjust--;
        }
        exp_a = 1;
    } else
        mant_a |= 0x80;
    if (!exp_b) {
        while (!(mant_b & 0x80)) {
            mant_b <<= 1;
            exp_adjust--;
        }
        exp_b = 1;
    } else
        mant_b |= 0x80;

    uint32_t result_mant = (uint32_t) mant_a * mant_b;

    int32_t result_exp = (int32_t) exp_a + exp_b - BF16_EXP_BIAS + exp_adjust;

    if (result_mant & 0x8000) {
        result_mant = (result_mant >> 8) & 0x7F;
        result_exp++;
    } else
        result_mant = (result_mant >> 7) & 0x7F;

    if (result_exp >= 0xFF)
        return (bf16_t) {.bits = (result_sign << 15) | 0x7F80};
    if (result_exp <= 0) {
        if (result_exp < -6)
            return (bf16_t) {.bits = result_sign << 15};
        result_mant >>= (1 - result_exp);
        result_exp = 0;
    }

    return (bf16_t) {.bits = (result_sign << 15) | ((result_exp & 0xFF) << 7) |
                             (result_mant & 0x7F)};
}

static inline bf16_t bf16_div(bf16_t a, bf16_t b)
{
    uint16_t sign_a = (a.bits >> 15) & 1;
    uint16_t sign_b = (b.bits >> 15) & 1;
    int16_t exp_a = ((a.bits >> 7) & 0xFF);
    int16_t exp_b = ((b.bits >> 7) & 0xFF);
    uint16_t mant_a = a.bits & 0x7F;
    uint16_t mant_b = b.bits & 0x7F;

    uint16_t result_sign = sign_a ^ sign_b;

    if (exp_b == 0xFF) {
        if (mant_b)
            return b;
        /* Inf/Inf = NaN */
        if (exp_a == 0xFF && !mant_a)
            return BF16_NAN();
        return (bf16_t) {.bits = result_sign << 15};
    }
    if (!exp_b && !mant_b) {
        if (!exp_a && !mant_a)
            return BF16_NAN();
        return (bf16_t) {.bits = (result_sign << 15) | 0x7F80};
    }
    if (exp_a == 0xFF) {
        if (mant_a)
            return a;
        return (bf16_t) {.bits = (result_sign << 15) | 0x7F80};
    }
    if (!exp_a && !mant_a)
        return (bf16_t) {.bits = result_sign << 15};

    if (exp_a)
        mant_a |= 0x80;
    if (exp_b)
        mant_b |= 0x80;

    uint32_t dividend = (uint32_t) mant_a << 15;
    uint32_t divisor = mant_b;
    uint32_t quotient = 0;

    for (int i = 0; i < 16; i++) {
        quotient <<= 1;
        if (dividend >= (divisor << (15 - i))) {
            dividend -= (divisor << (15 - i));
            quotient |= 1;
        }
    }

    int32_t result_exp = (int32_t) exp_a - exp_b + BF16_EXP_BIAS;

    if (!exp_a)
        result_exp--;
    if (!exp_b)
        result_exp++;

    if (quotient & 0x8000)
        quotient >>= 8;
    else {
        while (!(quotient & 0x8000) && result_exp > 1) {
            quotient <<= 1;
            result_exp--;
        }
        quotient >>= 8;
    }
    quotient &= 0x7F;

    if (result_exp >= 0xFF)
        return (bf16_t) {.bits = (result_sign << 15) | 0x7F80};
    if (result_exp <= 0)
        return (bf16_t) {.bits = result_sign << 15};
    return (bf16_t) {
        .bits = (result_sign << 15) | ((result_exp & 0xFF) << 7) |
                (quotient & 0x7F),
    };
}

static inline bf16_t bf16_sqrt(bf16_t a)
{
    uint16_t sign = (a.bits >> 15) & 1;
    int16_t exp = ((a.bits >> 7) & 0xFF);
    uint16_t mant = a.bits & 0x7F;

    /* Handle special cases */
    if (exp == 0xFF) {
        if (mant)
            return a; /* NaN propagation */
        if (sign)
            return BF16_NAN(); /* sqrt(-Inf) = NaN */
        return a;              /* sqrt(+Inf) = +Inf */
    }

    /* sqrt(0) = 0 (handle both +0 and -0) */
    if (!exp && !mant)
        return BF16_ZERO();

    /* sqrt of negative number is NaN */
    if (sign)
        return BF16_NAN();

    /* Flush denormals to zero */
    if (!exp)
        return BF16_ZERO();

    /* Direct bit manipulation square root algorithm */
    /* For sqrt: new_exp = (old_exp - bias) / 2 + bias */
    int32_t e = exp - BF16_EXP_BIAS;
    int32_t new_exp;
    
    /* Get full mantissa with implicit 1 */
    uint32_t m = 0x80 | mant;  /* Range [128, 256) representing [1.0, 2.0) */
    
    /* Adjust for odd exponents: sqrt(2^odd * m) = 2^((odd-1)/2) * sqrt(2*m) */
    if (e & 1) {
        m <<= 1;  /* Double mantissa for odd exponent */
        new_exp = ((e - 1) >> 1) + BF16_EXP_BIAS;
    } else {
        new_exp = (e >> 1) + BF16_EXP_BIAS;
    }
    
    /* Now m is in range [128, 256) or [256, 512) if exponent was odd */
    /* Binary search for integer square root */
    /* We want result where result^2 = m * 128 (since 128 represents 1.0) */
    
    uint32_t low = 90;          /* Min sqrt (roughly sqrt(128)) */
    uint32_t high = 256;        /* Max sqrt (roughly sqrt(512)) */
    uint32_t result = 128;      /* Default */
    
    /* Binary search for square root of m */
    while (low <= high) {
        uint32_t mid = (low + high) >> 1;
        uint32_t sq = (mid * mid) / 128;  /* Square and scale */
        
        if (sq <= m) {
            result = mid;  /* This could be our answer */
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }
    
    /* result now contains sqrt(m) * sqrt(128) / sqrt(128) = sqrt(m) */
    /* But we need to adjust the scale */
    /* Since m is scaled where 128=1.0, result should also be scaled same way */
    
    /* Normalize to ensure result is in [128, 256) */
    if (result >= 256) {
        result >>= 1;
        new_exp++;
    } else if (result < 128) {
        while (result < 128 && new_exp > 1) {
            result <<= 1;
            new_exp--;
        }
    }
    
    /* Extract 7-bit mantissa (remove implicit 1) */
    uint16_t new_mant = result & 0x7F;
    
    /* Check for overflow/underflow */
    if (new_exp >= 0xFF)
        return (bf16_t) {.bits = 0x7F80};  /* +Inf */
    if (new_exp <= 0)
        return BF16_ZERO();
    
    return (bf16_t) {.bits = ((new_exp & 0xFF) << 7) | new_mant};
}

static inline bool bf16_eq(bf16_t a, bf16_t b)
{
    if (bf16_isnan(a) || bf16_isnan(b))
        return false;
    if (bf16_iszero(a) && bf16_iszero(b))
        return true;
    return a.bits == b.bits;
}

static inline bool bf16_lt(bf16_t a, bf16_t b)
{
    if (bf16_isnan(a) || bf16_isnan(b))
        return false;
    if (bf16_iszero(a) && bf16_iszero(b))
        return false;
    bool sign_a = (a.bits >> 15) & 1, sign_b = (b.bits >> 15) & 1;
    if (sign_a != sign_b)
        return sign_a > sign_b;
    return sign_a ? a.bits > b.bits : a.bits < b.bits;
}

static inline bool bf16_gt(bf16_t a, bf16_t b)
{
    return bf16_lt(b, a);
}

#include <stdio.h>
#include <time.h>

#define TEST_ASSERT(cond, msg)         \
    do {                               \
        if (!(cond)) {                 \
            printf("FAIL: %s\n", msg); \
            return 1;                  \
        }                              \
    } while (0)

static int test_basic_conversions(void)
{
    printf("Testing basic conversions...\n");

    float test_values[] = {0.0f,  1.0f,     -1.0f,     2.0f,  -2.0f, 0.5f,
                           -0.5f, 3.14159f, -3.14159f, 1e10f, -1e10f};

    for (size_t i = 0; i < sizeof(test_values) / sizeof(test_values[0]); i++) {
        float orig = test_values[i];
        bf16_t bf = f32_to_bf16(orig);
        float conv = bf16_to_f32(bf);

        if (orig != 0.0f) {
            TEST_ASSERT((orig < 0) == (conv < 0), "Sign mismatch");
        }

        if (orig != 0.0f && !bf16_isinf(f32_to_bf16(orig))) {
            float diff = (conv - orig);
            float rel_error = (diff < 0) ? -diff / orig : diff / orig;
            TEST_ASSERT(rel_error < 0.01f, "Relative error too large");
        }
    }

    printf("  Basic conversions: PASS\n");
    return 0;
}

static int test_special_values(void)
{
    printf("Testing special values...\n");

    bf16_t pos_inf = {.bits = 0x7F80};  /* +Infinity */
    TEST_ASSERT(bf16_isinf(pos_inf), "Positive infinity not detected");
    TEST_ASSERT(!bf16_isnan(pos_inf), "Infinity detected as NaN");

    bf16_t neg_inf = {.bits = 0xFF80};  /* -Infinity */
    TEST_ASSERT(bf16_isinf(neg_inf), "Negative infinity not detected");

    bf16_t nan_val = BF16_NAN();
    TEST_ASSERT(bf16_isnan(nan_val), "NaN not detected");
    TEST_ASSERT(!bf16_isinf(nan_val), "NaN detected as infinity");

    bf16_t zero = f32_to_bf16(0.0f);
    TEST_ASSERT(bf16_iszero(zero), "Zero not detected");

    bf16_t neg_zero = f32_to_bf16(-0.0f);
    TEST_ASSERT(bf16_iszero(neg_zero), "Negative zero not detected");

    printf("  Special values: PASS\n");
    return 0;
}

static int test_arithmetic(void)
{
    printf("Testing arithmetic operations...\n");

    bf16_t a = f32_to_bf16(1.0f);
    bf16_t b = f32_to_bf16(2.0f);
    bf16_t c = bf16_add(a, b);
    float result = bf16_to_f32(c);
    float diff = result - 3.0f;
    TEST_ASSERT((diff < 0 ? -diff : diff) < 0.01f, "Addition failed");

    c = bf16_sub(b, a);
    result = bf16_to_f32(c);
    diff = result - 1.0f;
    TEST_ASSERT((diff < 0 ? -diff : diff) < 0.01f, "Subtraction failed");

    a = f32_to_bf16(3.0f);
    b = f32_to_bf16(4.0f);
    c = bf16_mul(a, b);
    result = bf16_to_f32(c);
    diff = result - 12.0f;
    TEST_ASSERT((diff < 0 ? -diff : diff) < 0.1f, "Multiplication failed");

    a = f32_to_bf16(10.0f);
    b = f32_to_bf16(2.0f);
    c = bf16_div(a, b);
    result = bf16_to_f32(c);
    diff = result - 5.0f;
    TEST_ASSERT((diff < 0 ? -diff : diff) < 0.1f, "Division failed");

    /* Test square root */
    a = f32_to_bf16(4.0f);
    c = bf16_sqrt(a);
    result = bf16_to_f32(c);
    diff = result - 2.0f;
    TEST_ASSERT((diff < 0 ? -diff : diff) < 0.01f, "sqrt(4) failed");

    a = f32_to_bf16(9.0f);
    c = bf16_sqrt(a);
    result = bf16_to_f32(c);
    diff = result - 3.0f;
    TEST_ASSERT((diff < 0 ? -diff : diff) < 0.01f, "sqrt(9) failed");

    printf("  Arithmetic: PASS\n");
    return 0;
}

static int test_comparisons(void)
{
    printf("Testing comparison operations...\n");

    bf16_t a = f32_to_bf16(1.0f);
    bf16_t b = f32_to_bf16(2.0f);
    bf16_t c = f32_to_bf16(1.0f);

    TEST_ASSERT(bf16_eq(a, c), "Equality test failed");
    TEST_ASSERT(!bf16_eq(a, b), "Inequality test failed");

    TEST_ASSERT(bf16_lt(a, b), "Less than test failed");
    TEST_ASSERT(!bf16_lt(b, a), "Not less than test failed");
    TEST_ASSERT(!bf16_lt(a, c), "Equal not less than test failed");

    TEST_ASSERT(bf16_gt(b, a), "Greater than test failed");
    TEST_ASSERT(!bf16_gt(a, b), "Not greater than test failed");

    bf16_t nan_val = BF16_NAN();
    TEST_ASSERT(!bf16_eq(nan_val, nan_val), "NaN equality test failed");
    TEST_ASSERT(!bf16_lt(nan_val, a), "NaN less than test failed");
    TEST_ASSERT(!bf16_gt(nan_val, a), "NaN greater than test failed");

    printf("  Comparisons: PASS\n");
    return 0;
}

static int test_edge_cases(void)
{
    printf("Testing edge cases...\n");

    float tiny = 1e-45f;
    bf16_t bf_tiny = f32_to_bf16(tiny);
    float tiny_val = bf16_to_f32(bf_tiny);
    TEST_ASSERT(bf16_iszero(bf_tiny) || (tiny_val < 0 ? -tiny_val : tiny_val) < 1e-37f,
                "Tiny value handling");

    float huge = 1e38f;
    bf16_t bf_huge = f32_to_bf16(huge);
    bf16_t bf_huge2 = bf16_mul(bf_huge, f32_to_bf16(10.0f));
    TEST_ASSERT(bf16_isinf(bf_huge2), "Overflow should produce infinity");

    bf16_t small = f32_to_bf16(1e-38f);
    bf16_t smaller = bf16_div(small, f32_to_bf16(1e10f));
    float smaller_val = bf16_to_f32(smaller);
    TEST_ASSERT(bf16_iszero(smaller) || (smaller_val < 0 ? -smaller_val : smaller_val) < 1e-45f,
                "Underflow should produce zero or denormal");

    printf("  Edge cases: PASS\n");
    return 0;
}

static int test_rounding(void)
{
    printf("Testing rounding behavior...\n");

    float exact = 1.5f;
    bf16_t bf_exact = f32_to_bf16(exact);
    float back_exact = bf16_to_f32(bf_exact);
    TEST_ASSERT(back_exact == exact,
                "Exact representation should be preserved");

    float val = 1.0001f;
    bf16_t bf = f32_to_bf16(val);
    float back = bf16_to_f32(bf);
    float diff2 = back - val;
    TEST_ASSERT((diff2 < 0 ? -diff2 : diff2) < 0.001f, "Rounding error should be small");

    printf("  Rounding: PASS\n");
    return 0;
}

#ifndef BFLOAT16_NO_MAIN
int main(void)
{
    printf("\n=== bfloat16 Test Suite ===\n\n");

    int failed = 0;

    failed |= test_basic_conversions();
    failed |= test_special_values();
    failed |= test_arithmetic();
    failed |= test_comparisons();
    failed |= test_edge_cases();
    failed |= test_rounding();

    if (failed) {
        printf("\n=== TESTS FAILED ===\n");
        return 1;
    }

    printf("\n=== ALL TESTS PASSED ===\n");
    return 0;
}
#endif /* BFLOAT16_NO_MAIN */
```
:::
### Assembly Code
:::spoiler Assembly Code (Click to unfold)
```assembly=
.text
.global main
# ==============================
# Main function
# ==============================
main:
    la a0, str_bts
    li a7, 4         # syscall for print string
    ecall
    addi sp, sp, -8    # Allocate stack space
    sw ra, 0(sp)       # Save return address
    sw s0, 4(sp)       # Save s0
    li s0, 0           # s0 = success = 0
    jal test_basic_conversions
    or s0, s0, a0      # failed |= test_basic_conversions()
    jal test_special_values
    or s0, s0, a0      # failed |= test_special_values()
    jal test_arithmetic
    or s0, s0, a0      # failed |= test_arithmetic()
    jal test_comparisons
    or s0, s0, a0      # failed |= test_comparisons()
    jal test_edge_cases
    or s0, s0, a0      # failed |= test_edge_cases()
    jal test_rounding
    beq s0, zero, main.all_passed  # if failed == 0 goto all_passed
    la a0, str_tf
    li a7, 4         # syscall for print string
    ecall
    li a0, 1          # return 1
    lw s0, 4(sp)       # Restore s0
    lw ra, 0(sp)       # Restore return address
    addi sp, sp, 8     # Deallocate stack space
    li a7, 10  # exit code = 10
    ecall
main.all_passed:
    la a0, str_atp
    li a7, 4         # syscall for print string
    ecall
    lw ra, 0(sp)       # Restore return address
    lw s0, 4(sp)       # Restore s0
    addi sp, sp, 8     # Deallocate stack space
    li a7, 10  # exit code = 10
    ecall

# ===============================
# Function: int bf16_isnan(bf16_t a)
# ===============================
bf16_isnan:
    # Input: a0 = a.bits
    # Output: a0 = 1 if a is NaN, else 0
    li t0, 0x7f80
    and t1, a0, t0      # t1 = a.bit & 0x7f80
    beq t0, t1, bf16_isnan.skip1    # if t0 == t1 goto skip1
    li a0, 0                  # return false
    ret
bf16_isnan.skip1:
    andi t0, a0, 0x007f      # t0 = a.bit & 0x007f
    bne t0,zero, bf16_isnan.skip2  # if t0 != 0 goto skip2
    li a0, 0                  # return false
    ret
bf16_isnan.skip2:
    li a0, 1                  # return true
    ret

# ===============================
# Function: int bf16_isinf(bf16_t a)
# ===============================
bf16_isinf:
    # Input: a0 = a.bits
    # Output: a0 = 1 if a is Inf, else 0
    li t0, 0x7f80
    and t1, a0, t0      # t1 = a.bit & 0x7f80
    beq t1, t0, bf16_isinf.skip1    # if t1 == t0 goto skip1
    li a0, 0                  # return false
    ret
bf16_isinf.skip1:
    andi t0, a0, 0x007f      # t0 = a.bit &0x007f
    beq t0,zero, bf16_isinf.skip2  # if t0 == 0 goto skip2
    li a0, 0                  # return false
    ret
bf16_isinf.skip2:
    li a0, 1                  # return true
    ret

# ===============================
# Function: bf16_iszero(bf16_t a)
# ===============================
bf16_iszero:
    # Input: a0 = a.bits
    # Output: a0 = 1 if a is zero, else 0
    li t0, 0x7fff
    and a0, a0, t0      # a0 = a.bit & 0x7fff
    beq a0, zero, bf16_iszero.zero  # if a0 == 0 goto zero
    li a0, 0                  # return false
    ret
bf16_iszero.zero:
    li a0, 1                  # return true
    ret

# ===============================
# Function: f32_to_bf16(float val)
# ===============================
f32_to_bf16:
    # Input: a0 = float val
    # Output: a0 = bf16_t bits
    srli t0, a0, 23       # t0 = val >> 23
    andi t0, t0, 0xff     # t0 = (val >> 23) & 0xff
    li t1, 0xff          # t1 = dummy= 0xff
    bne t0, t1, f32_to_bf16.skip # if t0 != 0xff goto skip
    srli a0, a0, 16      # a0 = val >> 16
    li t1, 0xffff
    and a0, a0, t1  # a0 = (val >> 16) & 0xffff
    ret
f32_to_bf16.skip:
    srli t0, a0, 16       # t0 = val >> 16
    andi t0, t0, 1        # t0 = (val >> 16) & 1
    li t1, 0x7fff
    add t0, t0, t1   # t0 = ((val >> 16) & 1) + 0x7fff
    add a0, a0, t0       # a0 = val + t0
    srli a0, a0, 16      # a0 = (val + t0) >> 16
    ret

# ===============================
# Function: bf16_to_f32(bf16_t val)
# ===============================
bf16_to_f32:
    # Input: a0 = bf16_t bits
    # Output: a0 = float val
    slli a0, a0, 16      # a0 = val << 16
    ret

# ===============================
# Function: bf16_add(bf16_t a, bf16_t b)
# ===============================
bf16_add:
    # Input: a0 = a, a1 = b
    # Output: a0 = result
    srli t0, a0, 15       # t0 = a >> 15
    andi t0, t0, 1        # t0 = sign_a
    srli t1, a1, 15       # t1 = b >> 15
    andi t1, t1, 1        # t1 = sign_b
    srli t2, a0, 7        # t2 = a >> 7
    andi t2, t2, 0xff     # t2 = exp_a
    srli t3, a1, 7        # t3 = b >> 7
    andi t3, t3, 0xff     # t3 = exp_b
    andi t4, a0, 0x7f     # t4 = mant_a
    andi t5, a1, 0x7f     # t5 = mant_b
    li t6, 0xff           # t6 = dummy = 0xff
    bne t2, t6, bf16_add.skip1  # if exp_a != 0xff goto skip1
    beq t4, zero, bf16_add.skip1_1  # if mant_a == 0 goto skip1_1
    ret                     # return a
bf16_add.skip1_1:
    bne t3, t6, bf16_add.skip1_2  # if exp_b != 0xff goto skip1_2
    bne t5, zero, bf16_add.skip1_2_1  # if mant_b != 0 goto skip1_2_1
    beq t0, t1, bf16_add.skip1_2_1  # if sign_a == sign_b goto skip1_2_1
    li a0, 0x7fc0       # return NaN
    ret
bf16_add.skip1_2_1:
    mv a0, a1           # return b
    ret
bf16_add.skip1_2:
    ret
bf16_add.skip1:
    li t6, 0xff           # t6 = dummy = 0xff
    bne t3, t6, bf16_add.skip2  # if exp_b != 0xff goto skip2
    mv a0, a1          # return b
    ret
bf16_add.skip2:
    bne t2, zero, bf16_add.skip3  # if exp_a != 0 goto skip3
    bne t4, zero, bf16_add.skip3  # if mant_a != 0 goto skip3
    mv a0, a1          # return b
    ret
bf16_add.skip3:
    bne t3, zero, bf16_add.skip4  # if exp_b != 0 goto skip4
    bne t5, zero, bf16_add.skip4  # if mant_b != 0 goto skip4
    ret
bf16_add.skip4:
    beq t2, zero, bf16_add.skip5  # if exp_a == 0 goto skip5
    ori t4, t4, 0x80     # mant_a |= 0x80
bf16_add.skip5:
    beq t3, zero, bf16_add.skip6  # if exp_b == 0 goto skip6
    ori t5, t5, 0x80     # mant_b |= 0x80
bf16_add.skip6:
    sub t0, t2, t3     # exp_diff = exp_a - exp_b
    bge zero, t0, bf16_add.skip7  # if exp_diff <= 0 goto skip7
    mv t1, t2      # result_exp = exp_a
    li t6, 8          # t6 = dummy = 8
    bge t6, t0, bf16_add.skip7_1  # if exp_diff <= 8 goto skip7_1
    ret
bf16_add.skip7_1:
    srl t5, t5, t0     # mant_b >>= exp_diff
    j bf16_add.skip9
bf16_add.skip7:
    bge t0,zero, bf16_add.skip8  # if exp_diff >= 0 goto skip8
    mv t1, t3      # result_exp = exp_b
    li t6, -8         # t6 = dummy = -8
    bge t0, t6, bf16_add.skip8_1  # if exp_diff >= -8 goto skip8_1
    mv a0, a1      # return b
    ret
bf16_add.skip8_1:
    sub t0, zero, t0    # t0 = -exp_diff (現在為正)
    srl t4, t4, t0      # mant_a >>= |exp_diff|
    j bf16_add.skip9
bf16_add.skip8:
    mv t1, t2      # result_exp = exp_a
bf16_add.skip9:
    srli t2, a0, 15       # t2 = a >> 15
    andi t2, t2, 1        # t2 = sign_a
    srli t3, a1, 15       # t3 = b >> 15
    andi t3, t3, 1        # t3 = sign_b
    bne t2, t3, bf16_add.skip10  # if sign_a != sign_b goto skip10
    mv a1, t2      # a1 =result_sign = sign_a
    add a0, t4, t5     # a0 = result_mant = mant_a + mant_b
    andi t6, a0, 0x100  # t6 = result_mant & 0x100
    beq t6, zero, bf16_add.skip11  # if t6 == 0 goto skip10_1
    srli a0, a0, 1      # result_mant >>= 1
    addi t1, t1, 1     # result_exp += 1
    li t6, 0xff       # t6 = dummy = 0xff
    blt t1, t6, bf16_add.skip11  # if result_exp < 0xff goto skip10
    slli a1 ,a1,15      # a1 = result_sign << 15
    li t6, 0x7f80       # t6 = dummy = 0x7f80
    or a0, a1, t6      # return (result_sign << 15) | 0x7f80
    ret
bf16_add.skip10:
    blt t4, t5, bf16_add.skip11_1  # if mant_a < mant_b goto skip11_1
    mv a1, t2      # a1 = result_sign = sign_a
    sub a0, t4, t5     # a0 = result_mant = mant_a - mant_b
    j bf16_add.skip11_2
bf16_add.skip11_1:
    mv a1, t3      # a1 = result_sign = sign_b
    sub a0, t5, t4     # a0 = result_mant = mant_b - mant_a
bf16_add.skip11_2:
    bne a0, zero, bf16_add.loop  # if result_mant != 0 goto loop
    li a0, 0x0000      # return 0
    ret
bf16_add.loop:
    andi t6, a0, 0x80   # t6 = result_mant & 0x80
    bne t6, zero, bf16_add.skip11  # if t6 != 0 goto skip11
    slli a0, a0, 1      # result_mant <<= 1
    addi t1, t1, -1     # result_exp -= 1
    blt zero, t1, bf16_add.loop  # if result_exp >= 0 goto loop
    li a0, 0x0000       # return 0
    ret
bf16_add.skip11:
    slli a1 ,a1,15      # a1 = result_sign << 15
    andi t1, t1, 0xff   # t1 = result_exp & 0xff
    slli t1, t1, 7      # t1 = (result_exp & 0xff) << 7
    andi a0, a0, 0x7f   # a0 = result_mant & 0x7f
    or t6, a1, t1      # t6 = (result_sign << 15) | (result_exp & 0xff) << 7
    or a0, t6, a0      # return (result_sign << 15) | (result_exp & 0xff) << 7 | (result_mant & 0x7f)
    ret

# ===============================
# Function: bf16_sub(bf16_t a, bf16_t b)
# ===============================
bf16_sub:
    # Input: a0 = a, a1 = b
    # Output: a0 = result
    li t6, 0x8000
    xor a1, a1, t6   # b.bits ^= 0x8000
    addi sp, sp, -4     # Allocate stack space
    sw ra, 0(sp)        # Save return address
    jal bf16_add      # Call bf16_add
    lw ra, 0(sp)        # Restore return address
    addi sp, sp, 4      # Deallocate stack space
    ret

# ===============================
# Function: bf16_mul(bf16_t a, bf16_t b)
# ===============================
bf16_mul:
    # Input: a0 = a, a1 = b
    # Output: a0 = result
    srli t0, a0, 15       # t0 = a >> 15
    andi t0, t0, 1        # t0 = sign_a
    srli t1, a1, 15       # t1 = b >> 15
    andi t1, t1, 1        # t1 = sign_b
    srli t2, a0, 7        # t2 = a >> 7
    andi t2, t2, 0xff     # t2 = exp_a
    andi t4, a0, 0x7f     # t4 = mant_a
    xor t1, t0, t1        # t1 = result_sign = sign_a ^ sign_b
    li t6, 0xff           # t6 = dummy = 0xff
    bne t2, t6, bf16_mul.skip1  # if exp_a != 0xff goto skip1
    beq t4, zero, bf16_mul.skip1_1  # if mant_a == 0 goto skip1_1
    ret
bf16_mul.skip1_1:
    srli t3, a1, 7        # t3 = b >> 7
    andi t3, t3, 0xff     # t3 = exp_b
    andi t5, a1, 0x7f     # t5 = mant_b
    bne t3, zero, bf16_mul.skip1_2  # if exp_b != 0 goto skip1_2
    beq t5, zero, bf16_mul.skip1_2  # if mant_b == 0 goto skip1_2
    li a0, 0x7fc0       # return NaN
    ret
bf16_mul.skip1_2:
    slli a0, t1, 15     # a0 = result_sign << 15
    li  t6, 0x7f80
    or a0, a0, t6       # return (result_sign << 15) | 0x7f80
    ret
bf16_mul.skip1:
    li t6, 0xff           # t6 = dummy = 0xff
    bne t3, t6, bf16_mul.skip2  # if exp_b != 0xff goto skip2
    beq t5, zero, bf16_mul.skip2_1 # if mant_b == 0 goto skip2_1
    mv a0, a1          # return b
    ret
bf16_mul.skip2_1:
    bne t2, zero, bf16_mul.skip2_2  # if exp_a != 0 goto skip2_2
    beq t4, zero, bf16_mul.skip2_2  # if mant_a == 0 goto skip2_2
    li a0, 0x7fc0       # return NaN
    ret
bf16_mul.skip2_2:
    slli a0, t1, 15     # a0 = result_sign << 15
    li t6, 0x7f80
    or a0, a0, t6       # return (result_sign << 15) | 0x7f80
    ret
bf16_mul.skip2:
    bne t2, zero, bf16_mul.skip3_1  # if exp_a != 0 goto skip3_1
    beq t4, zero, bf16_mul.skip3_1  # if mant_a == 0 goto skip3
    slli a0, t1, 15     # a0 = result_sign << 15
    ret
bf16_mul.skip3_1:
    bne t3, zero, bf16_mul.skip3_2  # if exp_b != 0 goto skip3_2
    beq t5, zero, bf16_mul.skip3_2  # if mant_b == 0 goto skip3
    slli a0, t1, 15     # a0 = result_sign << 15
    ret
bf16_mul.skip3_2:
    li a0, 0      # a0 = exp_adjust = 0
    bne t2, zero, bf16_mul.skip4_2  # if exp_a != 0 goto skip4_2
bf16_mul.loop1:
    andi t6, t4, 0x80   # t6 = mant_a & 0x80
    bne t6, zero, bf16_mul.skip4_1  # if t6 != 0 goto skip4_1
    slli t4, t4, 1      # mant_a <<= 1
    addi a0, a0, -1     # exp_adjust -= 1
    j bf16_mul.loop1
bf16_mul.skip4_1:
    li t2, 1         # exp_a = 1
    j bf16_mul.skip4
bf16_mul.skip4_2:
    ori t4, t4, 0x80     # mant_a |= 0x80
bf16_mul.skip4:
    bne t3, zero, bf16_mul.skip5_2 # if exp_b != 0 goto skip5_2
bf16_mul.loop2:
    andi t6, t5, 0x80   # t6 = mant_b & 0x80
    bne t6, zero, bf16_mul.skip5_1  # if t6 != 0 goto skip5_1
    slli t5, t5, 1      # mant_b <<= 1
    addi a0, a0, -1     # exp_adjust -= 1
    j bf16_mul.loop2
bf16_mul.skip5_1:
    li t3, 1         # exp_b = 1
    j bf16_mul.skip5
bf16_mul.skip5_2:
    ori t5, t5, 0x80     # mant_b |= 0x80
bf16_mul.skip5:
    mv t0, t4        # t0 = Multiplicand (M)
    mv t1, t5        # t1 = Multiplier (Q)
    li a1, 0         # a1 = Product (P), initialized to 0
    li t6, 0         # i = 0 (loop counter)
    li t4, 16        # t4 = dummy = 16
bf16_mul.mul_loop:
    bge t6, t4, bf16_mul.mul_end
    andi t5, t1, 1
    beq t5, zero, bf16_mul.skip_add
    add a1, a1, t0
    add a1, a1, t0   # If LSB is 1, add multiplicand (t0) to product (a1)
bf16_mul.skip_add:
    slli t0, t0, 1   # Shift multiplicand (t0) left by 1
    srli t1, t1, 1   # Shift multiplier (t1) right by 1
    addi t6, t6, 1
    j bf16_mul.mul_loop
bf16_mul.mul_end:
    add a0, a0, t2     # result_exp = exp_adjust + exp_a
    add a0, a0, t3     # result_exp = exp_adjust + exp
    addi a0, a0, -127  # result_exp -= 127
    li t6, 0x8000
    and t6, a1, t6  # t6 = result_mant & 0x8000
    beq t6, zero, bf16_mul.skip6_1  # if t6 == 0 goto skip6_1
    srli a1, a1, 8      # result_mant >>= 8
    andi a1, a1, 0x7f    # result_mant &= 0x7f
    addi a0, a0, 1       # result_exp += 1
    j bf16_mul.skip6
bf16_mul.skip6_1:
    srli a1, a1, 7      # result_mant >>= 7
    andi a1, a1, 0x7f    # result_mant &= 0x7f
bf16_mul.skip6:
    li t6, 0xff         # t6 = dummy = 0xff
    blt a0, t6, bf16_mul.skip7  # if result_exp < 0xff goto skip7
    slli a0, t1, 15     # a0 = result_sign << 15
    li t6, 0x7f80
    or a0, a0, t6       # return (result_sign << 15) | 0x7f80
    ret
bf16_mul.skip7:
    blt zero, a0, bf16_mul.skip8  # if result_exp >= 0 goto skip8
    li t6, -6        # t6 = dummy = -6
    bge a0, t6, bf16_mul.skip8_1  # if result_exp >= -6 goto skip8_1
    slli a0, t1, 15     # a0 = result_sign << 15
    ret
bf16_mul.skip8_1:
    li t6, 1        # t6 = dummy = 1
    sub t6, t6, a0     # t6 = 1 - result_exp
    srl a1, a1, t6     # result_mant >>= (1 - result_exp)
    li a0, 0        # result_exp = 0
bf16_mul.skip8:
    slli t1, t1, 15     # t1 = result_sign << 15
    andi a0, a0, 0xff   # a0 = result_exp & 0xff
    slli a0, a0, 7     # a0 = (result_exp & 0xff) << 7
    andi a1, a1, 0x7f   # a1 = result_mant & 0x7f
    or a0, t1, a0    # a0 = (result_sign << 15) | (result_exp & 0xff) << 7
    or a0, a0, a1    # return (result_sign << 15) | (result_exp & 0xff) << 7 | (result_mant & 0x7f)
    ret

# ===============================
# Function: bf16_div(bf16_t a, bf16_t b)
# ===============================
bf16_div:
    # Input: a0 = a, a1 = b
    # Output: a0 = result
    srli t0, a0, 15       # t0 = a >> 15
    andi t0, t0, 1        # t0 = sign_a
    srli t1, a1, 15       # t1 = b >> 15
    andi t1, t1, 1        # t1 = sign_b
    srli t3, a1, 7        # t3 = b >> 7
    andi t3, t3, 0xff     # t3 = exp_b
    andi t5, a1, 0x7f     # t5 = mant_b
    xor t0, t0, t1        # t0 = result_sign = sign_a ^ sign_b
    li t6, 0xff           # t6 = dummy = 0xff
    bne t3, t6, bf16_div.skip1  # if exp_b != 0xff goto skip1
    beq t5, zero, bf16_div.skip1_1  # if mant_b == 0 goto skip1_1
    mv a0, a1          # return b
    ret
bf16_div.skip1_1:
    srli t2, a0, 7        # t2 = a >> 7
    andi t2, t2, 0xff     # t2 = exp_a
    andi t4, a0, 0x7f     # t4 = mant_a
    bne t2, t6, bf16_div.skip1_2  # if exp_a != 0xff goto skip1_2
    bne t4, zero, bf16_div.skip1_2  # if mant_a != 0 goto skip1_2
    li a0, 0x7fc0       # return NaN
    ret
bf16_div.skip1_2:
    slli a0, t0, 15     # a0 = result_sign << 15
    ret
bf16_div.skip1:
    bne t3, zero, bf16_div.skip2  # if exp_b != 0 goto skip2
    bne t5, zero, bf16_div.skip2  # if mant_b != 0 goto skip2
    bne t2, zero, bf16_div.skip2_1  # if exp_a != 0 goto skip2_1
    bne t4, zero, bf16_div.skip2_1  # if mant_a != 0 goto skip2_1
    li a0, 0x7fc0       # return NaN
    ret
bf16_div.skip2_1:
    slli a0, t0, 15     # a0 = result_sign << 15
    li t6, 0x7f80       # t6 = dummy = 0x7f80
    or a0, a0, t6       # return (result_sign << 15) | 0x7f80
    ret
bf16_div.skip2:
    li t6, 0xff           # t6 = dummy = 0xff
    bne t2, t6, bf16_div.skip3   # if exp_a != 0xff goto skip3
    beq t4, zero, bf16_div.skip3_1  # if mant_a == 0 goto skip3_1
    ret
bf16_div.skip3_1:
    slli a0, t0, 15     # a0 = result_sign << 15
    li t6, 0x7f80       # t6 = dummy = 0x7f80
    or a0, a0, t6       # return (result_sign << 15) | 0x7f80
    ret
bf16_div.skip3:
    bne t2, zero, bf16_div.skip4_1  # if exp_a != 0 goto skip4_1
    bne t4, zero, bf16_div.skip4_1  # if mant_a != 0 goto skip4_1
    slli a0, t0, 15     # a0 = result_sign << 15
    ret
bf16_div.skip4_1:
    beq t2, zero ,bf16_div.skip4 # if exp_a != 0 goto skip4
    ori t4, t4, 0x80     # mant_a |= 0x80
bf16_div.skip4:
    beq t3, zero, bf16_div.skip5  # if exp_b != 0 goto skip5
    ori t5, t5, 0x80     # mant_b |= 0x80
bf16_div.skip5:
    slli t4, t4, 15     # dividend = mant_a <<= 15
    li a1, 0        # quotient = 0
    li t6, 0        # i = 0
    li a0, 16       # a0 = dummy = 16
bf16_div.loop1:
    bge t6, a0, bf16_div.loop1_end  # if i >= 16 goto loop1_end
    slli a1, a1, 1      # quotient <<= 1
    li t1, 15       # t1 = dummy = 15
    sub t1, t1, t6     # t1 = 15 - i
    sll t1, t5, t1     # t1 = divisor << (15 - i)
    blt t4, t1, bf16_div.skip_sub  # if dividend < t1 goto skip_sub
    sub t4, t4, t1     # dividend -= t1
    ori a1, a1, 1      # quotient |= 1
bf16_div.skip_sub:
    addi t6, t6, 1    # i++
    j bf16_div.loop1
bf16_div.loop1_end:
    sub t1, t2, t3     # result_exp = exp_a - exp_b
    addi t1, t1, 127   # result_exp += 127
    bne t2, zero, bf16_div.skip6 # if exp_a != 0 goto skip6
    addi t1, t1, -1    # result_exp -= 1
bf16_div.skip6:
    bne t3, zero, bf16_div.skip7 # if exp_b != 0 goto skip7
    addi t1, t1, 1    # result_exp += 1
bf16_div.skip7:
    li t6, 0x8000
    and t6, a1, t6   # t6 = quotient & 0x8000
    beq t6, zero, bf16_div.loop2  # if t6 == 0 goto loop2
    srli a1, a1, 8      # quotient >>= 8
    j bf16_div.skip8
bf16_div.loop2:
    li t6, 0x8000
    and t6, a1, t6  # t6 = quotient & 0x8000
    bne t6, zero, bf16_div.loop2_end  # if t6 != 0 goto loop2_end
    li t6, 1       # t6 = dummy = 1
    bge t6, t1, bf16_div.loop2_end  # if 1 >= result_exp goto loop2_end
    slli a1, a1, 1      # quotient <<= 1
    addi t1, t1, -1     # result_exp -= 1
    j bf16_div.loop2
bf16_div.loop2_end:
    srli a1, a1, 8      # quotient >>= 8
bf16_div.skip8:
    andi a1, a1, 0x7f    # quotient &= 0x7f
    li t6, 0xff         # t6 = dummy = 0xff
    blt t1, t6, bf16_div.skip9  # if result_exp < 0xff goto skip9
    slli a0, t0, 15     # a0 = result_sign << 15
    li t6, 0x7f80       # t6 = dummy = 0x7f80
    or a0, a0, t6       # return (result_sign << 15) | 0x7f80
    ret
bf16_div.skip9:
    blt zero, t1, bf16_div.skip10  # if result_exp >= 0 goto skip10
    li t6, -6        # t6 = dummy = -6
    bge t1, t6, bf16_div.skip9_1  # if result_exp >= -6 goto skip9_1
    slli a0, t0, 15     # a0 = result_sign << 15
    ret
bf16_div.skip9_1:
    li t6, 1        # t6 = dummy = 1
    sub t6, t6, t1     # t6 = 1 - result_exp
    srl a1, a1, t6     # quotient >>= (1 - result_exp)
bf16_div.skip10:
    slli t0, t0, 15     # t0 = result_sign << 15
    andi t1, t1, 0xff   # t1 = result_exp & 0xff
    slli t1, t1, 7     # t1 = (result_exp & 0xff) << 7
    andi a1, a1, 0x7f   # a1 = quotient & 0x7f
    or a0, t0, t1    # a0 = (result_sign << 15) | (result_exp & 0xff) << 7
    or a0, a0, a1     # return (result_sign << 15) | (result_exp & 0xff) << 7 | (quotient & 0x7f)
    ret

# ================================
# Function: bf16_sqrt(bf16_t a)
# ================================
bf16_sqrt:
    # Input: a0 = a
    # Output: a0 = result
    srli t0, a0, 15       # t0 = sign = a >> 15
    andi t0, t0, 1        # t0 = sign = (a >> 15) & 1
    srli t1, a0, 7        # t1 = exp = a >> 7
    andi t1, t1, 0xff     # t1 = exp = (a >> 7) & 0x7f
    andi t2, a0, 0x7f     # t2 = mant = a & 0x7f
    li t6, 0xff           # t6 = dummy = 0xff
    bne t1, t6, bf16_sqrt.skip1  # if exp != 0xff goto skip1
    beq t2, zero, bf16_sqrt.skip1_1  # if mant == 0 goto skip1_1
    ret                     # return a
bf16_sqrt.skip1_1:
    beq t0, zero, bf16_sqrt.skip1_2  # if sign == 0 goto skip1_2
    li a0, 0x7fc0       # return NaN
    ret
bf16_sqrt.skip1_2:
    ret
bf16_sqrt.skip1:
    bne t1, zero, bf16_sqrt.skip2  # if exp != 0 goto skip2
    bne t2, zero, bf16_sqrt.skip2  # if mant != 0 goto skip2
    li a0, 0x0000      # return 0
    ret
bf16_sqrt.skip2:
    beq t0, zero, bf16_sqrt.skip3  # if sign == 0 goto skip3
    li a0, 0x7fc0       # return NaN
    ret
bf16_sqrt.skip3:
    bne t1, zero, bf16_sqrt.skip4  # if exp != 0 goto skip4
    li a0, 0x0000      # return 0
    ret
bf16_sqrt.skip4:
    addi a0, t1, -127  # a0 = e = exp - 127
    ori t2, t2,0x80  # t2 = m = mant |= 0x80
    andi t6, a0, 1     # t6 = e & 1
    beq t6, zero, bf16_sqrt.skip5_1  # if t6 == 0 goto skip5_1
    slli t2, t2, 1     # m <<= 1
    addi t1, a0, -1   # t1 = new_exp = e - 1
    srai t1, t1, 1    # new_exp = (e - 1) >> 1
    addi t1, t1, 127  # new_exp += 127
    j bf16_sqrt.skip5
bf16_sqrt.skip5_1:
    srai t1, a0, 1    # new_exp = e >> 1
    addi t1, t1, 127  # new_exp += 127
bf16_sqrt.skip5:
    li a0, 90      # a0 = low = 90
    li t0, 256     # t0 = high = 256
    li t3, 128    # t3 = result = 128
    addi sp, sp, -8     # Allocate stack space
    sw s0, 0(sp)        # Save s0
    sw s1, 4(sp)        # Save return address
bf16_sqrt.loop1:
    blt t0, a0, bf16_sqrt.loop1_end  # if high < low goto loop1_end
    add t4, a0, t0   # t4 = mid = (low + high)
    srli t4, t4, 1  # mid = (low + high) >> 1
    mv t0, t4        # t0 = Multiplicand (被乘數)
    mv t1, t4        # t1 = Multiplier (乘數)
    li t5, 0         # t5 = Product (積), initialized to 0
    li t6, 0         # t6 = loop counter i = 0
bf16_sqrt.mul_loop:
    li s0, 16        # Loop 16 times for up to 16-bit numbers
    bge t6, s0, bf16_sqrt.mul_end

    # Check LSB of Multiplier (t1)
    andi s0, t1, 1
    beq s0, zero, bf16_sqrt.skip_add

    # If LSB is 1, add Multiplicand (t0) to Product (t5)
    add t5, t5, t0

bf16_sqrt.skip_add:
    # Shift Multiplicand left for the next position
    slli t0, t0, 1
    # Shift Multiplier right to check the next bit
    srli t1, t1, 1
    addi t6, t6, 1    # i++
    j bf16_sqrt.mul_loop

bf16_sqrt.mul_end:
    # At this point, t5 holds the full result of mid * mid
    srli t5, t5, 7     # sq = (mid * mid) / 128
    blt t2, t5, bf16_sqrt.skip6_1  # if m < sq goto skip6_1
    mv t3, t4      # result = mid
    addi a0, t4, 1   # low = mid + 1
    j bf16_sqrt.skip6
bf16_sqrt.skip6_1:
    addi t0, t4, -1   # high = mid - 1
bf16_sqrt.skip6:
    j bf16_sqrt.loop1
bf16_sqrt.loop1_end:
    lw s1, 4(sp)        # Restore s1
    lw s0, 0(sp)        # Restore s0
    addi sp, sp, 8      # Deallocate stack space
    li t6, 256     # t6 = dummy = 256
    blt t3, t6, bf16_sqrt.skip7_1  # if result < 256 goto skip7
    srli t3, t3, 1    # result >>= 1
    addi t1, t1, 1   # new_exp += 1
    j bf16_sqrt.skip7
bf16_sqrt.skip7_1:
    li t6, 128   # t6 = dummy = 128
    bge t3, t6, bf16_sqrt.skip7  # if result >= 128 goto skip7
bf16_sqrt.loop2:
    bge t3, t6, bf16_sqrt.skip7  # if result >= 128 goto skip7
    li t4, 1       # t4 = dummy = 1
    bge t4, t1, bf16_sqrt.skip7  # if 1 >= new_exp goto skip7
    slli t3, t3, 1     # result <<= 1
    addi t1, t1, -1    # new_exp -= 1
    j bf16_sqrt.loop2
bf16_sqrt.skip7:
    andi a0, t3, 0x7f  # result_mant = result & 0x7f
    li t6, 0xff        # t6 = dummy = 0xff
    blt t1, t6, bf16_sqrt.skip8  # if new_exp < 0xff goto skip8
    li a0, 0x7f80      # return 0x7f80
    ret
bf16_sqrt.skip8:
    blt zero, t1, bf16_sqrt.skip9  # if new_exp >= 0 goto skip9
    li a0, 0x0000      # return
    ret
bf16_sqrt.skip9:
    andi t1, t1, 0xff   # new_exp = new_exp & 0xff
    slli t1, t1, 7      # new_exp = (new_exp & 0xff) << 7
    or a0, a0, t1     # a0 = (new_exp & 0xff) << 7 | new_mant
    ret

# ===============================
# Function: bf16_eq(bf16_t a, bf16_t b)
# ===============================
bf16_eq:
    # Input: a0 = a, a1 = b
    # Output: a0 = result (1 if a == b else 0)
    addi sp, sp, -8     # Allocate stack space
    sw ra, 0(sp)        # Save return address
    sw s0, 4(sp)        # Save s0
    mv s0, a0      # s0 = a
    jal bf16_isnan   # Call bf16_isnan(a)
    bne a0, zero, bf16_eq.false  # if isnan(a) return 0
    mv a0, a1      # a0 = b
    jal bf16_isnan   # Call bf16_isnan(b)
    beq a0, zero, bf16_eq.not_nan  # if !isnan(b) goto not_nan
bf16_eq.not_nan:
    mv a0, s0      # a0 = a
    jal bf16_iszero  # Call bf16_iszero(a)
    beq a0, zero, bf16_eq.not_zero  # if !iszero(a) goto not_zero
    mv a0, a1      # a0 = b
    jal bf16_iszero  # Call bf16_iszero(b)
    beq a0, zero, bf16_eq.not_zero  # if !iszero(b) goto not_zero
    j bf16_eq.true  # both are zero, return 1
bf16_eq.not_zero:
    beq s0, a1, bf16_eq.true  # if a == b
bf16_eq.false:
    li a0, 0        # return 0
    lw s0, 4(sp)        # Restore s0
    lw ra, 0(sp)        # Restore return address
    addi sp, sp, 8      # Deallocate stack space
    ret
bf16_eq.true:
    li a0, 1        # return 1
    lw s0, 4(sp)        # Restore s0
    lw ra, 0(sp)        # Restore return address
    addi sp, sp, 8      # Deallocate stack space
    ret

# ===============================
# Function: bf16_lt(bf16_t a, bf16_t b)
# ===============================
bf16_lt:
    # Input: a0 = a, a1 = b
    # Output: a0 = result (1 if a < b else 0)
    addi sp, sp, -16     # Allocate stack space
    sw ra, 0(sp)        # Save return address
    sw s0, 4(sp)        # Save s0
    sw s1, 8(sp)        # Save s1
    sw s2, 12(sp)       # Save s2
    mv s0, a0      # s0 = a
    jal bf16_isnan   # Call bf16_isnan(a)
    bne a0, zero, bf16_lt.false  # if isnan(a) return 0
    mv a0, a1      # a0 = b
    jal bf16_isnan   # Call bf16_isnan(b)
    bne a0, zero, bf16_lt.false  # if isnan(b) goto nan
    mv a0, s0      # a0 = a
    jal bf16_iszero  # Call bf16_iszero(a)
    beq a0, zero, bf16_lt.not_zero  # if !iszero(a) goto not_zero
    mv a0, a1      # a0 = b
    jal bf16_iszero  # Call bf16_iszero(b)
    beq a0, zero, bf16_lt.not_zero  # if !iszero(b) goto not_zero
bf16_lt.not_zero:
    srli s1, s0, 15  # s1 = sign_a = a >> 15
    andi s1, s1, 1    # s1 = sign_a = (a >> 15) & 1
    srli s2, a1, 15  # s2 = sign_b = b >> 15
    andi s2, s2, 1    # s2 = sign_b = (b >> 15) & 1
    beq s1, s2, bf16_lt.same_sign  # if sign_a == sign_b goto same_sign
    bge s2, s1, bf16_lt.false  # if sign_a <= sign_b goto less
    j bf16_lt.true  # return 1
bf16_lt.same_sign:
    beq s1, zero, bf16_lt.positive  # if sign_a == 0 goto positive
    bge a1, s0, bf16_lt.false  # if b >= a goto less
    j bf16_lt.true  # return 1
bf16_lt.positive:
    bge s0, a1, bf16_lt.false  # if a >= b goto less
bf16_lt.true:
    li a0, 1       # return 1
    lw s2, 12(sp)       # Restore s2
    lw s1, 8(sp)        # Restore s1
    lw s0, 4(sp)        # Restore s0
    lw ra, 0(sp)        # Restore return address
    addi sp, sp, 16      # Deallocate stack space
    ret
bf16_lt.false:
    li a0, 0       # return 0
    lw s2, 12(sp)       # Restore s2
    lw s1, 8(sp)        # Restore s1
    lw s0, 4(sp)        # Restore s0
    lw ra, 0(sp)        # Restore return address
    addi sp, sp, 16      # Deallocate stack space
    ret

# ===============================
# Function: bf16_gt(bf16_t a, bf16_t b)
# ===============================
bf16_gt:
    # Input: a0 = a, a1 = b
    # Output: a0 = result (1 if a > b else 0)
    addi sp, sp, -4     # Allocate stack space
    sw ra, 0(sp)        # Save return address
    xor a0, a0, a1       # a0 = a ^ b
    xor a1, a0, a1       # a1 = b ^ (a ^ b) = a
    xor a0, a0, a1       # a0 = (a ^ b) ^ a = b
    jal bf16_lt  # Call bf16_lt(b, a)
    lw ra, 0(sp)        # Restore return address
    addi sp, sp, 4      # Deallocate stack space
    ret


# ============================================================================
# Test functions
# ============================================================================

# ==============================
# Function: test_basic_conversions(void)
# ==============================
test_basic_conversions:
    la a0, str_tbc
    li a7, 4          # syscall for print string
    ecall
    addi sp, sp, -24    # Allocate stack space
    sw ra, 0(sp)       # Save return address
    sw s0, 4(sp)       # Save s0
    sw s1, 8(sp)       # Save s1
    sw s2, 12(sp)      # Save s2
    sw s3, 16(sp)      # Save s3
    sw s4, 20(sp)      # Save s4
    li s0, 0          # i = 0
    li s1, 11         # num_test_val = 11
    la s2, test_values  # load address of test_values
test_basic_conversions.loop:
    bge s0, s1, test_basic_conversions.loop_end  # if i >= num_test_val goto loop_end
    lw s3, 0(s2)     # s3 = orig = load test_values[i]
    mv a0, s3       # a0 = orig
    jal f32_to_bf16 # Call f32_to_bf16(orig)
    mv s4, a0      # s4 = bf = f32_to_bf16(orig)
    jal bf16_to_f32 # Call bf16_to_f32(bf)
    mv t0, a0     # t0 = conv = bf16_to_f32(bf)
    beq s3, zero, test_basic_conversions.skip1  # if orig == 0 goto skip1
    srli t1, s3, 31         # t1 = sign of orig (s3)
    srli t2, t0, 31         # t2 = sign of conv (t0)
    beq t1, t2, test_basic_conversions.skip1 # TEST ASSERTION
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_sm
    ecall 
    li a0, 1
    j test_basic_conversions.end
test_basic_conversions.skip1:
    beq s3, zero, test_basic_conversions.skip2  # if orig == 0 goto skip2
    mv a0, s4      # a0 = bf
    jal bf16_isinf  # Call bf16_isinf(bf)
    bne a0, zero, test_basic_conversions.skip2  # if isinf(bf) goto skip2
    la t6, test_upper # load address of test_upper
    slli t1, s0, 2     # t1 = i * 4
    add t6, t6, t1     # t6 = &test_upper[i]
    lw a0, 0(t6)   # a0 = test_upper[i]
    la t6, test_lower # load address of test_lower
    add t6, t6, t1   # t6 = &test_lower[i]
    lw t2, 0(t6)   # t2 = test_lower[i]
    blt t2, t0, test_basic_conversions.skip2  # if test_lower[i] < conv goto skip2
    blt t0, a0, test_basic_conversions.skip2  # if conv < test_upper[i] goto skip2
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_retl
    ecall 
    li a0, 1
    j test_basic_conversions.end
test_basic_conversions.skip2:
    addi s0, s0, 1   # i++
    addi s2, s2, 4   # s2 = &test_values[i]
    j test_basic_conversions.loop
test_basic_conversions.loop_end:
    la a0, str_bcp
    li a7, 4          # syscall for print string
    ecall 
    li a0, 0          # return 0
test_basic_conversions.end:
    lw s4, 20(sp)      # Restore s4
    lw s3, 16(sp)      # Restore s3
    lw s2, 12(sp)      # Restore s2
    lw s1, 8(sp)       # Restore s1
    lw s0, 4(sp)       # Restore s0
    lw ra, 0(sp)       # Restore return address
    addi sp, sp, 24      # Deallocate stack space
    ret

# ==============================
# Function: test_special_values(void)
# ==============================
test_special_values:
    la a0, str_tsv
    li a7, 4          # syscall for print string
    ecall
    addi sp, sp, -4    # Allocate stack space
    sw ra, 0(sp)       # Save return address
    li t0, 0x7f80  # pos_inf = 0x7f80
    mv a0, t0      # a0 = pos_inf
    jal bf16_isinf  # Call bf16_isinf(pos_inf)
    bne a0, zero, test_special_values.test_assert1 # TEST ASSERTION
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_pind
    ecall 
    li a0, 1
    lw ra, 0(sp)       # Restore return address
    addi sp, sp, 4      # Deallocate stack space
    ret
test_special_values.test_assert1:
    mv a0, t0      # a0 = pos_inf
    jal bf16_isnan  # Call bf16_isnan(pos_inf)
    beq a0, zero, test_special_values.test_assert2 # TEST ASSERTION
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_idan
    ecall 
    li a0, 1
    lw ra, 0(sp)       # Restore return address
    addi sp, sp, 4      # Deallocate stack space
    ret
test_special_values.test_assert2:
    li a0, 0xff80  # neg_inf = 0xff80
    jal bf16_isinf  # Call bf16_isinf(neg_inf)
    bne a0, zero, test_special_values.test_assert3 # TEST ASSERTION
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_nind
    ecall 
    li a0, 1
    lw ra, 0(sp)       # Restore return address
    addi sp, sp, 4      # Deallocate stack space
    ret
test_special_values.test_assert3:
    li t0, 0x7fc0  # nan = 0x7fc0
    mv a0, t0      # a0 = nan
    jal bf16_isnan  # Call bf16_isnan(nan)
    bne a0, zero, test_special_values.test_assert4 # TEST ASSERTION
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_nnd
    ecall 
    li a0, 1
    lw ra, 0(sp)       # Restore return address
    addi sp, sp, 4      # Deallocate stack space
    ret
test_special_values.test_assert4:
    mv a0, t0      # a0 = nan
    jal bf16_isinf  # Call bf16_isinf(nan)
    beq a0, zero, test_special_values.test_assert5 # TEST ASSERTION
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_ndai
    ecall 
    li a0, 1
    lw ra, 0(sp)       # Restore return address
    addi sp, sp, 4      # Deallocate stack space
    ret
test_special_values.test_assert5:
    li a0, 0x0000  # pos_zero = 0x000
    jal bf16_iszero  # Call bf16_iszero(pos_zero)
    bne a0, zero, test_special_values.test_assert6 # TEST ASSERTION
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_znd
    ecall 
    li a0, 1
    lw ra, 0(sp)       # Restore return address
    addi sp, sp, 4      # Deallocate stack space
    ret
test_special_values.test_assert6:
    li a0, 0x8000  # neg_zero = 0x800
    jal bf16_iszero  # Call bf16_iszero(neg_zero)
    bne a0, zero, test_special_values.test_assert7 # TEST ASSERTION
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_nznd
    ecall 
    li a0, 1
    lw ra, 0(sp)       # Restore return address
    addi sp, sp, 4      # Deallocate stack space
    ret
test_special_values.test_assert7:
    lw ra, 0(sp)       # Restore return address
    addi sp, sp, 4      # Deallocate stack space
    la a0, str_svp
    li a7, 4         # syscall for print string
    ecall
    li a0, 0          # return 0
    ret

# ==============================
# Function: test_arithmetic(void)
# ==============================
test_arithmetic:
    la a0, str_tao
    li a7, 4         # syscall for print string
    ecall
    addi sp, sp, -24  # Allocate stack space
    sw ra, 0(sp)      # Save return address
    sw s0, 4(sp)      # Save s0
    sw s1, 8(sp)      # Save s1
    sw s2, 12(sp)     # Save s2
    sw s3, 16(sp)     # Save s3
    sw s4, 20(sp)     # Save s4
    li a0, 0x3f800000 # f1 = 1.0f
    jal f32_to_bf16  # Call f32_to_bf16(1.0f)
    la s0, test_arith_values  # load address of test_arith_values
    la s1, test_arith_upper  # load address of test_arith_upper
    la s2, test_arith_lower  # load address of test_arith_lower
    lw a0, 0(s0)   # a0 = test_arith_values[0]
    jal f32_to_bf16  # Call f32_to_bf16(test_arith_values[0])
    mv s3, a0      # s3 = a = f32_to_bf16(test_arith_values[0])
    lw a0, 4(s0)   # a0 = test_arith_values[1]
    jal f32_to_bf16  # Call f32_to_bf16
    mv s4, a0      # s4 = b = f32_to_bf16(test_arith_values[1])
    mv a0, s3      # a0 = a
    mv a1, s4      # a1 = b
    jal bf16_add  # Call bf16_add(a, b)
    mv t0, a0     # t0 = c = bf16_add(a, b)
    lw t1, 0(s1)   # t1 = test_arith_upper[0]
    lw t2, 0(s2)   # t2 = test_arith_lower[0]
    blt t2, t0, test_arithmetic.skip1  # if test_arith_lower[0] < c goto skip1
    blt t0, t1, test_arithmetic.skip1  # if c < test_arith_upper[0] goto skip1
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_af
    ecall 
    li a0, 1
    j test_arithmetic.end
test_arithmetic.skip1:
    mv a0, s4      # a0 = b
    mv a1, s3      # a1 = a
    jal bf16_sub  # Call bf16_sub(b, a)
    mv t0, a0     # t0 = c = bf16_sub(b, a)
    lw t1, 4(s1)   # t1 = test_arith_upper[1]
    lw t2, 4(s2)   # t2 = test_arith_lower[1]
    blt t2, t0, test_arithmetic.skip2  # if test_arith_lower[1] < c goto skip2
    blt t0, t1, test_arithmetic.skip2  # if c < test_arith_upper[1] goto skip2
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_sf
    ecall 
    li a0, 1
    j test_arithmetic.end
test_arithmetic.skip2:
    lw a0, 8(s0)   # a0 = test_arith_values[2]
    jal f32_to_bf16  # Call f32_to_bf16
    mv s3, a0      # s3 = a = f32_to_bf16(test_arith_values[2])
    mv a0, s3      # a0 = a
    mv a1, s4      # a1 = b
    jal bf16_div  # Call bf16_div(a, b)
    mv t0, a0     # t0 = c = bf16_div(a, b)
    lw t1, 8(s1)   # t1 = test_arith_upper[2]
    lw t2, 8(s2)   # t2 = test_arith_lower[2]
    blt t2, t0, test_arithmetic.skip3  # if test_arith_lower[2] < c goto skip3
    blt t0, t1, test_arithmetic.skip3  # if c < test_arith_upper[2] goto skip3
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_df
    ecall 
    li a0, 1
    j test_arithmetic.end
test_arithmetic.skip3:
    lw a0, 16(s0)   # a0 = test_arith_values[4]
    jal f32_to_bf16  # Call f32_to_bf16
    mv s4, a0      # s4 = b = f32_to_bf16(test_arith_values[4])
    lw a0, 12(s0)   # a0 = test_arith_values[3]
    jal f32_to_bf16  # Call f32_to_bf16
    mv s3, a0      # s3 = a = f32_to_bf16(test_arith_values[3])
    mv a1, s4      # a1 = b
    jal bf16_mul  # Call bf16_mul(a, b)
    mv t0, a0     # t0 = c = bf16_mul(a, b)
    lw t1, 12(s1)   # t1 = test_arith_upper
    lw t2, 12(s2)   # t2 = test_arith_lower
    blt t2, t0, test_arithmetic.skip4  # if test_arith_lower < c goto skip4
    blt t0, t1, test_arithmetic.skip4  # if c < test_arith_upper goto skip4
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_mf
    ecall 
    li a0, 1
    j test_arithmetic.end
test_arithmetic.skip4:
    mv a0, s4      # a0 = b
    jal bf16_sqrt  # Call bf16_sqrt(b)
    mv t0, a0     # t0 = c = bf16_sqrt(b)
    lw t1, 16(s1)   # t1 = test_arith_upper
    lw t2, 16(s2)   # t2 = test_arith_lower
    blt t2, t0, test_arithmetic.skip5  # if test_arith_lower < c goto skip5
    blt t0, t1, test_arithmetic.skip5  # if c < test_arith_upper goto skip5
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_sqrt4
    ecall 
    li a0, 1
    j test_arithmetic.end
test_arithmetic.skip5:
    lw a0, 20(s0)   # a0 = test_arith_values[5]
    jal f32_to_bf16  # Call f32_to_bf16
    mv s3, a0      # s3 = a = f32_to_bf16(test_arith_values[5])
    mv a0, s3      # a0 = a
    jal bf16_sqrt  # Call bf16_sqrt(a)
    mv t0, a0     # t0 = c = bf16_sqrt(a)
    lw t1, 20(s1)   # t1 = test_arith_upper
    lw t2, 20(s2)   # t2 = test_arith_lower
    blt t2, t0, test_arithmetic.skip6  # if test_arith_lower < c goto skip6
    blt t0, t1, test_arithmetic.skip6  # if c < test_arith_upper goto skip6
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_sqrt9
    ecall 
    li a0, 1
    j test_arithmetic.end
test_arithmetic.skip6:
    la a0, str_ap
    li a7, 4         # syscall for print string
    ecall
    li a0, 0          # return 0
test_arithmetic.end:
    lw s4, 20(sp)     # Restore s4
    lw s3, 16(sp)     # Restore s3
    lw s2, 12(sp)     # Restore s2
    lw s1, 8(sp)      # Restore s1
    lw s0, 4(sp)      # Restore s0
    lw ra, 0(sp)      # Restore return address
    addi sp, sp, 24     # Deallocate stack space
    ret

# ==============================
# Function: test_comparisons(void)
# ==============================
test_comparisons:
    la a0, str_tco
    li a7, 4         # syscall for print string
    ecall
    addi sp, sp, -16  # Allocate stack space
    sw ra, 0(sp)      # Save return address
    sw s0, 4(sp)      # Save s0
    sw s1, 8(sp)      # Save s1
    sw s2, 12(sp)     # Save s2
    li a0, 0x40000000 # f2 = 2.0f
    jal f32_to_bf16  # Call f32_to_bf16(2)
    mv s1, a0       # s1 = b = f32_to_bf16(2.0f)
    li a0, 0x3f800000 # f1 = 1.0f
    jal f32_to_bf16  # Call f32_to_bf16(1.0f)
    mv s2, a0       # s2 = c = f32_to_bf16(1.0f)
    li a0, 0x3f800000 # f1 = 1.0f
    jal f32_to_bf16  # Call f32_to_bf16(1.0f)
    mv s0, a0       # s0 = a = f32_to_bf16(1.0f)
    mv a1, s2      # a1 = c
    jal bf16_eq  # Call bf16_eq(a, c)
    bne a0, zero, test_comparisons.test_assert1 # TEST ASSERTION
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_etf
    ecall 
    li a0, 1
    j test_comparisons.end
test_comparisons.test_assert1:
    mv a0, s0      # a0 = a
    mv a1, s1      # a1 = b
    jal bf16_eq  # Call bf16_eq(a, b)
    beq a0, zero, test_comparisons.test_assert2 # TEST ASSERTION
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_itf
    ecall 
    li a0, 1
    j test_comparisons.end
test_comparisons.test_assert2:
    mv a0, s0      # a0 = a
    mv a1, s1      # a1 = b
    jal bf16_lt  # Call bf16_lt(a, b)
    bne a0, zero, test_comparisons.test_assert3 # TEST ASSERTION
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_lttf
    ecall 
    li a0, 1
    j test_comparisons.end
test_comparisons.test_assert3:
    mv a0, s1      # a0 = b
    mv a1, s0      # a1 = a
    jal bf16_lt  # Call bf16_lt(b, a)
    beq a0, zero, test_comparisons.test_assert4 # TEST ASSERTION
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_nlttf
    ecall 
    li a0, 1
    j test_comparisons.end
test_comparisons.test_assert4:
    mv a0, s0      # a0 = a
    mv a1, s2      # a1 = c
    jal bf16_lt  # Call bf16_lt(a, c)
    beq a0, zero, test_comparisons.test_assert5 # TEST ASSERTION
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_enlttf
    ecall
    li a0, 1
    j test_comparisons.end
test_comparisons.test_assert5:
    mv a0, s1      # a0 = b
    mv a1, s0      # a1 = a
    jal bf16_gt  # Call bf16_gt(b, a)
    bne a0, zero, test_comparisons.test_assert6 # TEST ASSERTION
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_gttf
    ecall
    li a0, 1
    j test_comparisons.end
test_comparisons.test_assert6:
    mv a0, s0      # a0 = a
    mv a1, s1      # a1 = b
    jal bf16_gt  # Call bf16_gt(a, b)
    beq a0, zero, test_comparisons.test_assert7 # TEST ASSERTION
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_ngttf
    ecall
    li a0, 1
    j test_comparisons.end
test_comparisons.test_assert7:
    li s2, 0x7fc0  # nan = 0x7fc0
    mv a0, s2      # a0 = nan
    mv a1, s2      # a1 = nan
    jal bf16_eq  # Call bf16_eq(nan, nan)
    beq a0, zero, test_comparisons.test_assert8 # TEST ASSERTION
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_netf
    ecall
    li a0, 1
    j test_comparisons.end
test_comparisons.test_assert8:
    mv a0, s2      # a0 = nan
    mv a1, s0      # a1 = a
    jal bf16_lt  # Call bf16_lt(nan, a)
    beq a0, zero, test_comparisons.test_assert9 # TEST ASSERTION
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_nanlttf
    ecall
    li a0, 1
    j test_comparisons.end
test_comparisons.test_assert9:
    mv a0, s2      # a0 = nan
    mv a1, s0      # a1 = a
    jal bf16_gt  # Call bf16_gt(nan, a)
    beq a0, zero, test_comparisons.test_assert10 # TEST ASSERTION
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_nangttf
    ecall
    li a0, 1
    j test_comparisons.end
test_comparisons.test_assert10:
    li a7, 4         # syscall for print string
    la a0, str_cp
    ecall
    li a0, 0          # return 0
test_comparisons.end:
    lw s2, 12(sp)     # Restore s2
    lw s1, 8(sp)      # Restore s1
    lw s0, 4(sp)      # Restore s0
    lw ra, 0(sp)       # Restore return address
    addi sp, sp, 16      # Deallocate stack space
    ret

# ==============================
# Function: test_edge_cases(void)x
# ==============================
test_edge_cases:
    la a0, str_tec
    li a7, 4         # syscall for print string
    ecall
    addi sp, sp, -16 # Allocate stack space
    sw ra, 0(sp)      # Save return address
    sw s0, 4(sp)      # Save s0
    sw s1, 8(sp)      # Save s1
    sw s2, 12(sp)      # Save s2
    la s0, test_edge_values
    lw a0, 0(s0)   # a0 = tiny = test_edge_values[0]
    jal f32_to_bf16  # Call f32_to_bf16
    mv s1, a0      # s1 = bf_tiny = f32_to_bf16(tiny)
    jal bf16_to_f32 # Call bf16_to_f32(bf_tiny)
    mv s2, a0     # t0 = tiny_val = bf16_to_f32(bf_tiny)
    mv a0, s1      # a0 = bf_tiny
    jal bf16_iszero  # Call bf16_iszero(bf_tiny)
    bne a0, zero, test_edge_cases.skip1 # if iszero(bf_tiny) goto skip1
    lw a0, 4(s0)   # a0  = test_edge_values[1]
    li t0, 0x7fffffff
    and s2, s2, t0   # s2 = abs(tiny_val)
    blt s2, a0, test_edge_cases.skip1  # if tiny_val < small goto skip1
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_tvh
    ecall 
    li a0, 1
    j test_edge_cases.end
test_edge_cases.skip1:
    lw a0, 12(s0)   # a0 = huge = test_edge_values[3]
    jal f32_to_bf16  # Call f32_to_bf16
    mv s1, a0      # s1 = bf_huge = f32_to_bf16(huge)
    lw a0, 16(s0)   # a0 = test_edge_values[4]
    jal f32_to_bf16  # Call f32_to_bf16
    mv a1, a0      # a1  = f32_to_bf16(test_edge_values[4])
    mv a0, s1      # a0 = bf_huge
    jal bf16_mul  # Call bf16_mul(bf_huge, f32_to_bf16(test_edge_values[4]))
    jal bf16_isinf  # Call bf16_isinf(bf_huge2)
    bne a0, zero, test_edge_cases.skip2 # if isinf(bf_huge) goto skip2
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_ospi
    ecall 
    li a0, 1
    j test_edge_cases.end
test_edge_cases.skip2:
    lw a0, 8(s0)   # a0 = small = test_edge_values[2]
    jal f32_to_bf16  # Call f32_to_bf16
    mv s1, a0      # s1 = small = f32_to_bf16(test_edge_values[2])
    lw a0, 20(s0)   # a0 = test_edge_values[5]
    jal f32_to_bf16  # Call f32_to_bf16
    mv a1, a0      # a1  = f32_to_bf16(test_edge_values[5])
    mv a0, s1      # a0 = small
    jal bf16_div  # Call bf16_div(small, f32_to_bf16(test_edge_values[5]))
    mv s1, a0      # s1 = smaller
    jal bf16_to_f32 # Call bf16_to_f32(smaller)
    mv s2, a0     # s2 = small_val
    mv a0, s1      # a0 = smaller
    jal bf16_iszero  # Call bf16_iszero(smaller)
    bne a0, zero, test_edge_cases.skip3 # if iszero(smaller) goto skip3
    lw a0, 0(s0)   # a0  = test_edge_values[0]
    li t0, 0x7fffffff
    and s2, s2, t0   # s2 = abs(small_val)
    blt a0, s2, test_edge_cases.skip3  # if small_val < test_edge_values[0] goto skip3
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_uspzod
    ecall 
    li a0, 1
    j test_edge_cases.end
test_edge_cases.skip3:
    la a0, str_ecp
    li a7, 4         # syscall for print string
    ecall
    li a0, 0          # return 0
test_edge_cases.end:
    lw s2, 12(sp)     # Restore s2
    lw s1, 8(sp)      # Restore s1
    lw s0, 4(sp)      # Restore s0
    lw ra, 0(sp)      # Restore return address
    addi sp, sp, 16     # Deallocate stack space
    ret

# ==============================
# Function: test_rounding(void)
# ==============================
test_rounding:
    la a0, str_trb
    li a7, 4         # syscall for print string
    ecall
    addi sp, sp, -12  # Allocate stack space
    sw ra, 0(sp)       # Save return address
    sw s0, 4(sp)       # Save s0
    sw s1, 8(sp)       # Save s1
    la s0, test_round_values  # load address of test_round_values
    lw s1, 0(s0)   # s1 = exact = test_round_values[0]
    mv a0, s1      # a0 = exact
    jal f32_to_bf16  # Call f32_to_bf16(test_round_values[0])
    jal bf16_to_f32 # Call bf16_to_f32
    beq a0, s1, test_rounding.skip1  # if back_exact == exact goto next1
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_ersbp
    ecall 
    li a0, 1
    j test_rounding.end
test_rounding.skip1:
    lw a0, 4(s0)   # a0 = val = test_round_values[1]
    jal f32_to_bf16  # Call f32_to_bf16(test_round_values[1])
    jal bf16_to_f32 # Call bf16_to_f32
    la s1, test_round_bounds  # load address of test_round_bounds
    lw t0, 0(s1)   # t0 = lower = test_round_bounds[0]
    blt t0, a0, test_rounding.skip2  # if lower < back goto skip2
    lw t0, 4(s1)   # t0 = upper = test_round_bounds[1]
    blt a0, t0, test_rounding.skip2  # if back < upper goto skip2
    la a0, str_f
    li a7, 4
    ecall
    la a0, str_resbs
    ecall 
    li a0, 1
    j test_rounding.end
test_rounding.skip2:
    la a0, str_rp
    li a7, 4         # syscall for print string
    ecall
    li a0, 0          # return 0
test_rounding.end:
    lw s1, 8(sp)      # Restore s1
    lw s0, 4(sp)      # Restore s0
    lw ra, 0(sp)      # Restore return address
    addi sp, sp, 12     # Deallocate stack space
    ret


# ============================================================================
# data section
# ============================================================================
.data
test_values: .word 0x00000000, 0x3F800000, 0xBF800000, 0x40000000, 0xC0000000, 0x3F000000, 0xBF000000, 0x40490FDB, 0xC0490FDB, 0x501502F9, 0xD01502F9 # 0.0f, 1.0f, -1.0f, 2.0f, -2.0f, 0.5f, -0.5f, 3.14159f, -3.14159f, 1e10f, -1e10f
test_upper: .word 0x00000000, 0x3F8147AE, 0xBF8147AE, 0x400147AE, 0xC00147AE, 0x3F0147AE, 0xBF0147AE, 0x404B1287, 0xC04B1287, 0x50168071, 0xD0168071 # 0.0f, 1.01f, -1.01f, 2.02f, 2.02f, 0.505f, 0.505f,3.1730059f, -3.1730059f, 1.01e10f, -1.01e10f
test_lower: .word 0x00000000, 0x3F7D70A4, 0xBF7D70A4, 0x3FFD70A4, 0xCFFD70A4, 0x3EFD70A4, 0xBEFD70A4, 0x40470D18, 0xC0470D18, 0x50138581, 0xD0138581 # 0.0f, 0.99f, -0.99f, 1.98f, -1.98f, 0.495f, -0.495f, 3.1101747f, -3.1101747f, 9.9e9f, -9.9e9f

test_arith_values: .word 0x3f800000, 0x40000000, 0x41200000, 0x40400000, 0x40800000, 0x41100000  # 1.0, 2.0, 10.0, 3.0, 4.0, 9.0
test_arith_upper: .word 0x4040a3d7, 0x3f8147ae, 0x40a33333, 0x4141999a, 0x4000a3d7, 0x4040a3d7 # 3.01f, 1.01f, 5.1f, 12.1f, 2.01f, 3.01f
test_arith_lower: .word 0x403f5c29, 0x3f7d70a4, 0x409ccccd, 0x413e6666, 0x3ffeb852, 0x403f5c29 # 2.99f, 0.99f, 4.9f, 11.9f, 0.99f, 2.99f

test_edge_values: .word 0x00000001, 0x02081cea, 0x006ce3ee, 0x7e967699, 0x41200000, 0x501502f9  # 1e-45f, 1e-37f, 1e-38f, 1e38f, 10.0f, 1e10f

test_round_values: .word 0x3fc00000, 0x3f800347 # 1.5f, 1.0001f
test_round_bounds: .word 0x3f7fc505, 0x3f80240b # 0.9991f, 1.0011f

str_f: .string "FAIL: "
str_tbc: .string "Testing basic conversions...\n"
str_sm: .string "Sign mismatch"
str_retl: .string "Relative error too large"
str_bcp: .string "  Basic conversions: PASS\n"
str_tsv: .string "Testing special values...\n"
str_pind: .string "Positive infinity not detected"
str_idan: .string "Infinity detected as NaN"
str_nind: .string "Negative infinity not detected"
str_nnd: .string "NaN not detected"
str_ndai: .string "NaN detected as infinity"
str_znd: .string "Zero not detected"
str_nznd: .string "Negative zero not detected"
str_svp: .string "  Special values: PASS\n"
str_tao: .string "Testing arithmetic operations...\n"
str_af: .string "Addition failed"
str_sf: .string "Subtraction failed"
str_mf: .string "Multiplication failed"
str_df: .string "Division failed"
str_sqrt4: .string "sqrt(4) failed"
str_sqrt9: .string "sqrt(9) failed"
str_ap: .string "  Arithmetic: PASS\n"
str_tco: .string "Testing comparisons operations...\n"
str_etf: .string "Equality test failed"
str_itf: .string "Inequality test failed"
str_lttf: .string "Less than test failed"
str_nlttf: .string "Not less than test failed"
str_enlttf: .string "Equal not less than test failed"
str_gttf: .string "Greater than test failed"
str_ngttf: .string "Not greater than test failed"
str_netf: .string "NaN equality test failed"
str_nanlttf: .string "NaN less than test failed"
str_nangttf: .string "NaN greater than test failed"
str_cp: .string "  Comparisons: PASS\n"
str_tec: .string "Testing edge cases...\n"
str_tvh: .string "Tiny value handling"
str_ospi: .string "Overflow should produce infinity"
str_uspzod: .string "Underflow should produce zero or denormal"
str_ecp: .string "  Edge cases: PASS\n"
str_trb: .string "Testing rounding behavior...\n"
str_ersbp: .string "Exact representation should be preserved"
str_resbs: .string "Rounding error should be small"
str_rp: .string "  Rounding: PASS\n"
str_bts: .string "\n=== bfloat16 Test Suite ===\n\n"
str_tf: .string "\n=== TESTS FAILED ===\n"
str_atp: .string "\n=== ALL TESTS PASSED ===\n"
```
:::
### Test Result
![image](https://hackmd.io/_uploads/S1zK6Q5Tgg.png)




| Console |Compiled C code |RISC-V Assembly |
| -------- | -------- | -------- |
| ![image](https://hackmd.io/_uploads/HkZzYYwall.png)   | ![image](https://hackmd.io/_uploads/HyRz5twTgl.png)  | ![image](https://hackmd.io/_uploads/BydJqFv6xg.png)|

## Leetcode [#190 Reverse Bits](https://leetcode.com/problems/reverse-bits)
Using [clz](https://hackmd.io/0mzMhln2To2AGMOu9rz3Pg?view#clz-optimization) helps locate the highest significant bit, so we only reverse the effective bit range and pad the leading zeros afterward, reducing unnecessary loops and computations.
### Description
Reverse bits of a given 32 bits signed integer.

* **Example 1:**

    Input: n = `43261596`
    Output: `964176192`

    **Explanation:**
    
    Integer	Binary
    |43261596	|00000010100101000001111010011100|
    |----|----|
    |**964176192**	|**00111001011110000010100101000000**|

* **Example 2:**

    Input: n = `2147483644`
    Output: `1073741822`
    
    **Explanation:**
    
    Integer	Binary
    |2147483644	|01111111111111111111111111111100|
    |----|----|
    |**1073741822**	|**00111111111111111111111111111110**|
### Original Code
#### C code
```clike=
int reverseBits(int n) {
    uint32_t ans = 0;
    for (int i = 0; i < 32; i++){
        ans <<= 1;
        ans += n % 2;
        n >>= 1;
    }
    return ans;
}
```
#### Assembly
```assembly=
reverse_bits:
    # Input: a0 = 32-bit unsigned integer
    # Output: a0 = reversed 32-bit unsigned integer
    li t0, 0          # t0 = ans = 0
    li t1, 0          # t1 = i = 0
    li t2, 32         # t2 = 32
reverse_bits.loop:
    bge t1, t2, reverse_bits.end  # if (i >= 32) goto end
    slli t0, t0, 1    # ans <<= 1
    andi t3, a0, 1    # t3 = n & 1 = n % 2
    add t0, t0, t3    # ans += n % 2
    srli a0, a0, 1    # n >>= 1
    addi t1, t1, 1    # i += 1
    j reverse_bits.loop
reverse_bits.end:
    mv a0, t0         # return ans
    ret
```
### Optimize with `clz`
#### C code
```clike=
#include <stdint.h>

static inline unsigned clz(uint32_t x) {
    int n = 32, c = 16;
    do {
        uint32_t y = x >> c;
        if (y) {
            n -= c;
            x = y;
        }
        c >>= 1;
    } while (c);
    return n - x;
}

uint32_t reverseBits(uint32_t n) {
    if (n == 0) return 0;

    uint32_t ans = 0;
    int zeros = clz(n);
    int bits = 32 - zeros;
    for (int i = 0; i < bits; i++) {
        ans <<= 1;
        ans |= (n & 1);
        n >>= 1;
    }
    ans <<= zeros;
    return ans;
}
```
#### Assembly
```assembly=
clz:
    # Input: a0 = 32-bit unsigned integer.
    # Output: a0 = number of leading zeros in x's binary representation
    li t0, 32    # n = t0 = 32
    li t1, 16    # c = t1 = 16
clz.loop:
    srl t2, a0, t1    # y = t2 = x >> c
    beq t2, zero, clz.skip    # if (y == 0) goto clz.skip
    sub t0, t0, t1    # n -= c
    mv a0, t2   # x = y
clz.skip:
    srli t1, t1, 1
    bne t1, zero, clz.loop # while (c != 0) goto clz.loop
    sub a0, t0, a0    # return n - x
    ret

reverse_bits:
    # Input: a0 = 32-bit unsigned integer
    # Output: a0 = 32-bit unsigned integer with bits reversed
    beq a0, zero, reverse_bits.end  # if (n == 0) return 0
    mv t6, a0        # t6 = n
    addi sp, sp, -4  # Allocate stack space
    sw ra, 0(sp)     # Save return address
    jal clz          # clz(n)
    lw ra, 0(sp)     # Restore return address
    addi sp, sp, 4   # Deallocate stack space
    li t1, 32        # t1 = 32
    sub t1, t1, a0   # a0 = bits = 32 - zeros
    li t2, 0        # t2 = ans = 0
    li t3, 0        # t3 = i = 0
reverse_bits.loop:
    bge t3, t1, reverse_bits.end_loop  # if (i >= bits) goto end_loop
    slli t2, t2, 1    # ans <<= 1
    andi t4, t6, 1    # t4 = n & 1
    or t2, t2, t4     # ans |= (n & 1)
    srli t6, t6, 1    # n >>= 1
    addi t3, t3, 1    # i++
    j reverse_bits.loop
reverse_bits.end_loop:
    sll t2, t2, a0     # ans <<= zeros
    mv a0, t2         # return ans
reverse_bits.end:
    ret
```
#### Assembly (Optimized with loop unrolling)
```assembly=
clz:
    # Input: a0 = 32-bit unsigned integer.
    # Output: a0 = number of leading zeros in x's binary representation
    li t0, 32           # n = t0 = 32
    srli t2, a0, 16      # y = t2 = x >> 16
    beq t2, zero, clz.L_c8 # if (y == 0) goto clz.L_c8
    addi t0, t0, -16      # n -= 16
    mv a0, t2           # x = y
clz.L_c8:
    srli t2, a0, 8       # y = t2 = x >> 8
    beq t2, zero, clz.L_c4 # if (y == 0) goto clz.L_c4
    addi t0, t0, -8       # n -= 8
    mv a0, t2           # x = y
clz.L_c4:
    srli t2, a0, 4       # y = t2 = x >> 4
    beq t2, zero, clz.L_c2 # if (y == 0) goto clz.L_c2
    addi t0, t0, -4       # n -= 4
    mv a0, t2           # x = y
clz.L_c2:
    srli t2, a0, 2       # y = t2 = x >> 2
    beq t2, zero, clz.L_c1 # if (y == 0) goto .L_c1
    addi t0, t0, -2       # n -= 2
    mv a0, t2           # x = y
clz.L_c1:
    srli t2, a0, 1       # y = t2 = x >> 1
    beq t2, zero, clz.L_final # if (y == 0) goto clz.L_final
    addi t0, t0, -1       # n -= 1
    mv a0, t2           # x = y
clz.L_final:
    sub a0, t0, a0      # return n - x
    ret
reverse_bits:
    # Input: a0 = 32-bit unsigned integer
    # Output: a0 = 32-bit unsigned integer with bits reversed
    beq a0, zero, reverse_bits.end  # if (n == 0) return 0
    mv t6, a0        # t6 = n
    addi sp, sp, -4  # Allocate stack space
    sw ra, 0(sp)     # Save return address
    jal clz          # clz(n)
    lw ra, 0(sp)     # Restore return address
    addi sp, sp, 4   # Deallocate stack space
    li t1, 32        # t1 = 32
    sub t1, t1, a0   # a0 = bits = 32 - zeros
    li t2, 0        # t2 = ans = 0
    li t3, 0        # t3 = i = 0
reverse_bits.loop:
    bge t3, t1, reverse_bits.end_loop  # if (i >= bits) goto end_loop
    slli t2, t2, 1    # ans <<= 1
    andi t4, t6, 1    # t4 = n & 1
    or t2, t2, t4     # ans |= (n & 1)
    srli t6, t6, 1    # n >>= 1
    addi t3, t3, 1    # i++
    j reverse_bits.loop
reverse_bits.end_loop:
    sll t2, t2, a0     # ans <<= zeros
    mv a0, t2         # return ans
reverse_bits.end:
    ret
```


|                   | Best Case reverse_bits(0)| Worst Case reverse_bits(0x80000000) |
| ----------------- | ------------------------- | ----------------------------------- |
| ***Original Assembly*** | ![image](https://hackmd.io/_uploads/ByqGkNtTge.png)| ![image](https://hackmd.io/_uploads/ByqGkNtTge.png)|
| ***With `clz` Assembly***|![image](https://hackmd.io/_uploads/rkjbeNK6lx.png)|![image](https://hackmd.io/_uploads/H1IVbNt6xg.png)
|
| ***With Unrolled `clz` Assembly***|![image](https://hackmd.io/_uploads/rkjbeNK6lx.png)|![image](https://hackmd.io/_uploads/SkhkZVF6lx.png)|


## Analysis
We test our code using [Ripes](https://github.com/mortbopet/Ripes) simulator.

### 5-stage pipelined processor
The RISC-V 5-stage pipelined processor is an efficient CPU architecture that breaks down the execution of a single instruction into five independent stages, known as Pipelining. It allows multiple instructions to be in different stages of execution simultaneously, with the primary goal of dramatically increasing processor throughput to achieve an ideal performance of one completed instruction per clock cycle.
Bolck diagram of a RISC-V 5-stage pipelined processor is below:
![image](https://hackmd.io/_uploads/BJt7lPCnge.png)

**The Five Classic Stages**

* `IF (Instruction Fetch)`
Reads an instruction from memory.
* `ID (Instruction Decode)`
Decodes the instruction's function and reads the required register values.
* `EX (Execute)`
The Arithmetic Logic Unit (ALU) performs the core computation or address calculation.
* `MEM (Memory Access)`
Performs a read (load) or write (store) operation to data memory.
* `WB (Write Back)`
Writes the operation's result back to a destination register.

To demonstrate how a five-stage pipelined processor works, we will trace the execution of addi t0, x0, 32—the first instruction in the clz function—as it moves through the five stages: Instruction Fetch, Decode, Execute, Memory Access, and Write Back.

1. IF
    ![iShot_2025-10-11_14.49.23](https://hackmd.io/_uploads/BJ3Hy5wTxe.png)
    * The PC holds the address of the current instruction, which is 0x00000004.
    * Instruction Memory: The processor fetches the 32-bit machine code for the instruction, 0x02000293, from this memory address.
    * Simultaneously, the PC is incremented by 4 (0x00000004 + 4) to calculate the address of the next instruction (0x00000008) for the following clock cycle.
    * The fetched instruction 0x02000293 and the updated PC value are passed to the IF/ID pipeline register.

2. ID
    ![iShot_2025-10-11_14.51.08](https://hackmd.io/_uploads/rJa8JqDTee.png)
    * The control unit decodes the instruction 0x02000293 from the IF/ID register and identifies it as an ADDI (Add Immediate) operation.
    * The decoder identifies the first source register (rs1) as x0 (index 0x00) and reads the value of x0, which is 0x00000000, from the Register File.
    * The immediate value 32 is extracted from the instruction and sign-extended to its 32-bit representation, 0x00000020.
    * The value of x0 (0x00000000), the immediate value (0x00000020), the destination register index x5 (index 0x05), and the necessary ALU control signals are passed to the ID/EX pipeline register.

3. EX
    ![iShot_2025-10-11_14.51.42](https://hackmd.io/_uploads/rknvycD6ee.png)
    * A multiplexer (MUX) selects the value of x0 (0x00000000) from the ID/EX register as the first input to the ALU.
    * Another MUX selects the immediate value 0x00000020 as the second input to the ALU.
    * ALU performs an addition operation based on the control signals.
    * Computes 0x00000000 + 0x00000020, yielding the result 0x00000020.
    * 0x00000020 and the destination register index x5 are passed to the EX/MEM pipeline register.

4. MEM
    ![iShot_2025-10-11_14.52.10](https://hackmd.io/_uploads/Sku_J5Dagl.png)
    * Since addi is an arithmetic instruction and not a load or store, it performs no read or write operations on the data memory in this stage.
    * The memory's Write Enable signal is de-asserted (inactive, shown in red), so no data is written. Any value read from memory (like 0x00038513) is ignored.
    * The ALU result from the EX/MEM register (0x00000020) is simply passed through this stage to the MEM/WB pipeline register.

5. Write Back (WB)
    ![iShot_2025-10-11_14.53.00](https://hackmd.io/_uploads/r11Yy9vTee.png)
    * A MUX selects the source of the data to be written into the register file. For an addi instruction, it chooses the result from the ALU (0x00000020), not a value read from data memory.
    * The selected data 0x00000020 is written into the register file.
    * The destination register is identified by the index 0x05 (for x5), which is passed from the MEM/WB register.
    * register x5 has been updated with the value 32.
## References
* [Quiz1 of Computer Architecture (2025 Fall)](/9YLc_YfrT6ue-v2zQacNfQ)
* [RISC-V Instruction Set Manual](https://riscv.org/specifications/ratified/)
* [RISC-V Assembly Programmer’s Manual](https://github.com/riscv-non-isa/riscv-asm-manual/blob/main/src/asm-manual.adoc)
* [Leetcode #190](https://leetcode.com/problems/reverse-bits)