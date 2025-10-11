#define BFLOAT16_NO_MAIN
#include "q1-bfloat16.c"

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

bf16_t int32_to_bf16(int32_t val) {
    uint16_t sign = val >> 31 & 1;
    uint16_t exponent;
    uint32_t mantissa;

    if (val == 0)
        return BF16_ZERO();

    if (val < 0)
        val = -val;

    uint16_t fls = 31 - clz(val);

    if (fls > 7) {
        uint32_t round_bit = (1 << (fls - 8)) - 1; // Half of discarded mantissa
        val += round_bit;                          // Round to nearest even
        fls = 31 - clz(val);                       // Recalculate if overflow after rounding
    }

    exponent = fls + BF16_EXP_BIAS;
    mantissa = (val << (32 - fls)) >> 25; // Remove implicit 1 and shift to 7 bits

    return (bf16_t){.bits = sign << 15 | (exponent & 0xff) << 7 | (mantissa & 0x7f)};
}

int test_int32_to_bf16() {
    printf("Testing int32 to bfloat16 conversion...\n");

    int test_values[] = {
        0, 1, -1, 2, 3, 10, 255, 256, 257, -1023, 65535, -65535,
        12345678, -12345678, 2147483647, -2147483648};
    size_t num_tests = sizeof(test_values) / sizeof(test_values[0]);

    for (size_t i = 0; i < num_tests; i++) {
        int val = test_values[i];
        float f_val = (float)val;
        bf16_t bf_val = int32_to_bf16(val);
        bf16_t bf_from_f = f32_to_bf16(f_val);

        printf("Test %d:\n", val);
        printf("    int: %13d -> bf16: 0x%04X -> float: %13.1f\n", val, bf_val.bits, bf16_to_f32(bf_val));
        printf("  float: %13.1f -> bf16: 0x%04X -> float: %13.1f\n\n", f_val, bf_from_f.bits, bf16_to_f32(bf_from_f));

        TEST_ASSERT(bf16_eq(bf_val, bf_from_f),
                    "int32 to bfloat16 conversion failed");
    }

    printf("int32 to bfloat16 conversion: PASS\n");
    return 0;
}

int main() {
    if (test_int32_to_bf16()) {
        printf("\n=== TESTS FAILED ===\n");
        return 1;
    }

    printf("\n=== ALL TESTS PASSED ===\n");
    return 0;
}