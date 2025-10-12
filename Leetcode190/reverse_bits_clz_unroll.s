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
