.text
.global _start
_start:
	lui	a3, 0x00000	# VGA space
	#addi a3, a3, 0x00000 # address 0 in VGA memory

	lui a4, 0x10000 # scratchpad space
	#addi a4, a4, 0x0000 # address 0 in scratchpad

	lui a5, 0x20000 # testio space
	#addi a5, a5, 0x0000 # address 0

	lui a6, 0x00000
	addi a6, a6, 0x001

	lui a7, 0x00000
	#addi a7, a7, 0x000

	# To get a certain number of iterations
	lui t1, 0x00000
	addi t1, t1, 0x006
vgawloop:
	# Storing to VGA memory
	sw a6, 0(a3)
	# Incrementing value to store and load
	addi a6, a6, 0x001
	# Incrementing block_address, and counter
	addi a3, a3, 0x010
	addi a7, a7, 0x001

	# Branch if counter < max iterations
	blt a7, t1, vgawloop

	# Reset counter
	lui a7, 0x00000

	# Reset address
	lui	a3, 0x00000	# VGA space

vgarloop:
	# Loading from VGA memory
	lw a6, 0(a3)

	# Incrementing block_address, and counter
	addi a3, a3, 0x010
	addi a7, a7, 0x001

	# Branch if counter < max iterations
	blt a7, t1, vgarloop

	# Reset counter
	lui a7, 0x00000
	#addi a7, a7, 0x000


scratchwloop:
	sw a6, 0(a4)
	addi a6, a6, 0x001

	addi a4, a4, 0x010
	addi a7, a7, 0x001

	blt a7, t1, scratchwloop

	# Reset counter
	lui a7, 0x00000

	# Reset address
	lui a4, 0x10000 # scratchpad space

scratchrloop:
	lw a6, 0(a4)

	addi a4, a4, 0x010
	addi a7, a7, 0x001

	blt a7, t1, scratchrloop

	# Reset counter
	lui a7, 0x00000

testiowloop:
	sw a6, 0(a5)
	addi a6, a6, 0x001

	addi a5, a5, 0x010
	addi a7, a7, 0x001

	blt a7, t1, testiowloop

	# Reset counter
	lui a7, 0x00000

	# Reset
	lui a5, 0x20000 # testio space

testiorloop:
	lw a6, 0(a5)

	addi a5, a5, 0x010
	addi a7, a7, 0x001

	blt a7, t1, testiorloop
