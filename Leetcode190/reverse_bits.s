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