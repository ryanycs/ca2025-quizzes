.data

.equ    BF16_SIGN_MASK, 0x8000
.equ    BF16_EXP_MASK,  0x7F80
.equ    BF16_MANT_MASK, 0x007F
.equ    BF16_EXP_BIAS,  127

.equ    BF16_POS_INF,  0x7F80
.equ    BF16_NEG_INF,  0xFF80
.equ    BF16_NAN,      0x7FC0
.equ    BF16_ZERO,     0x0000
.equ    BF16_NEG_ZERO, 0x8000

.equ    NUM_TEST_VALUES_CONV, 9
.equ    NUM_TEST_VALUES_ADD,  11
.equ    NUM_TEST_VALUES_SUB,  3
.equ    NUM_TEST_VALUES_MUL,  4

orig_f32:
.word   0x00000000  #  0.0
.word   0x3f800000  #  1.0
.word   0xbf800000  # -1.0
.word   0x3f000000  #  0.5
.word   0xbf000000  # -0.5
.word   0x40490fd0  #  3.14159
.word   0xc0490fd0  # -3.14159
.word   0x501502f9  #  1e10
.word   0xd01502f9  # -1e10

conv_bf16:
.word   0x0000      #  0.0
.word   0x3f80      #  1.0
.word   0xbf80      # -1.0
.word   0x3f00      #  0.5
.word   0xbf00      # -0.5
.word   0x4049      #  3.140625
.word   0xc049      # -3.140625
.word   0x5015      #  1e10
.word   0xd015      # -1e10

conv_f32:
.word   0x00000000  #  0.0
.word   0x3f800000  #  1.0
.word   0xbf800000  # -1.0
.word   0x3f000000  #  0.5
.word   0xbf000000  # -0.5
.word   0x40490000  #  3.140625
.word   0xc0490000  # -3.140625
.word   0x50150000  #  1e10
.word   0xd0150000  # -1e10

bf16_add_input:
.word   0x3f80, 0x4000      #  1.0 + 2.0
.word   0x4049, 0x402e      #  3.140625 + 2.71875
.word   0x3f80, 0xffffc000  #  1.0 + -2.0
.word   0xffffc000, 0x3f80  # -2.0 + 1.0
.word   0x0000, 0x3f80      #  0.0 + 1.0
.word   0x3f80, 0x0000      #  1.0 + 0.0
.word   0x7f80, 0x3f80      # +Inf + 1.0
.word   0x3f80, 0x7f80      #  1.0 + +Inf
.word   0xffff80, 0x3f80    # -inf + 1.0
.word   0x3f80, 0xffff80    #  1.0 + -inf
.word   0x7f62, 0x7f62      #  3e38 + 3e38 (f32 to bf16)

bf16_add_output:
.word   0x4040              #  3.0
.word   0x40bb              #  5.84375
.word   0xbf80              # -1.0
.word   0xbf80              # -1.0
.word   0x3f80              #  1.0
.word   0x3f80              #  1.0
.word   0x7f80              # +Inf
.word   0x7f80              # +Inf
.word   0xffff80            # -Inf
.word   0xffff80            # -Inf
.word   0x7f80              # +Inf

bf16_sub_input:
.word   0x4000, 0x3f80      #  2.0 - 1.0
.word   0x4049, 0x402e      #  3.140625 - 2.71875
.word   0x3f80, 0xffffc000  #  1.0 - -2.0

bf16_sub_output:
.word   0x3f80              #  1.0
.word   0x3ed8              #  0.421875
.word   0x4040              #  3.0

bf16_mul_input:
.word   0x4040, 0x4080      #  3.0 * 4.0
.word   0x4049, 0x402e      #  3.140625 * 2.71875
.word   0x7f80, 0x3f80      # +Inf * 1.0
.word   0x7f80, 0x0000      # +Inf * 0.0

bf16_mul_output:
.word   0x4140              #  12.0
.word   0x4108              #  8.5
.word   0x7f80              # +Inf
.word   0x7fc0              #  NaN

conversion_passed_msg:     .string " Basic conversions: Pass\n"
special_values_passed_msg: .string " Special values: PASS\n"
arithmetic_passed_msg:     .string " Arithmetic (ADD/SUB/MUL): PASS\n"
comparison_passed_msg:     .string " Comparisons: PASS\n"

result_msg: .string "   Result: "
golden_msg: .string " Golden: "
endline:    .string "\n"

.text

#-------------------------------------------------------------------------------
# main
#-------------------------------------------------------------------------------
main:
    # test_basic_conversions()
    jal     ra, test_basic_conversions
    bne     x0, a0, 1f                    # if (ret != 0) go to fail

    # test_special_values()
    jal     ra, test_special_values
    bne     x0, a0, 1f                    # if (ret != 0) go to fail

    # test_arithmetic()
    jal     ra, test_arithmetic
    bne     x0, a0, 1f                    # if (ret != 0) go to fail

    # test_comparisons()
    jal     ra, test_comparisons
    bne     x0, a0, 1f                    # if (ret != 0) go to fail

    li      a7, 10                        # system call: exit
    ecall
1: # fail
    li      a7, 93                        # system call: exit2
    li      a0, 1                         # exit value
    ecall                                 # exit 1


#-------------------------------------------------------------------------------
# test_basic_conversions
#
# Register Usage:
#   s0: i
#   s1: arr_ptr
#   s2: orig
#   s3: bf
#   s4: conv
#   s5: conv_bf16
#   s6: conv_f32
#
#-------------------------------------------------------------------------------
test_basic_conversions:
    addi    sp, sp, -8
    sw      ra, 4(sp)                     # store return addr
    sw      s0, 0(sp)                     # store s0

# for (i = 0; i < NUM_TEST_VALUES; i++)
    li      s0, 0                         # i = 0

    la      s1, orig_f32                  # arr_ptr = &orig_f32[0]
    la      s5, conv_bf16                 # arr_ptr = &conv_bf16[0]
    la      s6, conv_f32                  # arr_ptr = &conv_f32[0]
    li      t0, NUM_TEST_VALUES_CONV
    bge     s0, t0, 3f                    # if (i >= NUM_TEST_VALUES) go to end for
1:
    lw      s2, 0(s1)                     # orig = orig_f32[i]

    mv      a0, s2
    jal     ra f32_to_bf16                # f32_to_bf16(orig)
    mv      s3, a0                        # bf = f32_to_bf16(orig)

    jal     ra bf16_to_f32                # bf16_to_f32(bf)
    mv      s4, a0                        # conv = bf16_to_f32(bf)

# Sign bit check
    snez    t0, s2                        # t0 = (orig != 0.0)
    beq     t0, x0, 2f                    # if (orig == 0.0) go to 2
    slt     t1, s2, x0                    # t1 = orig < 0
    slt     t2, s4, x0                    # t2 = conv < 0
    bne     t1, t2, 4f                    # if (orig < 0) != (conv < 0) go to fail
2:

# bf vs conv_bf16 check
    lw      t0, 0(s5)                     # t0 = conv_bf16[i]
    bne     s3, t0, 4f                    # if (bf != conv_bf16[i]) go to fail

# conv vs conv_f32 check
    lw      t0, 0(s6)                     # t0 = conv_f32[i]
    bne     s4, t0, 4f                    # if (conv != conv_f32[i]) go to fail

# Print orig and conv for debugging
    # li      a7, 4                         # print string
    # la      a0, golden_msg
    # ecall
    # li      a7, 2                         # print float
    # mv      a0, s2                        # orig
    # ecall
    # li      a7, 4                         # print newline
    # la      a0, endline
    # ecall
    # la      a0, result_msg
    # ecall
    # li      a7, 2                         # print float
    # mv      a0, s4                        # conv
    # ecall
    # li      a7, 4                         # print newline
    # la      a0, endline
    # ecall
    # ecall

    addi    s0, s0, 1                     # i++
    addi    s1, s1, 4                     # arr_ptr += 4
    addi    s5, s5, 4
    addi    s6, s6, 4

    li      t0, NUM_TEST_VALUES_CONV
    blt     s0, t0, 1b                    # if (i < NUM_TEST_VALUES), back to 1
# end for
3:
    la      a0, conversion_passed_msg
    li      a7, 4
    ecall                                 # Print passed message

    mv      a0, x0                        # a0 = 0
    j       5f                            # go to return
4: # fail
    li      a0, 1                         # a0 = 1
5: # on return
    lw      s0, 0(sp)                     # restore s0
    lw      ra, 4(sp)                     # restore return addr
    addi    sp, sp, 8
    ret


#-------------------------------------------------------------------------------
# test_special_values
#-------------------------------------------------------------------------------
test_special_values:
    addi    sp, sp, -4
    sw      ra, 0(sp)                     # store return addr

    li      a0, BF16_POS_INF
    jal     ra, bf16_isinf
    beq     x0, a0, 1f                    # if (ret == 0) go to fail

    li      a0, BF16_POS_INF
    jal     ra, bf16_isnan
    bne     x0, a0, 1f                    # if (ret != 0) go to fail

    li      a0, BF16_NEG_INF
    jal     ra, bf16_isinf
    beq     x0, a0, 1f                    # if (ret == 0) go to fail

    li      a0, BF16_NAN
    jal     ra, bf16_isnan
    beq     x0, a0, 1f                    # if (ret == 0) go to fail

    li      a0, BF16_NAN
    jal     ra, bf16_isinf
    bne     x0, a0, 1f                    # if (ret != 0) go to fail

    li      a0, BF16_ZERO
    jal     ra, bf16_iszero
    beq     x0, a0, 1f                    # if (ret == 0) go to fail

    li      a0, BF16_NEG_ZERO
    jal     ra, bf16_iszero
    beq     x0, a0, 1f                    # if (ret == 0) go to fail

    li      a7, 4
    la      a0, special_values_passed_msg
    ecall                                 # Print passed message

    li      a0, 0
    j       2f                            # go to return
1: # fail
    li      a0, 1
2: # on return
    lw      ra, 0(sp)                     # restore return addr
    addi    sp, sp, 4
    ret


#-------------------------------------------------------------------------------
# test_arithmetic
#-------------------------------------------------------------------------------
test_arithmetic:
    addi    sp, sp, -4
    sw      ra, 0(sp)                     # store return addr

    # Test bf16_add
    la      a0, bf16_add
    la      a1, bf16_add_input
    la      a2, bf16_add_output
    li      a3, 2                         # two arguments
    li      a4, NUM_TEST_VALUES_ADD
    jal     ra, textfixture
    bne     x0, a0, 3f                    # if (ret != 0) go to fail

    # Test bf16_sub
    la      a0, bf16_sub
    la      a1, bf16_sub_input
    la      a2, bf16_sub_output
    li      a3, 2                         # two arguments
    li      a4, NUM_TEST_VALUES_SUB
    jal     ra, textfixture
    bne     x0, a0, 3f                    # if (ret != 0) go to fail

    # Test bf16_mul
    la      a0, bf16_mul
    la      a1, bf16_mul_input
    la      a2, bf16_mul_output
    li      a3, 2                         # two arguments
    li      a4, NUM_TEST_VALUES_MUL
    jal     ra, textfixture
    bne     x0, a0, 3f                    # if (ret != 0) go to fail

    # All tests passed
    li      a7, 4
    la      a0, arithmetic_passed_msg
    ecall                                 # Print passed message

    li      a0, 0
    j       4f                            # go to return
3: # fail
    li      a0, 1                         # a0 = 1
4: # on return
    lw      ra, 0(sp)                     # restore return addr
    addi    sp, sp, 4
    ret


#-------------------------------------------------------------------------------
# test_comparisons
#
# Register Usage:
#   s0: a
#   s1: b
#   s2: c
#
#-------------------------------------------------------------------------------
test_comparisons:
    # Callee save
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    sw      s1, 4(sp)
    sw      s2, 0(sp)

    li      s0, 0x3f80                    # a = 1.0
    li      s1, 0x4000                    # b = 2.0
    li      s2, 0x3f80                    # c = 1.0

    # Test bf16_eq
    mv      a0, s0                        # a0 = a
    mv      a1, s2                        # a1 = c
    jal     ra, bf16_eq                   # bf16_eq(a, c)
    beq     x0, a0, 1f                    # if (a != c) go to fail

    mv      a0, s0                        # a0 = a
    mv      a1, s1                        # a1 = b
    jal     ra, bf16_eq                   # bf16_eq(a, b)
    bne     x0, a0, 1f                    # if (a == b) go to fail

    # Test bf16_lt
    mv      a0, s0                        # a0 = a
    mv      a1, s1                        # a1 = b
    jal     ra, bf16_lt                   # bf16_lt(a, b)
    beq     x0, a0, 1f                    # if (!(a < b)) go to fail

    mv      a0, s1                        # a0 = b
    mv      a1, s0                        # a1 = a
    jal     ra, bf16_lt                   # bf16_lt(b, a)
    bne     x0, a0, 1f                    # if (b < a) go to fail

    mv      a0, s0                        # a0 = a
    mv      a1, s2                        # a1 = c
    jal     ra, bf16_lt                   # bf16_lt(a, c)
    bne     x0, a0, 1f                    # if (a < c) go to fail

    # Test bf16_gt
    mv      a0, s1                        # a0 = b
    mv      a1, s0                        # a1 = a
    jal     ra, bf16_gt                   # bf16_gt(b, a)
    beq     x0, a0, 1f                    # if (!(b > a)) go to fail

    mv      a0, s0                        # a0 = a
    mv      a1, s1                        # a1 = b
    jal     ra, bf16_gt                   # bf16_gt(a, b)
    bne     x0, a0, 1f                    # if (a > b) go to fail

    # Test NaN
    li      s1, BF16_NAN                  # s1 = NaN
    mv      a0, s1                        # a0 = NaN
    mv      a1, s1                        # a1 = NaN
    jal     ra, bf16_eq                   # bf16_eq(NaN, NaN)
    bne     x0, a0, 1f                    # if (NaN == NaN) go to fail

    mv      a0, s1                        # a0 = NaN
    mv      a1, s0                        # a1 = a
    jal     ra, bf16_lt                   # bf16_lt(NaN, a)
    bne     x0, a0, 1f                    # if (NaN < a) go to fail

    mv      a0, s1                        # a0 = NaN
    mv      a1, s0                        # a1 = a
    jal     ra, bf16_gt                   # bf16_gt(NaN, a)
    bne     x0, a0, 1f                    # if (NaN > a) go to fail

    # Print passed message
    li      a7, 4
    la      a0, comparison_passed_msg
    ecall

    li      a0, 0
    j       2f

1: # fail
    li      a0, 1

2: # on return
    # Callee restore
    lw      s2, 0(sp)
    lw      s1, 4(sp)
    lw      s0, 8(sp)
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret


#-------------------------------------------------------------------------------
# textfixture
# Test the given function with the provided input and golden data
#
# Arguments:
#   a0: address of the function to test
#   a1: address of input data
#   a2: address of golden data
#   a3: number of arguments of the test function (1 or 2)
#   a4: number of test data
#
# Returns:
#   a0: 0 if all tests passed, 1 if any test failed
#
# Register Usage:
#   s0: i
#   s1: func_addr
#   s2: input_data_addr
#   s3: golden_data_addr
#   s4: num_args
#   s5: num_test_data
#   s6: func(a0) or func(a0, a1)
#   s7: golden_data[i]
#
#-------------------------------------------------------------------------------
textfixture:
    # Callee save
    addi    sp, sp, -36
    sw      ra, 32(sp)
    sw      s0, 28(sp)
    sw      s1, 24(sp)
    sw      s2, 20(sp)
    sw      s3, 16(sp)
    sw      s4, 12(sp)
    sw      s5, 8(sp)
    sw      s6, 4(sp)
    sw      s7, 0(sp)

    li      s0, 0                         # i = 0
    mv      s1, a0                        # func_addr
    mv      s2, a1                        # input_data_addr
    mv      s3, a2                        # golden_data_addr
    mv      s4, a3                        # num_args
    mv      s5, a4                        # num_test_data

    bge     s0, s5, 5f                    # if (i >= num_test_data) go to pass

    # Determine the number of arguments to load
    li      t0, 1
    sub     t1, s4, t0                    # t1 = num args - 1
    beqz    t1, 2f                        # if (num args - 1 == 0) go to one_arg

1: # two_args
    lw      a0, 0(s2)                     # a0 = input_data[i*2]
    lw      a1, 4(s2)                     # a1 = input_data[i*2 + 1]
    jalr    ra, s1, 0                     # func(a0, a1)

    mv      s6, a0                        # s6 = result
    lw      s7, 0(s3)                     # s7 = golden_data[i]

    # Print for debugging
    # mv      a0, s6
    # mv      a1, s7
    # jal     ra, print

    bne     s6, s7, 4f                    # compare s6, s7


    addi    s0, s0, 1                     # i++
    addi    s2, s2, 8                     # input_data += 8
    addi    s3, s3, 4                     # golden_data += 4
    blt     s0, s5, 1b                    # if (i < num_test_data) go to two_args
    j       3f

2: # one_arg
    lw      a0, 0(s2)                     # a0 = input_data[i]
    jalr    ra, s1, 0                     # test_function(a0)

    mv      s6, a0                        # s6 = result
    lw      s7, 0(s3)                     # s7 = golden_data[i]

    # Print for debugging
    # mv      a0, s6
    # mv      a1, s7
    # jal     ra, print

    bne     s6, s7, 4f                    # compare s6, s7

    addi    s0, s0, 1                     # i++
    addi    s2, s2, 4                     # input_data += 4
    addi    s3, s3, 4                     # golden_data += 4
    blt     s0, s5, 2b                    # if (i < num_test_data) go to one_arg

3: # pass
    li      a0, 0                         # return 0
    j       5f

4: # fail
    li      a0, 1                         # return 1

5: # on return

    # Callee restore
    lw      s7, 0(sp)
    lw      s6, 4(sp)
    lw      s5, 8(sp)
    lw      s4, 12(sp)
    lw      s3, 16(sp)
    lw      s2, 20(sp)
    lw      s1, 24(sp)
    lw      s0, 28(sp)
    lw      ra, 32(sp)
    addi    sp, sp, 36

    ret


#-------------------------------------------------------------------------------
# print
# Print 2 bfloat16 numbers (result and golden) for debugging
#
# Arguments:
#   a0: bf16 a (result)
#   a1: bf16 b (golden)
#
# Register Usage:
#   s0: a
#   s1: b
#
#-------------------------------------------------------------------------------
print:
    addi    sp, sp, -12
    sw      ra, 8(sp)
    sw      s0, 4(sp)
    sw      s1, 0(sp)

    mv      s0, a0
    mv      s1, a1

    li      a7, 4                         # print string
    la      a0, result_msg
    ecall

    li      a7, 2                         # print float
    mv      a0, s0
    jal     ra, bf16_to_f32
    ecall

    li      a7, 4                         # print string
    la      a0, golden_msg
    ecall

    li      a7, 2                         # print float
    mv      a0, s1
    jal     ra, bf16_to_f32
    ecall

    li      a7, 4                         # print newline
    la      a0, endline
    ecall

    lw      s1, 0(sp)
    lw      s0, 4(sp)
    lw      ra, 8(sp)
    addi    sp, sp, 12
    ret


#-------------------------------------------------------------------------------
# mul
# Multiplies two word by shift-and-add algorithm.
#
# Arguments:
#   a0 = multiplicand
#   a1 = multiplier
#
# Returns:
#   a0 = a0 * a1
#
# Side effects:
#   None
#
#-------------------------------------------------------------------------------
mul:
    addi    sp, sp, -4
    sw      ra, 0(sp)

    li      t0, 0
1:
    andi    t1, a1, 1                     # Check LSB of multiplier
    beq     t1, x0, 8                     # If LSB is 0, skip add(next instruction)
    add     t0, t0, a0
    slli    a0, a0, 1                     # multiplicand <<= 1
    srli    a1, a1, 1                     # multiplier >>= 1
    bnez    a1, 1b                        # Repeat if multiplier != 0

    mv      a0, t0

    lw      ra, 0(sp)
    addi    sp, sp, 4
    ret


#-------------------------------------------------------------------------------
# f32_to_bf16
# Convert a float32 number to bfloat16
#
# Arguments:
#   a0: float32
#
# Returns:
#   a0: bfloat16
#
# Register Usage:
#   t0: f32bits
#
#-------------------------------------------------------------------------------
f32_to_bf16:
    mv      t0, a0                        # f32bits = val
    srli    t1, t0, 23                    # t1 = f32bits >> 23
    andi    t1, t1, 0xFF                  # t1 = (f32bits >> 23) & 0xFF, i.e. exponent

    li      t2, 0xFF                      # t2 = 0xFF
    beq     t1, t2, 1f                    # if (t1 == 0xFF) go to 1 (NaN or Inf)

    srli    t1, t0, 16                    # t1 = f32bits >> 16
    andi    t1, t1, 1                     # t1 = (f32bits >> 16) & 1
    li      t2, 0x7FFF                    # t2 = 0x7FFF
    add     t3, t1, t2                    # t3 = ((f32bits >> 16) & 1) + 0x7FFF
    add     t0, t0, t3                    # f32bits += ((f32bits >> 16) & 1) + 0x7FFF
    srli    t0, t0, 16
    j       2f
1: # case of NaN or Inf
    srli    t0, t0, 16                    # f32bits >>= 16
    li      t1, 0xFFFF
    and     t0, t0, t1                    # f32bits &= 0xFFFF
2: # on return
    mv      a0, t0                        # return val = f32bits
    ret


#-------------------------------------------------------------------------------
# bf16_to_f32
# Convert a bfloat16 number to float32
#
# Arguments:
#   a0: bfloat16
#
# Returns:
#   a0: float32
#
#-------------------------------------------------------------------------------
bf16_to_f32:
    slli    a0, a0, 16
    ret


#-------------------------------------------------------------------------------
# bf16_isinf
# Check if a bfloat16 number is infinity
#
# Arguments:
#   a0: bf16
#
# Returns:
#   a0: 1 if bf16 is infinity, 0 otherwise
#
#-------------------------------------------------------------------------------
bf16_isinf:
    li      t0, BF16_EXP_MASK
    li      t1, BF16_MANT_MASK
    and     t2, a0, t0                    # t2 = bf16 & BF16_EXP_MASK
    bne     t2, t0, 1f                    # if (t2 != BF16_EXP_MASK) go to 1
    and     t2, a0, t1                    # t2 = bf16 & BF16_MANT_MASK
    bne     t2, x0, 1f                    # if (t2 != 0) go to 1
    li      a0, 1                         # return 1
    ret
1: # not inf
    li      a0, 0                         # return 0
    ret


#-------------------------------------------------------------------------------
# bf16_isnan
# Check if a bfloat16 number is NaN
#
# Arguments:
#   a0: bf16
#
# Returns:
#   a0: 1 if bf16 is NaN, 0 otherwise
#
#-------------------------------------------------------------------------------
bf16_isnan:
    li      t0, BF16_EXP_MASK
    li      t1, BF16_MANT_MASK
    and     t2, a0, t0                    # t2 = bf16 & BF16_EXP_MASK
    bne     t2, t0, 1f                    # if (t2 != BF16_EXP_MASK) go to 1
    and     t2, a0, t1                    # t2 = bf16 & BF16_MANT_MASK
    beq     t2, x0, 1f                    # if (t2 == 0) go to 1
    li      a0, 1                         # return 1
    ret
1: # not nan
    li      a0, 0                         # return 0
    ret

#-------------------------------------------------------------------------------
# bf16_iszero
# Check if a bfloat16 number is zero
#
# Arguments:
#   a0: bf16
#
# Returns:
#   a0: 1 if bf16 is zero, 0 otherwise
#
#-------------------------------------------------------------------------------
bf16_iszero:
    li      t0, 0x7FFF                    # t0 = 0x7FFF
    and     t1, a0, t0                    # t1 = bf16 & 0x7FFF
    bne     t1, x0, 1f                    # if (t1 != 0) go to 1
    li      a0, 1
    ret
1: # not zero
    li      a0, 0
    ret


#-------------------------------------------------------------------------------
# bf16_add
# Add two bfloat16 numbers
#
# Arguments:
#   a0: a
#   a1: b
#
# Returns:
#   a0: a + b
#
# Register Usage:
#   s0: sign_a
#   s1: sign_b
#   s2: exp_a (signed int)
#   s3: exp_b (signed int)
#   s4: mant_a
#   s5: mant_b
#   s6: exp_diff (signed int)
#   s7: result_sign
#   s8: result_exp (signed int)
#   s9: result_mant
#
#-------------------------------------------------------------------------------
bf16_add:
    addi    sp, sp, -44
    sw      ra, 40(sp)                    # store return addr
    sw      s0, 36(sp)                    # store s0
    sw      s1, 32(sp)                    # store s1
    sw      s2, 28(sp)                    # store s2
    sw      s3, 24(sp)                    # store s3
    sw      s4, 20(sp)                    # store s4
    sw      s5, 16(sp)                    # store s5
    sw      s6, 12(sp)                    # store s6
    sw      s7, 8(sp)                     # store s7
    sw      s8, 4(sp)                     # store s8
    sw      s9, 0(sp)                     # store s9

    # sign_a
    srli    s0, a0, 15                    # sign_a = a >> 15
    andi    s0, s0, 1                     # sign_a &= 1

    # sign_b
    srli    s1, a1, 15                    # sign_b = b >> 15
    andi    s1, s1, 1                     # sign_b &= 1

    # exp_a
    srli    s2, a0, 7                     # exp_a = a >> 7
    andi    s2, s2, 0xFF                  # exp_a &= 0xFF

    # exp_b
    srli    s3, a1, 7                     # exp_b = b >> 7
    andi    s3, s3, 0xFF                  # exp_b &= 0xFF

    # mant_a
    andi    s4, a0, 0x7F                  # mant_a = a & 0x7F

    # mant_b
    andi    s5, a1, 0x7F                  # mant_b = b & 0x7F

    # Check exp of a to see if NaN or Inf
    li      t0, 0xFF                      # t0 = 0xFF
    bne     s2, t0, 2f                    # if (exp_a != 0xFF) go to 2

    bne     x0, s4, return_a_add_bf16     #   if (mant_a) return a

    bne     s3, t0, 1f                    #   if (exp_b != 0xFF) go to 1
    sub     t0, s0, s1                    #     sign_a != sign_b
    not     t0, t0                        #     t0 = (sign_a == sign_b)
    or      t0, s5, t0                    #     t0 = (mant_b || sign_a == sign_b)
    bne     x0, t0, return_b_add_bf16     #     if (mant_b || sign_a == sign_b) return b
    li      a0, BF16_NAN                  #     else return BF16_NAN
    j       on_return_add_bf16            # on return
1:
    j       return_a_add_bf16             #   return a
2: # End check exp of a

    # Check exp of b
    li      t0, 0xFF
    beq     s3, t0, return_b_add_bf16     # if (exp_b == 0xFF) return b

    bne     x0, s2, 1f                    # if (exp_a != 0) go to 1
    beq     x0, s4, return_b_add_bf16     # if (mant_a == 0) return b
1:

    bne     x0, s3, 1f                    # if (exp_b != 0) go to 1
    beq     x0, s5, return_a_add_bf16     # if (mant_b == 0) return a
1:

    # Check exp of a to see if needed to add implicit leading 1
    beq     x0, s2, 1f                    # if (!exp_a) go to 1
    ori     s4, s4, 0x80                  #   mant_a |= 0x80

1:
    # Check exp of b to see if needed to add implicit leading 1
    beq     x0, s3, 1f                    # if (!exp_b) go to 1
    ori     s5, s5, 0x80                  #   mant_b |= 0x80

1:
    # exp_diff
    sub     s6, s2, s3                    # exp_diff = exp_a - exp_b

    # Check for exp_diff > 0
    ble     s6, x0, 1f                    # if (exp_diff <= 0) go to 1
    mv      s8, s2                        #   result_exp = exp_a
    li      t0, 8                         #   t0 = 8
    bgt     s6, t0, return_a_add_bf16     #   if (exp_diff > 8) return a
    srl     s5, s5, s6                    #   mant_b >>= exp_diff
    j       3f
1:
    # Check for exp_diff < 0
    bge     s6, x0, 2f                    # if (exp_diff >= 0) go to 2
    mv      s8, s3                        #   result_exp = exp_b
    li      t0, -8
    blt     s6, t0, return_b_add_bf16     #   if (exp_diff < -8) return b
    neg     t0, s6                        #   t0 = -exp_diff
    srl     s4, s4, t0                    #   mant_a >>= -exp_diff
    j       3f
2:
    # The else case
    mv      s8, s2                        # else result_exp = exp_a
3:

# Check if (sign_a == sign_b)
    bne     s0, s1, 1f                    # if (sign_a != sign_b) go to 1
    mv      s7, s0                        #   result_sign = sign_a
    add     s9, s4, s5                    #   result_mant = mant_a + mant_b

    andi    t0, s9, 0x100                 #   t0 = result_mant & 0x100
    beq     x0, t0, 3f                    #   if (!result_mant & 0x100) go to 3

    srli    s9, s9, 1                     #   result_mant >>= 1

    addi    s8, s8, 1                     #   ++result_exp
    li      t0, 0xFF                      #   t0 = 0xFF
    blt     s8, t0, 3f                    #   if (result_exp < 0xFF) go to 3
    slli    a0, s7, 15                    #   a0 = result_sign << 15
    li      t0, 0x7F80                    #   t0 = 0x7F80
    or      a0, a0, t0                    #   a0 |= 0x7F80 (return +Inf)
    j       on_return_add_bf16            #   on return
1: # else
# Check if (mant_a >= mant_b)
    blt     s4, s5, 1f                    # if (mant_a < mant_b) go to 1
    mv      s7, s0                        #   result_sign = sign_a
    sub     s9, s4, s5                    #   result_mant = mant_a - mant_b
    j       2f
1: # else
    mv      s7, s1                        #   result_sign = sign_b
    sub     s9, s5, s4                    #   result_mant = mant_b - mant_a
2:

# Check if (!result_mant)
    beq     x0, s9, return_zero_add_bf16  # if (result_mant == 0) return bf16_zero

1: # while loop for normalize
    andi    t0, s9, 0x80                  # t0 = result_mant & 0x80
    bne     x0, t0, 3f                    # if (t0 != 0) go to 3
    slli    s9, s9, 1                     # result_mant <<= 1
    addi    s8, s8, -1                    # --result_exp
    ble     s8, x0, return_zero_add_bf16  # if (result_exp <= 0) return bf16_zero
    j       1b
3: # end while

    # return value
    slli    a0, s7, 15                    # a0 = result_sign << 15
    andi    t0, s8, 0xFF                  # t0 = result_exp & 0xFF
    slli    t0, t0, 7                     # t0 <<= 7
    or      a0, a0, t0                    # a0 |= (result_exp & 0xFF) << 7
    andi    t0, s9, 0x7F                  # t0 = result_mant & 0x7F
    or      a0, a0, t0                    # a0 |= (result_mant & 0x7F)
    j       on_return_add_bf16            # on return

return_a_add_bf16:
    j       on_return_add_bf16
return_b_add_bf16:
    mv      a0, a1
    j       on_return_add_bf16
return_zero_add_bf16:
    li      a0, BF16_ZERO
    j       on_return_add_bf16
on_return_add_bf16:
    lw      s9, 0(sp)                     # restore s9
    lw      s8, 4(sp)                     # restore s8
    lw      s7, 8(sp)                     # restore s7
    lw      s6, 12(sp)                    # restore s6
    lw      s5, 16(sp)                    # restore s5
    lw      s4, 20(sp)                    # restore s4
    lw      s3, 24(sp)                    # restore s3
    lw      s2, 28(sp)                    # restore s2
    lw      s1, 32(sp)                    # restore s1
    lw      s0, 36(sp)                    # restore s0
    lw      ra, 40(sp)                    # restore return addr
    addi    sp, sp, 44
    ret


#-------------------------------------------------------------------------------
# bf16_sub
# Subtract two bfloat16 numbers
#
# Arguments:
#   a0: a
#   a1: b
#
# Returns:
#   a0: a - b
#
#-------------------------------------------------------------------------------
bf16_sub:
    addi    sp, sp, -4
    sw      ra, 0(sp)                     # store return addr

    li      t0, BF16_SIGN_MASK
    xor     a1, a1, t0                    # b = -b
    jal     ra, bf16_add

    lw      ra, 0(sp)                     # restore return addr
    addi    sp, sp, 4
    ret


#-------------------------------------------------------------------------------
# bf16_mul
# Multiply two bfloat16 numbers
#
# Arguments:
#   a0: a
#   a1: b
#
# Returns:
#   a0: a * b
#
# Register Usage:
#   s0: sign_a
#   s1: sign_b
#   s2: exp_a (signed int)
#   s3: exp_b (signed int)
#   s4: mant_a
#   s5: mant_b
#   s6: result_sign
#   s7: exp_adjust (signed int)
#   s8: result_mant
#   s9: result_exp (signed int)
#
#-------------------------------------------------------------------------------
bf16_mul:
    # Callee save
    addi    sp, sp, -44
    sw      ra, 40(sp)
    sw      s0, 36(sp)
    sw      s1, 32(sp)
    sw      s2, 28(sp)
    sw      s3, 24(sp)
    sw      s4, 20(sp)
    sw      s5, 16(sp)
    sw      s6, 12(sp)
    sw      s7, 8(sp)
    sw      s8, 4(sp)
    sw      s9, 0(sp)

    # sign_a
    srli    s0, a0, 15                    # sign_a = a >> 15
    andi    s0, s0, 1                     # sign_a &= 1

    # sign_b
    srli    s1, a1, 15                    # sign_b = b >> 15
    andi    s1, s1, 1                     # sign_b &= 1

    # exp_a
    srli    s2, a0, 7                     # exp_a = a >> 7
    andi    s2, s2, 0xFF                  # exp_a &= 0xFF

    # exp_b
    srli    s3, a1, 7                     # exp_b = b >> 7
    andi    s3, s3, 0xFF                  # exp_b &= 0xFF

    # mant_a
    andi    s4, a0, 0x7F                  # mant_a = a & 0x7F

    # mant_b
    andi    s5, a1, 0x7F                  # mant_b = b & 0x7F

    # result_sign
    xor     s6, s0, s1                    # result_sign = sign_a ^ sign_b

    # Check for NaN or Inf
    li      t0, 0xFF                      # t0 = 0xFF
    bne     s2, t0, 2f                    # if (exp_a != 0xFF) skip to 2
    bnez    s4, return_a_bf16_mul         # if (mant_a) return a (= NaN)
    bnez    s3, 1f
    bnez    s5, 1f
    j       return_nan_bf16_mul           # if (!exp_b && !mant_b) return NaN
1:
    j       return_inf_bf16_mul           # else return Inf


2:
    bne     s3, t0, 2f                    # if (exp_b != 0xFF) skip to 2
    bnez    s5, return_b_bf16_mul
    bnez    s2, 1f
    bnez    s4, 1f
    j       return_nan_bf16_mul           # if (!exp_a && !mant_a) return NaN
1:
    j       return_inf_bf16_mul           # else return Inf

2:
    # Check for zero
    seqz    t0, s2                        # t0 = !exp_a
    seqz    t1, s3                        # t1 = !exp_b
    and     t0, t0, t1                    # t0 = !exp_a && !exp_b

    seqz    t1, s3                        # t1 = !exp_b
    seqz    t2, s5                        # t2 = !mant_b
    and     t1, t1, t2                    # t1 = !exp_b && !mant_b
    or      t0, t0, t1                    # t0

    bne     x0, t0, return_zero_bf16_mul  # if (t0) return zero

    # exp_adjust
    li      s7, 0                         # exp_adjust = 0

    bnez    s2, 3f                        # if (exp_a) skip to 3
1: # while loop
    andi    t0, s4, 0x80
    bnez    t0, 2f                        # while (!(mant_a & 0x80))

    slli    s4, s4, 1                     # mant_a <<= 1
    addi    s7, s7, -1                    # --exp_adjust

    j       1b                            # repeat
2: # end loop
    li      s2, 1                         # exp_a = 1
    j       4f
3: # else case
    ori     s4, s4, 0x80                  # mant_a |= 0x80

4:
    bnez    s3, 3f                        # if (exp_b) skip to 3
1: # while loop
    andi    t0, s5, 0x80
    bnez    t0, 2f                        # while (!(mant_b & 0x80))

    slli    s5, s5, 1                     # mant_b <<= 1
    addi    s7, s7, -1                    # --exp_adjust

    j       1b                            # repeat
2: # end loop
    li      s3, 1                         # exp_b = 1
    j       4f
3: # else case
    ori     s5, s5, 0x80                  # mant_b |= 0x80

4:
    # result_mant
    mv      a0, s4                        # a0 = mant_a
    mv      a1, s5                        # a1 = mant_b
    jal     ra, mul
    mv      s8, a0                        # result_mant = mul(mant_a, mant_b)

    # result_exp
    add     s9, s2, s3                    # result_exp = exp_a + exp_b
    add     s9, s9, s7                    # result_exp += exp_adjust
    addi    s9, s9, -BF16_EXP_BIAS        # result_exp -= BF16_EXP_BIAS

    li      t0, 0x8000
    and     t0, s8, t0                    # t0 = result_mant & 0x8000
    beqz    t0, 1f                        # if (!(result_mant & 0x8000)) go to else

    srli    s8, s8, 8                     # result_mant >>= 8
    andi    s8, s8, 0x7F                  # result_mant &= 0x7F
    addi    s9, s9, 1                     # result_exp++
    j       2f
1: # else
    srli    s8, s8, 7                     # result_mant >>= 7
    andi    s8, s8, 0x7F                  # result_mant &= 0x7F

2: # join
    li      t0, 0xFF                      # t0 = 0xFF
    bge     s9, t0, return_inf_bf16_mul   # if (result_exp >= 0xFF) return Inf

    bgt     s9, x0, 1f                    # if (result_exp > 0) skip to 1
    li      t0, -6
    blt     s9, t0, return_zero_bf16_mul  # if (result_exp < -6) return zero
    li      t0, 1                         # t0 = 1
    sub     t0, t0, s9                    # t0 = 1 - result_exp
    srl     s8, s8, t0                    # result_mant >>= (1 - result_exp)
    li      s9, 0                         # result_exp = 0

1:
    # return value
    slli    a0, s6, 15                    # a0 = result_sign << 15
    andi    t0, s9, 0xFF                  # t0 = result_exp & 0xFF
    slli    t0, t0, 7                     # t0 <<= 7
    or      a0, a0, t0                    # a0 |= (result_exp & 0xFF) << 7
    andi    t0, s8, 0x7F                  # t0 = result_mant & 0x7F
    or      a0, a0, t0                    # a0 |= (result_mant & 0x7F)
    j       on_return_bf16_mul            # on return

return_a_bf16_mul:
    j       on_return_bf16_mul

return_b_bf16_mul:
    mv      a0, a1
    j       on_return_bf16_mul

return_zero_bf16_mul:
    slli    a0, s6, 15                    # a0 = result_sign << 15
    j       on_return_bf16_mul

return_nan_bf16_mul:
    li      a0, BF16_NAN                  # return NaN
    j       on_return_bf16_mul

return_inf_bf16_mul:
    slli    a0, s6, 15                    # a0 = result_sign << 15
    li      t0, 0x7F80                    # t0 = 0x7F80
    or      a0, a0, t0                    # a0 |= 0x7F80

on_return_bf16_mul:
    # Callee restore
    lw      s9, 0(sp)
    lw      s8, 4(sp)
    lw      s7, 8(sp)
    lw      s6, 12(sp)
    lw      s5, 16(sp)
    lw      s4, 20(sp)
    lw      s3, 24(sp)
    lw      s2, 28(sp)
    lw      s1, 32(sp)
    lw      s0, 36(sp)
    lw      ra, 40(sp)
    addi    sp, sp, 44
    ret


bf16_div:
    ret


bf16_sqrt:
    ret


#-------------------------------------------------------------------------------
# bf16_eq
#
# Arguments:
#   a0: a
#   a1: b
#
# Returns:
#   a0: 1 if a == b, 0 otherwise
#
# Register Usage:
#   s0: a
#   s1: b
#
#-------------------------------------------------------------------------------
bf16_eq:
    # Callee save
    addi    sp, sp, -12
    sw      ra, 8(sp)
    sw      s0, 4(sp)
    sw      s1, 0(sp)

    mv      s0, a0                        # s0 = a
    mv      s1, a1                        # s1 = b

    # Check for NaN
    jal     ra, bf16_isnan                # bf16_isnan(a)
    bne     x0, a0, 2f                    # if (a == NaN) return false
    mv      a0, s1                        # a0 = b
    jal     ra, bf16_isnan                # bf16_isnan(b)
    bne     x0, a0, 2f                    # if (b == NaN) return false

    # Check for zero
    mv      a0, s0                        # a0 = a
    jal     ra, bf16_iszero               # bf16_iszero(a)
    mv      t0, a0                        # t0 = (a == 0)
    mv      a0, s1                        # a0 = b
    jal     ra, bf16_iszero               # bf16_iszero(b)
    and     t0, t0, a0                    # t0 = (a == 0 && b == 0)
    bne     x0, t0, 1f                    # if (a == 0 && b == 0) return true

    # Compare values
    sub     t0, s0, s1                    # t0 = a - b
    bne     x0, t0, 2f                    # if (a != b) return false

1: # return true
    li      a0, 1
    j       3f

2: # return false
    li      a0, 0

3: # on return
    # Callee restore
    lw      s1, 0(sp)
    lw      s0, 4(sp)
    lw      ra, 8(sp)
    addi    sp, sp, 12
    ret


#-------------------------------------------------------------------------------
# bf16_lt
#
# Arguments:
#   a0: a
#   a1: b
#
# Returns:
#   a0: 1 if a < b, 0 otherwise
#
# Register Usage:
#   s0: a
#   s1: b
#
#-------------------------------------------------------------------------------
bf16_lt:
    # Callee save
    addi    sp, sp, -20
    sw      ra, 16(sp)
    sw      s0, 12(sp)
    sw      s1, 8(sp)
    sw      s2, 4(sp)
    sw      s3, 0(sp)

    mv      s0, a0                        # s0 = a
    mv      s1, a1                        # s1 = b

    # Check for NaN
    jal     ra, bf16_isnan                # bf16_isnan(a)
    bne     x0, a0, 4f                    # if (a == NaN) return false
    mv      a0, s1                        # a0 = b
    jal     ra, bf16_isnan                # bf16_isnan(b)
    bne     x0, a0, 4f                    # if (b == NaN) return false

    # Check for zero
    mv      a0, s0                        # a0 = a
    jal     ra, bf16_iszero               # bf16_iszero(a)
    mv      t0, a0                        # t0 = (a == 0)
    mv      a0, s1                        # a0 = b
    jal     ra, bf16_iszero               # bf16_iszero(b)
    and     t0, t0, a0                    # t0 = (a == 0 && b == 0)
    bne     x0, t0, 4f                    # if (a == 0 && b == 0) return false

    # sign_a
    srli    s2, s0, 15                    # sign_a = a >> 15
    andi    s2, s2, 1                     # sign_a = (a >> 15) & 1

    # sign_b
    srli    s3, s1, 15                    # sign_b = b >> 15
    andi    s3, s3, 1                     # sign_b = (b >> 15) & 1

    # Check for sign_a != sign_b
    bne     s2, s3, 1f                    # if (sign_a != sign_b) go to 1

    bnez    s2, 1f                        # if (sign_a) return a > b
    sltu    t0, s0, s1                    # t0 = (a < b) ? 1 : 0
    bnez    t0, 3f
    j       4f                            # return false

1: # return a > b
    sltu    t0, s1, s0                    # t0 = (b < a) ? 1 : 0
    bnez    t0, 3f                        # if (b < a) return true
    j       4f                            # else return false

2: # sign_a != sign_b
    sub     t0, s2, s3                    # t0 = sign_a - sign_b
    blt     x0, t0, 4f                    # if (sign_a == 0 && sign_b == 1) return false

3: # return true
    li      a0, 1
    j       5f                            # go to on return

4: # return false
    li      a0, 0

5: # on return
    lw      s3, 0(sp)
    lw      s2, 4(sp)
    lw      s1, 8(sp)
    lw      s0, 12(sp)
    lw      ra, 16(sp)
    addi    sp, sp, 20
    ret


#-------------------------------------------------------------------------------
# bf16_gt
#
# Arguments:
#   a0: a
#   a1: b
#
# Returns:
#   a0: 1 if a > b, 0 otherwise
#
#-------------------------------------------------------------------------------
bf16_gt:
    # Callee save
    addi    sp, sp, -4
    sw      ra, 0(sp)

    # Swap a and b and call bf16_lt
    mv      t0, a0                        # t0 = a
    mv      a0, a1                        # a0 = b
    mv      a1, t0                        # a1 = t0
    jal     ra, bf16_lt                   # bf16_lt(b, a)

    # Callee restore
    lw      ra, 0(sp)
    addi    sp, sp, 4
    ret
