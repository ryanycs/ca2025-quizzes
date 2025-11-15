#include <stdint.h>
#include <stdio.h>
#include <limits.h>
#include <unistd.h>

#define TEST_OUTPUT(msg, length) printstr(msg, length)
#define TEST_LOGGER(msg)                     \
    {                                        \
        char _msg[] = msg;                   \
        TEST_OUTPUT(_msg, sizeof(_msg) - 1); \
    }

extern uint64_t get_cycles(void);
extern uint64_t get_instret(void);
extern void hanoi(void);

static inline void printstr(char* ptr, int length) {
    register const char *a1 asm("a1") = (ptr);
    register long a2 asm("a2") = (length);
    asm volatile(
        "add a7, x0, 0x40;"
        "add a0, x0, 0x1;" /* stdout */
        "ecall;"
        :
        : "r"(a1), "r"(a2)
        : "memory", "a0"
    );
}

/* Software division for RV32I (no M extension) */
static unsigned long udiv(unsigned long dividend, unsigned long divisor)
{
    if (divisor == 0)
        return 0;

    unsigned long quotient = 0;
    unsigned long remainder = 0;

    for (int i = 31; i >= 0; i--) {
        remainder <<= 1;
        remainder |= (dividend >> i) & 1;

        if (remainder >= divisor) {
            remainder -= divisor;
            quotient |= (1UL << i);
        }
    }

    return quotient;
}

static unsigned long umod(unsigned long dividend, unsigned long divisor)
{
    if (divisor == 0)
        return 0;

    unsigned long remainder = 0;

    for (int i = 31; i >= 0; i--) {
        remainder <<= 1;
        remainder |= (dividend >> i) & 1;

        if (remainder >= divisor) {
            remainder -= divisor;
        }
    }

    return remainder;
}

static void print_dec(unsigned long val)
{
    char buf[20];
    char *p = buf + sizeof(buf) - 1;

    if (val == 0) {
        *p = '0';
        p--;
    } else {
        while (val > 0) {
            *p = '0' + umod(val, 10);
            p--;
            val = udiv(val, 10);
        }
    }

    p++;
    printstr(p, (buf + sizeof(buf) - p));
}

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

// static inline unsigned clz2(uint32_t x)
// {
//     if (x == 0)
//         return 32;
//     uint32_t n = 0;
//     if ((x >> 16) == 0) { n += 16; x <<= 16; }
//     if ((x >> 24) == 0) { n += 8;  x <<= 8;  }
//     if ((x >> 28) == 0) { n += 4;  x <<= 4;  }
//     if ((x >> 30) == 0) { n += 2;  x <<= 2;  }
//     if ((x >> 31) == 0) { n += 1; }
//     return n;
// }

static uint64_t mul32(uint32_t a, uint32_t b)
{
    uint64_t r = 0;
    for (int i = 0; i < 32; i++) {
        if (b & (1U << i)) {
            r += (uint64_t)a << i;
        }
    }
    return r;
}

static const uint32_t rsqrt_table[32] = {
    65536, 46341, 32768, 23170, 16384,  /* 2^0 to 2^4 */
    11585,  8192,  5793,  4096,  2896,  /* 2^5 to 2^9 */
     2048,  1448,  1024,   724,   512,  /* 2^10 to 2^14 */
      362,   256,   181,   128,    90,  /* 2^15 to 2^19 */
       64,    45,    32,    23,    16,  /* 2^20 to 2^24 */
       11,     8,     6,     4,     3,  /* 2^25 to 2^29 */
        2,     1                        /* 2^30, 2^31 */
};

uint32_t fast_rsqrt(uint32_t x)
{
    /* Handle edge cases */
    if (x == 0) return 0xFFFFFFFF;
    if (x == 1) return 65536;

    int exp = 31 - clz(x);

    uint32_t y = rsqrt_table[exp];

    if (x > (1u << exp)) {
        uint32_t y_next = (exp < 31) ? rsqrt_table[exp + 1] : 0;
        uint32_t delta = y - y_next;
        uint32_t frac = (uint32_t) ((((uint64_t)x - (1UL << exp)) << 16) >> exp);
        y -= (uint32_t) (mul32(delta, frac) >> 16);
    }

    for (int iter = 0; iter < 2; iter++) {
        uint32_t y2 = (uint32_t)mul32(y, y);
        uint32_t xy2 = (uint32_t)(mul32(x, y2) >> 16);
        y = (uint32_t)(mul32(y, (3u << 16) - xy2) >> 17);
    }

    return y;
}

int main(void)
{
    uint64_t start_cycles, end_cycles, cycles_elapsed;
    uint64_t start_instret, end_instret, instret_elapsed;

    uint32_t test_vals[] = {1, 2, 4, 16, 100, UINT_MAX};

    for (int i = 0; i < sizeof(test_vals) / sizeof(uint32_t); i++) {
        start_cycles = get_cycles();
        start_instret = get_instret();

        uint32_t y = fast_rsqrt(test_vals[i]);

        // Print result
        TEST_LOGGER("rsqrt(");
        print_dec(test_vals[i]);
        TEST_LOGGER(") = ");
        print_dec(y);
        TEST_LOGGER("\n");

        end_cycles = get_cycles();
        end_instret = get_instret();
        cycles_elapsed = end_cycles - start_cycles;
        instret_elapsed = end_instret - start_instret;

        TEST_LOGGER("  Cycles: ");
        print_dec((unsigned long) cycles_elapsed);
        TEST_LOGGER("\n  Instructions: ");
        print_dec((unsigned long) instret_elapsed);
        TEST_LOGGER("\n");
    }

    return 0;
}
