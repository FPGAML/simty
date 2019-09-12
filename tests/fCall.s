.text
.global _start
_start:
	la sp, 0x10000000

labOne:
	jal labTwo
	jal labThree
	j endLab

labTwo:
	addi sp, sp, -16
	lw s0, 12(sp)
	ret

labThree:
	ret

endLab:
	j endLab
