.text
.global _start
_start:
	addi a2, x0, 42	# color
	lui s0, 0x01010
	addi s0, s0, 0x101	# increment
	lui s1, 0x00001 # window size
	lui a0, 0x00000	# vga window
mainloop:
	csrr a1, mhartid
	slli a1, a1, 2	# counter
screenloop:
	add t0, a0, a1	# address
	sw a2, 0(t0)
	addi a1, a1, 32	# add thread count
	blt a1, s1, screenloop
	
	add a2, a2, s0
	j mainloop
