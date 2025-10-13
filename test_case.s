# =================================
# Uf8 encode/decode test case
# =================================
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
    mv a0, t4  # a0 = fl
    li a7, 1  # syscall: print integer
    ecall
    la a0, str1  # Load address of str1
    li a7, 4  # syscall: print string
    ecall
    mv a0, t5  # a0 = value
    li a7, 34  # syscall: print integer
    ecall
    la a0, str2  # Load address of str2
    li a7, 4  # syscall: print string
    ecall
    mv a0, t6  # a0 = fl2
    li a7, 1  # syscall: print integer
    ecall
    la a0, str6  # Load address of str6
    li a7, 4  # syscall: print string
    ecall
    addi s2, s2, 1  # i++
    j test.loop
test.end:
    lw s3, 16(sp)  # Restore max
    lw s2, 12(sp)  # Restore i
    lw s1, 8(sp)  # Restore passed
    lw s0, 4(sp)  # Restore previous_value
    lw ra, 0(sp)  # Restore return address
    addi sp, sp, 20  # Deallocate stack space
    ret


.data
str1: .string ": produces value 0x"
str2: .string " re-encodes back to "
str6: .string "\n"


# =================================================================


# =================================
# Bfloat16 test case
# =================================
test:
    addi sp, sp, -8 # Allocate stack space
    sw ra, 0(sp)  # Save return address
    sw s0, 4(sp)  # Save s0
    li a0, 0x3f800000  # Input: 1.0 in fp32
    jal f32_to_bf16  # a0 = bfloat16_encode(1.0)
    mv s0, a0  # s0 = encoded value
    jal bf16_to_f32  # a0 = bfloat16_decode(encoded value)
    mv t0, a0  # t0 = decoded value
    li a0, 0x3f800000  # Expected: 1.0 in fp32
    li a7, 2  # syscall: print float
    ecall
    la a0, str1  # Load address of str1
    li a7, 4  # syscall: print string
    ecall
    mv a0, s0  # a0 = encoded value
    li a7, 34  # syscall: print hex integer
    ecall
    la a0, str2  # Load address of str2
    li a7, 4  # syscall: print string
    ecall
    mv a0, t0  # a0 = decoded value
    li a7, 2  # syscall: print float
    ecall
    la a0, str6  # Load address of str6
    li a7, 4  # syscall: print string
    ecall

    li a0, 0x3f80  # 1.0 in bfloat16
    li a1, 0x4000  # 2.0 in bfloat16
    jal bf16_add  # a0 = bf16_add(1.0, 2.0)
    li a1, 0x4080  # 4.0 in bfloat16
    jal bf16_mul  # a0 = bf16_mul(3.0, 4.0)
    li a1, 0x4040  # 3.0 in bfloat16
    jal bf16_div  # a0 = bf16_sub(12.0, 3.0)
    jal bf16_to_f32  # a0 = bfloat16_decode(result)
    mv t1, a0  # t1 = result of division
    la a0, str3  # Load address of str3
    li a7, 4  # syscall: print string
    ecall
    mv a0, t1  # a0 = result of (1+2)*4/3
    li a7, 2  # syscall: print float
    ecall
    la a0, str6  # Load address of str6
    li a7, 4  # syscall: print string
    ecall

    li a0, 0x41e0  # 28.0 in bfloat16
    li a1, 0x4000  # 3.0 in bfloat
    jal bf16_sub  # a0 = bf16_sub(28.0, 3.0)
    jal bf16_sqrt  # a0 = bf16_sqrt(25.0)
    jal bf16_to_f32  # a0 = bfloat16_decode(result)
    mv t2, a0  # t2 = result of sqrt
    la a0, str4  # Load address of str4
    li a7, 4  # syscall: print string
    ecall
    mv a0, t2  # a0 = result of sqrt(7-3)
    li a7, 2  # syscall: print float
    ecall
    la a0, str6  # Load address of str6
    li a7, 4  # syscall: print string
    ecall
    li a0, 1  # passed = 1
    lw s0, 4(sp)  # Restore s0
    lw ra, 0(sp)  # Restore return address
    addi sp, sp, 8  # Deallocate stack space
    ret


.data
str1: .string ": produced value 0x"
str2: .string ", re-encoded to "
str3: .string "(1+2)*4/3 = "
str4: .string "sqrt(7-3) = "
str6: .string "\n"
