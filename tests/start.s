#include "defines.h"

.text

.global main

# Set up regular (non-interleaved) stack frames
.global _start
_start:
csrr a0, mhartid
sli t0, a0, LOG_STACK_INTERLEAVING
la sp, STACK_BASE
add sp, sp, t0
#jal ra, MAIN_START
jal ra, main
