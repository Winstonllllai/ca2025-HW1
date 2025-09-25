.data

.text
# ===============================
# Function: int bf16_isnan(bf16_t a)
# ===============================
bf16_isnan:
    # Input: a0 = a.bits
    # Output: a0 = 1 if a is NaN, else 0
    andi t0, a0, 0x7f80      # t0 = a.bit &0x7f80
    li t1, 0x7f80            # t1 = 0x7f80
    beq t0, t1, bf16_isnan.skip1    # if t0 == t1 goto skip1
    li a0, 0                  # return false
    ret
bf16_isnan.skip1:
    andi t0, a0, 0x007f      # t0 = a.bit &0x007f
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
    andi t0, a0, 0x7f80      # t0 = a.bit &0x7f80
    li t1, 0x7f80            # t1 = 0x7f80
    beq t0, t1, bf16_isnan.skip1    # if t0 == t1 goto skip1
    li a0, 0                  # return false
    ret
bf16_isnan.skip1:
    andi t0, a0, 0x007f      # t0 = a.bit &0x007f
    beq t0,zero, bf16_isnan.skip2  # if t0 == 0 goto skip2
    li a0, 0                  # return false
    ret
bf16_isnan.skip2:
    li a0, 1                  # return true
    ret

# ===============================
# Function: bf16_iszero(bf16_t a)
# ===============================
bf16_iszero:
    # Input: a0 = a.bits
    # Output: a0 = 1 if a is zero, else 0
    andi a0, a0, 0x7fff      # a0 = a.bit & 0x7fff
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
    andi a0, a0, 0xffff  # a0 = (val >> 16) & 0xffff
    ret
f32_to_bf16.skip:
    srli t0, a0, 16       # t0 = val >> 16
    andi t0, t0, 1        # t0 = (val >> 16) & 1
    addi t0, t0, 0x7fff   # t0 = ((val >> 16) & 1) + 0x7fff
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
    bne t3, t6, bf16_add.skip1_2  # if exp_b == 0xff goto skip1_2
    or t6, t5, t1        # t6 = mant_b | sign_a
    bne t6, t1, bf16_add.skip1_2_1  # if t6 != sign_a goto skip1_2_1
    mv a0, a1           # return b
    ret
bf16_add.skip1_2_1:
    li a0, 0x7fc0       # return NaN
    ret
bf16_add.skip1_2:
    ret
bf16_add.skip1:
    li t6, 0xff           # t6 = dummy = 0xff
    bne t3, t6, bf16_add.skip2  # if exp_b
    mv a0, a1          # return b
    ret
bf16_add.skip2:
    bne t2, zero, bf16_add.skip3  # if exp_a != 0 goto skip3
    bne t4, zero, bf16_add.skip3  # if mant_a != 0 goto skip3
    mv a0, a1          # return b
    ret
bf16_add.skip3:
    bne t3, zero, bf16_add.skip4  # if exp_b !=
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
    blt t0,zero, bf16_add.skip7  # if exp_diff < 0 goto skip7
    mv t1, t2      # result_exp = exp_a
    li t6, 8          # t6 = dummy = 8
    bge t0, t6, bf16_add.skip7_1  # if exp_diff >= 8 goto skip7_1
    ret
bf16_add.skip7_1:
    srl t5, t5, t0     # mant_b >>= exp_diff
    j bf16_add.skip9
bf16_add.skip7:
    bge t0,zero, bf16_add.skip8  # if exp_diff >= 0 goto skip8
    mv t1, t3      # result_exp = exp_b
    li t6, -8         # t6 = dummy = -8
    bge t0, t6, bf16_add.skip7_2  # if exp_diff >= -8 goto skip7_2
    mv a0, a1      # return b
    ret
bf16_add.skip8_1:
    srl t4, t4, -t0    # mant_a >>= -exp_diff
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
    ori a0, a1, 0x7f80  # return (result_sign << 15) | 0x7f80
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
    ori t6, a1, t1      # t6 = (result_sign << 15) | (result_exp & 0xff) << 7
    ori a0, t6, a0      # return (result_sign << 15) | (result_exp & 0xff) << 7 | (result_mant & 0x7f)
    ret

# ===============================
# Function: bf16_sub(bf16_t a, bf16_t b)
# ===============================
bf16_sub:
    # Input: a0 = a, a1 = b
    # Output: a0 = result
    xori a1, a1, 0x8000   # b.bits ^= 0x8000
    addi sp, sp, -4     # Allocate stack space
    sw ra, 0(sp)        # Save return address
    jal bf16_add      # Call bf16_add
    lw ra, 0(sp)        # Restore return address
    addi sp, sp, 4      # Deallocate stack space
    ret
