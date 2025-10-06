#include <stdbool.h>
#include <stdint.h>
#include <string.h>

typedef struct {
    uint16_t bits;
} bf16_t;


static int test_basic_conversions(void)
{
    printf("Testing basic conversions...\n");

    float test_values[] = {0.0f,  1.0f, -1.0f, 2.0f, -2.0f, 0.5f,
                           -0.5f, 3.14159f, -3.14159f, 1e10f, -1e10f};
    float test_upper[] = {0.0f, 1.01f, -1.01f, 2.02f, 2.02f, 0.505f, 
                        0.505f,3.1730059f, -3.1730059f, 1.01e10f, -1.01e10f};
    float test_lower[] = {0.0f, 0.99f, -0.99f, 1.98f, -1.98f, 0.495f, 
                        -0.495f, 3.1101741f, -3.1101741f, 9.9e9f, -9.9e9f};

    for (size_t i = 0; i < sizeof(test_values) / sizeof(test_values[0]); i++) {
        float orig = test_values[i];
        bf16_t bf = f32_to_bf16(orig);
        float conv = bf16_to_f32(bf);
        if (orig != 0.0f) {
            TEST_ASSERT((orig < 0) == (conv < 0), "Sign mismatch");
        }

        if (orig != 0.0f && !bf16_isinf(bf)) {
            float upper = test_upper[i];
            float lower = test_lower[i];
            TEST_ASSERT(lower < conv && conv < upper, "Relative error too large");
        }
    }

    printf("  Basic conversions: PASS\n");
    return 0;
}


static int test_arithmetic(void)
{
    printf("Testing arithmetic operations...\n");

    float test_arith_values[] = {1.0f, 2.0f, 10.0f, 3.0f, 4.0f, 9.0f};
    float test_arith_upper[] = {3.01f, 1.01f, 5.1f, 12.1f, 2.01f, 3.01f};
    float test_arith_lower[] = {2.99f, 0.99f, 4.9f, 11.9f, 1.99f, 2.99f};

    bf16_t a = f32_to_bf16(test_arith_values[0]);
    bf16_t b = f32_to_bf16(test_arith_values[1]);
    bf16_t c = bf16_add(a, b);
    float result = bf16_to_f32(c);
    TEST_ASSERT((test_arith_lower[0] < result && result < test_arith_upper[0], "Addition failed");

    c = bf16_sub(b, a);
    result = bf16_to_f32(c);
    TEST_ASSERT((test_arith_lower[1] < result && result < test_arith_upper[1]), "Subtraction failed");

    a = f32_to_bf16(test_arith_values[2]);
    // b = f32_to_bf16(2.0f);
    c = bf16_div(a, b);
    result = bf16_to_f32(c);
    TEST_ASSERT((test_arith_lower[2] < result && result < test_arith_upper[2]), "Division failed");

    a = f32_to_bf16(test_arith_values[3]);
    b = f32_to_bf16(test_arith_values[4]);
    c = bf16_mul(a, b);
    result = bf16_to_f32(c);
    TEST_ASSERT((test_arith_lower[3] < result && result < test_arith_upper[3]), "Multiplication failed");

    /* Test square root */
    // b = f32_to_bf16(4.0f);
    c = bf16_sqrt(b);
    result = bf16_to_f32(c);
    TEST_ASSERT((test_arith_lower[4] < result && result < test_arith_upper[4]), "sqrt(4) failed");

    a = f32_to_bf16(test_arith_values[5]);
    c = bf16_sqrt(a);
    result = bf16_to_f32(c);
    TEST_ASSERT((test_arith_lower[5] < result && result < test_arith_upper[5]), "sqrt(9) failed");

    printf("  Arithmetic: PASS\n");
    return 0;
}


static int test_edge_cases(void)
{
    printf("Testing edge cases...\n");
    float test_values[] = {1e-45f, 1e-37f, 1e-38f, 1e38f, 10.0f, 1e10f};

    float tiny = test_values[0];
    bf16_t bf_tiny = f32_to_bf16(tiny);
    float tiny_val = bf16_to_f32(bf_tiny);
    TEST_ASSERT(bf16_iszero(bf_tiny) || tiny_val < test_values[1],
                "Tiny value handling");

    float huge = test_values[3];
    bf16_t bf_huge = f32_to_bf16(huge);
    bf16_t bf_huge2 = bf16_mul(bf_huge, f32_to_bf16(test_values[4]));
    TEST_ASSERT(bf16_isinf(bf_huge2), "Overflow should produce infinity");

    bf16_t small = f32_to_bf16(test_values[2]);
    bf16_t smaller = bf16_div(small, f32_to_bf16(test_values[5]));
    float smaller_val = bf16_to_f32(smaller);
    TEST_ASSERT(bf16_iszero(smaller) || smaller_val < test_values[0],
                "Underflow should produce zero or denormal");

    printf("  Edge cases: PASS\n");
    return 0;
}


static int test_rounding(void)
{
    printf("Testing rounding behavior...\n");
    float test_values[] = {1.5f, 1.0001f};
    float test_bounds[] = {0.9991f, 1.0011f}

    float exact = test_values[0];
    bf16_t bf_exact = f32_to_bf16(exact);
    float back_exact = bf16_to_f32(bf_exact);
    TEST_ASSERT(back_exact == exact,
                "Exact representation should be preserved");

    float val = test_values[1];
    bf16_t bf = f32_to_bf16(val);
    float back = bf16_to_f32(bf);
    TEST_ASSERT(test_bounds[0] < back && back < test_bounds[1], "Rounding error should be small");

    printf("  Rounding: PASS\n");
    return 0;
}
