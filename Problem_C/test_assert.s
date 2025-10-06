# #define TEST_ASSERT(cond, msg)         \
#     do {                               \
#         if (!(cond)) {                 \
#             printf("FAIL: %s\n", msg); \
#             return 1;                  \
#         }                              \
#     } while (0)

# Input: cond & mes
    bne cond, zero, test_assert # replace cond
    la a0, str_f
    li a7, 4
    ecall
    la a0, msg # replace msg
    ecall 
    li a0, 1
    ret
test_assert:
