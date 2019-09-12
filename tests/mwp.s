.text
.global _start
_start:
	lui a0, 0x10000
	lui a1, 0x42000
	sw a1, 0(a0)
	#nop
	lw a2, 0(a0)
	#nop
	mv a3, a2
	#addi a3, a2, 0
	#lui a3, 0x10000
	#addi a3, a3, 0x010
	sw a2, 0(a0)
	sw a3, 0(a0)

plop:
	j plop
