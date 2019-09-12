.text
.global _start
_start:
	addi a2, x0, 42	# color
	lui s0, 0x01010
	addi s0, s0, 0x101	# increment
	lui s1, 0x00001 # window size
	lui a0, 0x00000	# vga window

	# This is where things go wrong

	lui	a3, 0x00000	# VGA space
	addi a3, a3, 0x00000 # address 0 in VGA memory

	lui a4, 0x10000 # scratchpad space
	addi a4, a4, 0x0000 # address 0 in scratchpad

	lui a5, 0x20000 # testio space
	addi a5, a5, 0x0000 # address 0

	lui a6, 0x0000
	addi a6, a6, 0x0001
mainloop:
	sw a6, 0(a3)
	addi x0, x0, 0x0000
	lw a6, 0(a3)
	addi a6, a6, 0x0001

	sw a6, 0(a4)
	addi x0, x0, 0x0000
	lw a6, 0(a4)
	addi a6, a6, 0x0001

	sw a6, 0(a5)
	addi x0, x0, 0x0000
	lw a6, 0(a5)
	addi a6, a6, 0x0001

	addi a3, a3, 0x0010
	addi a4, a4, 0x0010
	addi a5, a5, 0x0010

	j mainloop

	csrr a1, mhartid
	slli a1, a1, 2	# counter
screenloop:
	add t0, a0, a1	# address
	sw a2, 0(t0)
	addi a1, a1, 32	# add thread count
	blt a1, s1, screenloop

	add a2, a2, s0
	j mainloop
