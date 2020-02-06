#include "defines.h"

.text

.global main
# 16 bits for the scratchpad for block addresses, so the last block would be 100F FFF-
# testio addresses start with 2

# Set up regular (non-interleaved) stack frames
.global _start
_start:
csrr a0, mhartid
#slli t0, a0, LOG_STACK_INTERLEAVING
slli t0, a0, 0x00B
#la sp, STACK_BASE
la sp, 0x1000FFFC	# last block in the stack
# 10010000 should be the end of the stack

sub sp, sp, t0
#jal ra, MAIN_START
jal ra, main

# csrr a5, mhartid
# slli a5, a5, 0x2 # mul by 4, because $ bytes per word, hence per thread
# lui a0, 0x10001 # source address in scratchpad
# #lui a0, 0x20000
# add a0, a0, a5 # per-thread offset
#
# lui a1, 0x20000 # destination address in testio
# #addi a1, a1, 0x120
# add a1, a1, a5
# li a2, 0x20 # 32 iterations, because there are 32 threads per iteration, so that covers 1024 writes
# li a3, 0x0

# copyloop:
# 	lw a4, 0(a0)
# 	sw a4, 0(a1)
# 	addi a0, a0, 0x80 # 32 threads * 4 bytes per thread
# 	addi a1, a1, 0x80
# 	addi a3, a3, 0x1
# 	blt a3, a2, copyloop

lui a0, 0x2FFFF
#addi a0, a0, 0x0
sw zero, 0(a0)



infiniteLoop: j infiniteLoop
