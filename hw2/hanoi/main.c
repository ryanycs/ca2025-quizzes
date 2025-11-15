#include <stdint.h>
#include <stdbool.h>
#include <string.h>

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

static void print_move(int disk, char from, char to)
{
    TEST_LOGGER("Move Disk ");
    print_dec(disk);
    TEST_LOGGER(" from ");
    printstr(&from, 1);
    TEST_LOGGER(" to ");
    printstr(&to, 1);
    TEST_LOGGER("\n");
}

static void hanoi_c()
{
    int n_disks = 3; /* Number of disks */

    int total_moves = (1 << n_disks) - 1;
    const char pegs[3] = {'A', 'B', 'C'}; /* Peg labels */
    int pos[n_disks]; /* Disk positions: 0-A, 1-B, 2-C */

    /* Initialize all disks to peg A */
    for (int i = 0; i < n_disks; i++)
        pos[i] = 0;

    /* Set direction based on parity of number of disks */
    int direction = (n_disks & 1) ? -1 /* counter-clockwise */
                                    : 1; /* clockwise */

    /* Predefined packed mapping arrays */
    const uint8_t peg_map[3] = {
        0x9, /* Peg A: {CCW -> C (2), CW -> B (1)} */ // #C01
        0x2, /* Peg B: {CCW -> A (0), CW -> C (2)} */ // #C02
        0x4  /* Peg C: {CCW -> B (1), CW -> A (0)} */ // #C03
    };

    /* Calculate direction index: -1 -> 0 (CCW), 1 ->1 (CW) */
    int direction_index = (direction + 1) / 2;

    for (int n_moves = 1; n_moves <= total_moves; n_moves++) {
        int curr_gray = n_moves ^ (n_moves >> 1);
        int prev_gray = (n_moves - 1) ^ ((n_moves - 1) >> 1);
        int changed_bit = curr_gray ^ prev_gray;

        /* Identify the disk to move (0-indexed) */
        int disk = 0;
        if (changed_bit == 1) {
            disk = 0;
        } else if (changed_bit == 2) {
            disk = 1;
        } else {
            disk = 2;
        }

        /* Current peg of the disk */
        int curr_peg = pos[disk];
        int new_peg;

        if (disk == 0) {
            /* Calculate shift: direction_index=0 (CCW) -> shift2,
             * direction_index=1 (CW) -> shift0
             */
            int shift = (1 - direction_index) << 1;
            new_peg = (peg_map[curr_peg] >> shift) & 0x3; // #C05
        } else {
            /* Find the only peg not occupied by any smaller disk */
            bool found_new_peg = false;
            for (int p = 0; p < 3 && !found_new_peg; p++) {
                if (p == curr_peg)
                    continue;

                /* Check if any smaller disk is on peg p */
                bool has_smaller = false;
                for (int d = 0; d < disk; d++) {
                    if (pos[d] == p) {
                        has_smaller = true;
                        break;
                    }
                }

                if (!has_smaller) {
                    new_peg = p;
                    found_new_peg = true;
                }
            }
        }

        /* Execute the move */
        print_move(disk + 1, pegs[curr_peg], pegs[new_peg]);
        pos[disk] = new_peg;
    }
}

void timeit(void (*func)(void)) {
    uint64_t start_cycles, end_cycles, cycles_elapsed;
    uint64_t start_instret, end_instret, instret_elapsed;


    start_cycles = get_cycles();
    start_instret = get_instret();

    func();

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

int main(void) {
    TEST_LOGGER("=== RISC-V Assembly ===\n");
    timeit(hanoi);

    TEST_LOGGER("\n=== C Implementation ===\n");
    timeit(hanoi_c);

    return 0;
}