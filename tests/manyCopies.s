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

	lui a6, 0x00000
	addi a6, a6, 0x001

	lui a7, 0x00000
	addi a7, a7, 0x000

	# To get 10 iterations
	lui t1, 0x00000
	addi t1, t1, 0x004
vgaloop:
	# Storing to and loading from VGA memory
	sw a6, 0(a3)
	lw a6, 0(a3)

	# Incrementing value to store and load
	addi a6, a6, 0x001

	# Incrementing block_address, and counter
	addi a3, a3, 0x010
	addi a7, a7, 0x001

	# Branch if counter == max iterations
	blt a7, t1, vgaloop

	# Reset counter
	lui a7, 0x00000
	addi a7, a7, 0x000

scratchloop:
	sw a6, 0(a4)
	lw a6, 0(a4)
	addi a6, a6, 0x001

	addi a4, a4, 0x010
	addi a7, a7, 0x001

	blt a7, t1, scratchloop

	# Reset counter
	lui a7, 0x00000
	addi a7, a7, 0x000

testioloop:
	sw a6, 0(a5)
	lw a6, 0(a5)
	addi a6, a6, 0x001

	addi a5, a5, 0x010
	addi a7, a7, 0x001

	blt a7, t1, testioloop
