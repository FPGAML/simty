.text
.global _start
_start:
	csrr a4, mhartid
	mv a5, a4
	slli a5, a5, 0x1
	lui a0, 0x20006 # address in testio
	add a0, a0, a5 # threadId offset
	#li a1, 0x1 # stuff to write
#	li a2, 0x1 # counter
#	li a3, 0x20 # limit

writeloop:
	sh a4, 0(a0)
#	addi a2, a2, 0x1
#	addi a0, a0, 0x20
#	blt a2, a3, writeloop

	lui a0, 0x2FFFF
	sw zero, 0(a0)

plop:
	j plop
