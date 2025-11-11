.data

.equ BF16_EXP_BIAS,        127
.equ BF16_ZERO,            0x0000
.equ NUM_TEST_VALUES_CONV, 13

int32_values:
.word  0
.word  1
.word -1
.word  10
.word  255
.word  256
.word  257
.word  65535
.word -65535
.word  12345678
.word -12345678
.word  2147483647
.word -2147483648

bf16_values:
.word 0x0000 #  0.0
.word 0x3F80 #  1.0
.word 0xBF80 # -1.0
.word 0x4120 #  10.0
.word 0x437F #  255.0
.word 0x4380 #  256.0
.word 0x4380 #  256.0 (257 rounds to 256)
.word 0x4780 #  65536.0      (missing precision)
.word 0xC780 # -65536.0      (missing precision)
.word 0x4B3C #  12320768.0   (missing precision)
.word 0xCB3C # -12320768.0   (missing precision)
.word 0x4F00 #  2147483648.0 (missing precision)
.word 0xCF00 # -2147483648.0 (missing precision)

pass_message: .string "All tests passed.\n"

.text
.align	2
.globl	main

#-------------------------------------------------------------------------------
# main
#-------------------------------------------------------------------------------
main:
    addi    sp, sp, -4
    sw      ra, 0(sp)

    jal     ra, test_int32_to_bf16
    bnez    a0, 1f

    li      a7, 64                        # system call: write
    li      a0, 1                         # fd
    la      a1, pass_message              # buf
    li      a2, 18                        # count
    ecall

    lw      ra, 0(sp)
    addi    sp, sp, 4

    li      a0, 0
    ret

    # li      a7, 93                        # system call: exit
    # li      a0, 0                         # exit value
    # ecall                                 # exit 0
1: # fail
    # li      a7, 93                        # system call: exit
    # li      a0, 1                         # exit value
    # ecall                                 # exit 1

    lw      ra, 0(sp)
    addi    sp, sp, 4

    li      a0, 1
    ret

#-------------------------------------------------------------------------------
# int32_to_bf16
#
# Arguments:
#   a0: int32 value
#
# Returns:
#   a0: bf16 value
#
# Registers Usage:
#   s0: val (int32)
#   s1: sign
#   s2: fls
#   s3: round_bit
#   s4: exponent
#   s5: mantissa
#-------------------------------------------------------------------------------
int32_to_bf16:
    # Callee save
    addi    sp, sp, -28
    sw      ra, 24(sp)
    sw      s0, 20(sp)
    sw      s1, 16(sp)
    sw      s2, 12(sp)
    sw      s3, 8(sp)
    sw      s4, 4(sp)
    sw      s5, 0(sp)

    mv      s0, a0                # s0 = val

    # sign
    srli    s1, a0, 31            # sign = val >> 31
    andi    s1, s1, 1             # sign &= 1

    li      t0, BF16_ZERO
    beq     s0, t0, return_zero   # if (val == 0) return 0

    bgez    s0, 1f
    sub     s0, x0, s0            # val = -val
1:
    # highest set bit
    mv      a0, s0                # a0 = val
    jal     ra, clz
    li      t0, 31
    sub     s2, t0, a0            # fls = 31 - clz(val)

    # Round to nearest even
    li      t0, 7
    ble     s2, t0, 1f

    addi    t0, s2, -8            # t0 = fls - 8
    li      s3, 1
    sll     s3, s3, t0            # round_bit = 1 << (fls - 8)
    addi    s3, s3, -1            # round_bit = (1 << (fls - 8)) - 1
    add     s0, s0, s3            # val += round_bit
    mv      a0, s0                # a0 = val
    jal     ra, clz               # clz(val)
    li      t0, 31
    sub     s2, t0, a0            # fls = 31 - clz(val)
1: # no rounding needed

    # exponent
    addi    s4, s2, BF16_EXP_BIAS # exponent = fls + BF16_EXP_BIAS

    # mantissa
    li      t0, 32
    sub     t0, t0, s2            # t0 = 32 - fls
    sll     s5, s0, t0            # mantissa = val << (32 - fls)
    srli    s5, s5, 25            # mantissa >>= 25

    slli    a0, s1, 15            # a0 = sign << 15
    andi    t0, s4, 0xFF          # t0 = exponent & 0xFF
    slli    t0, t0, 7             # t0 = (exponent & 0xFF) << 7
    or      a0, a0, t0            # a0 |= (exponent & 0xFF) << 7
    andi    t0, s5, 0x7F          # t0 = mantissa & 0x7F
    or      a0, a0, t0            # a0 |= mantissa & 0x7F

    j       on_return

return_zero:
    li      a0, BF16_ZERO

on_return:
    # Callee restore
    lw      s5, 0(sp)
    lw      s4, 4(sp)
    lw      s3, 8(sp)
    lw      s2, 12(sp)
    lw      s1, 16(sp)
    lw      s0, 20(sp)
    lw      ra, 24(sp)
    addi    sp, sp, 28
    ret


#-------------------------------------------------------------------------------
# clz
# Count leading zeros
#
# Arguments:
#   a0: x
#
# Returns:
#   a0: number of leading zeros
#-------------------------------------------------------------------------------
clz:
    li      t0, 32                # n
    li      t1, 16                # c
1: # do while
    srl     t3, a0, t1            # y = x >> c
    beq     x0, t3, 2f            # if (!y) go to 2
    sub     t0, t0, t1            # n = n - c
    mv      a0, t3                # x = y
2: # join
    srai    t1, t1, 1             # c >>= 1
    bne     x0, t1, 1b            # while (c)
    sub     a0, t0, a0            # return value: n - x
    ret


#-------------------------------------------------------------------------------
# test_int32_to_bf16
#-------------------------------------------------------------------------------
test_int32_to_bf16:
    # Callee save
    addi    sp, sp, -20
    sw      ra, 16(sp)
    sw      s0, 12(sp)
    sw      s1, 8(sp)
    sw      s2, 4(sp)
    sw      s3, 0(sp)

    li      s0, 0                     # i = 0
    la      s1, int32_values          # input_data_addr
    la      s2, bf16_values           # golden_data_addr
    li      s3, NUM_TEST_VALUES_CONV  # num_test_data

    bge     s0, s3, 2f                # if (i >= num_test_data) go to pass

1: # loop
    lw      a0, 0(s1)                 # a0 = input_data[i]
    jal     ra, int32_to_bf16         # int32_to_bf16(a0)

    mv      t0, a0                    # t0 = result
    lw      t1, 0(s2)                 # s7 = golden_data[i]

    bne     t0, t1, 3f                # compare t0, t1

    addi    s0, s0, 1                 # i++
    addi    s1, s1, 4                 # input_data += 4
    addi    s2, s2, 4                 # golden_data += 4
    blt     s0, s3, 1b                # if (i < num_test_data) repeat

2: # pass
    li      a0, 0                     # return 0
    j       4f

3: # fail
    li      a0, 1                     # return 1

4: # on return
    # Callee restore
    lw      s3, 0(sp)
    lw      s2, 4(sp)
    lw      s1, 8(sp)
    lw      s0, 12(sp)
    lw      ra, 16(sp)
    addi    sp, sp, 20
    ret