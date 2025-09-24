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
    jal ra, test     # a0 = test()
    lw ra, 0(sp)     # Restore return address
    addi sp, sp, 4   # Deallocate stack space
    beq a0, zero, main.test_failed  # if (a0 == 0) goto fail
    la a0, str5  # Load address of str5
    li a7, 4  # syscall: print string
    ecall
    li a0, 0  # return 0
    ret
main.test_failed:
    li a0, 1  # return 1
    ret

# ======================================
# Function: clz
# ======================================
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
    
# ======================================
# Function: uf8_encode
# ======================================
uf8_encode:
    # Input: a = 32-bit unsigned integer
    # Output: a0 = 8-bit unsigned integer
    li t0, 16    # t0 dummy = 16
    blt a0, t0, uf8_encode.end    # if (value < 16) return value
    addi sp, sp, -8  # Allocate stack space
    sw ra, 4(sp)     # Save return address
    sw a0, 0(sp)     # Save input value
    jal ra, clz      # Call clz function
    mv t1, a0        # lz = t1 = clz(value)
    lw a0, 0(sp)     # Restore input value
    lw ra, 4(sp)     # Restore return address
    addi sp, sp, 8   # Deallocate stack space
    li t2, 31   # msb = t2 = 31
    sub t2, t2, t1  # msb = 31 - lz
    li t3, 0    # exponent = t3 = 0
    li t4, 0    # overflow = t4 = 24
    li t0, 5   # t0 dummy = 5
    blt t2, t0, uf8_encode.loop3    # if (msb < 5) goto loop
    addi t3, t2, -4  # exponent = msb - 4
    li t0, 15  # t0 dummy = 15
    bge t0, t3, uf8_encode.skip1    #if (exponent <= 15) goto skip1
    li t3, 15  # exponent = 15
    li t0, 0  # e = t0 = 0
uf8_encode.loop1:
    bge t0, t3, uf8_encode.loop2
    slli t4, t4,1  # overflow <<= 1
    addi t4, t4, 16 # overflow += 16
    addi t0, t0, 1 # e += 1
    j uf8_encode.loop1
uf8_encode.loop2:
    bge zero, t3, uf8_encode.loop3 # if (0 >= exponent) goto loop3
    bge a0, t4, uf8_encode.loop3  # if (value >= overflow) goto loop3
    addi t4, t4, -16 # overflow -= 16
    srli t4, t4, 1  # overflow >>= 1
    addi t3, t3, -1  # exponent -= 1
    j uf8_encode.loop2
    li t0, 15 # t0 dummy = 15
uf8_encode.loop3:
    bge t3, t0, uf8_encode.skip1  # if (exponent >= 15) goto skip1
    slli t2, t4, 1  # next_overflow = overflow << 1
    addi t2, t2, 16 # next_overflow += 16
    blt a0, t2, uf8_encode.skip1  # if (value < next_overflow) goto skip1
    mv t4, t2 # overflow = next_overflow
    addi t3, t3, 1  # exponent += 1
    j uf8_encode.loop3
uf8_encode.skip1:
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
    li t0, -1   # previous_value = -1
    li t1, 1    # t1 = passed = 1
    li t2, 0    # i = 0
    li t3, 256  # max = 256
test.loop:
    bge t2, t3, test.end   # if (i >= max) goto end
    mv t4, t2  # fl = t4 = i
    mv a0, t4  # a0 = fl
    addi sp, sp, -4  # Allocate stack space
    sw ra, 0(sp)  # Save return address
    jal ra, uf8_encode  # a0 = uf8_encode(fl)
    lw ra, 0(sp)  # Restore return address
    mv t5, a0  # value = t5 = uf8_encode(fl)
    sw ra, 0(sp)  # Save return address
    jal ra, uf8_encode  # a0 = uf8_encode(value)
    lw ra, 0(sp)  # Restore return address
    addi sp, sp, 4   # Deallocate stack space
    mv t6, a0  # fl2 = t6 = uf8_encode(value)
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
    li t1, 0  # passed = 0
test.skip1:
    blt t0, t5, test.skip2  # if (previous_value < value) goto skip2
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
    mv a0, t0  # a0 = previous_value
    li a7, 1  # syscall: print integer
    ecall
    la a0, str6  # Load address of str6
    li a7, 4  # syscall: print string
    ecall
    li t1, 0  # passed = 0
test.skip2:
    mv t0, t5  # previous_value = value
    addi t2, t2, 1  # i++
    j test.loop
test.end:
    mv a0, t1  # return passed
    ret  # End of test function
