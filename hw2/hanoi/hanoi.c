/* Iterative Tower of Hanoi Using Gray Code */

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

static void print_move(int disk, char from, char to)
{
    printf("Move Disk %d from %c to %c\n", disk, from, to);
}

int main()
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
        int disk = __builtin_popcount(changed_bit - 1); // #C04

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

    return 0;
}