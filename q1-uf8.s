    .data
pass_message:
    .string "All tests passed.\n"
    .text
main:
    jal     ra, test              # test()
    beq     x0, a0, exit          # if (!test())
    li      a7, 4
    la      a0, pass_message
    ecall
    li      a7, 10                # halt
    ecall
exit:
    li      a7, 93                # system call: exit2
    li      a0, 1                 # exit value
    ecall                         # exit 1

# Test encode/decode round-trip
#
# s0: previous_value
# s1: passed
# s2: i
# s3: fl
# s4: value
# s5: fl2
test:
    addi    sp, sp, -4
    sw      ra 0(sp)              # store return addr

    li      s0, -1                # previous_value = -1
    li      s1, 1                 # passed = true

# for (i = 0; i < 256; i++)
    li      s2, 0                 # i = 0
1:
    mv      s3, s2                # fl = i
    mv      a0, s3                # a0 = fl
    jal     ra, uf8_decode        # uf8_decode(fl)
    mv      s4, a0                # value = uf8_encode(fl)
    jal     ra, uf8_encode        # uf8_encode(value)
    mv      s5, a0                # fl2 = uf8_decode(value)

    beq     s3, s5, 2f            # if (fl == fl2), to 2
    li      s1, 0                 # passed = false
2:
    bgt     s4, s0, 3f            # if (value > previous_value), to 3
    li      s1, 0                 # passed = false
3:
    mv      s0, s4                # previous_value = value
    addi    s2, s2, 1             # i++
    li      t0, 256
    blt     s2, t0, 1b            # if (i < 256), to 1
# done

    lw      ra 0(sp)              # restore return addr
    addi    sp, sp, 4

    mv      a0, s1                # return passed
    ret

clz:
    li      t0, 32                # n
    li      t1, 16                # c
1:
    srl     t3, a0, t1            # y = x >> c
    beq     x0, t3, 2f            # if (!y)
    sub     t0, t0, t1            # n = n - c
    mv      a0, t3                # x = y
2:
    srai    t1, t1, 1             # c >>= 1
    bne     x0, t1, 1b            # while (c)
    sub     a0, t0, a0            # return value: n - x
    ret

# Decode uf8 to uint32_t
#
# a0: fl
# t0: mantissa
# t1: exponent
# t3: offset
uf8_decode:
    addi    sp, sp, -4
    sw      ra, 0(sp)             # store return addr

    andi    t0, a0, 0x0f          # mantissa = fl & 0x0f
    srli    t1, a0, 4             # exponent = fl >> 4

    li      t2, 15
    sub     t2, t2, t1            # 15 - exponent
    li      t3, 0x00007fff
    srl     t3, t3, t2            # offset = 0x7fff >> (15 - exponent)
    slli    t3, t3, 4             # offset <<= 4

    sll     t4, t0, t1            # mantissa << exponent
    add     a0, t4, t3            # return mantissa + offset

    lw      ra, 0(sp)             # restore return addr
    addi    sp, sp, 4
    ret

# Encode uint32_t to uf8
#
# s0: value
# s1: lz
# s2: msb
# s3: exponent
# s4: overflow
# s5: e
# s6: next_overflow
# s7: mantissa
uf8_encode:
    addi    sp, sp, -36
    sw      ra, 32(sp)            # store return addr
    sw      s0, 28(sp)
    sw      s1, 24(sp)
    sw      s2, 20(sp)
    sw      s3, 16(sp)
    sw      s4, 12(sp)
    sw      s5, 8(sp)
    sw      s6, 4(sp)
    sw      s7, 0(sp)

    mv      s0, a0                # value
    li      t0, 16
    blt     s0, t0, 4f            # if (value < 16) goto 4

    jal     ra, clz               # clz(value)
    mv      s1, a0                # lz = clz(value)

    li      s2, 31
    sub     s2, s2, t1            # msb = 31 - lz

    li      s3, 0                 # exponent
    li      s4, 0                 # overflow

# if (msb >= 5)
    li      t0, 5
    blt     s2, t0, 5f            # if (msb < 5) goto 5

    addi,   s3, s2, -4            # exponent = msb - 4

# if (exponent > 15)
    li      t0, 15
    ble     s3, t0, 2f            # if (exponent <= 15) goto 2
    li      s3, 15                # exponent = 15
# fi
2:
# for (e = 0; e < exponent; e++)
    li      s5, 0                 # e = 0
3:
    bge     s5, s3, 4f            # if (e >= exponent) goto 4
    slli    s4, s4, 1             # overflow <<= 1
    addi    s4, s4, 16            # overflow += 16
    addi    s5, s5, 1             # e++
    j       3b                    # repeat
# end for
4:
# while (exponent > 0 && value >= overflow)
    slt     t0, x0, s3            # t0 = if (exponent > 0)
    slt     t1, s0, s4            # t1 = if (value < overflow)
    and     t0, t0, t1            # t0 = if (exponent > 0 && value < overflow)
    beq     x0, t0, 5f            # if (!t0) goto 5

    addi    s4, s4, -16           # overflow -= 16
    srli    s4, s4, 1             # overflow >>= 1
    addi    s3, s3, -1            # exponent--

    j       4b                    # repeat
# end while
5:
# while (exponent < 15)
    li      t0, 15
6:
    bge     s3, t0, 7f            # if (exponent >= 15) goto 7

    slli    s6, s4, 1             # next_overflow = overflow << 1
    addi    s6, s6, 16            # next_overflow += 16

    blt     s0, s6 , 7f           # if (value < next_overflow) break to 7

    mv      s4, s6                # overflow = next_overflow
    addi    s3, s3, 1             # exponent++

    j       6b                    # repeat
# end while
7:
    sub     s7, s0, s4            # mantissa = value - overflow
    srl     s7, s7, s3            # mantissa >>= exponent

    slli    a0, s3, 4             # a0 = exponent << 4
    or      a0, a0, s7            # a0 |= mantissa

    lw      s7, 0(sp)
    lw      s6, 4(sp)
    lw      s5, 8(sp)
    lw      s4, 12(sp)
    lw      s3, 16(sp)
    lw      s2, 20(sp)
    lw      s1, 24(sp)
    lw      s0, 28(sp)
    lw      ra, 32(sp)            # restore return addr
    addi    sp, sp, 36

    ret