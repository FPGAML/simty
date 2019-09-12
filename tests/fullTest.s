.text
.global _start
_start:
	lui a1, 0x00000
	addi a1, a1, 0x001 # to subtract

	lui	a3, 0x00000	# VGA space
	lui a4, 0x10000 # scratchpad space
	lui a5, 0x20000 # testio space

	lui a6, 0x00000 # working register
	lui a0, 0x00000 # reference register

	lui a7, 0x00000 # counter

	# To get a certain number of iterations
	lui t1, 0x00000
#	addi t1, t1, 0x003
	addi t1, t1, 0x020 # 32 for starters
#	addi t1, t1, 0x004

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

	bne a6, a0, error

	# Incrementing block_address, and counter
	addi a3, a3, 0x010
	addi a7, a7, 0x001

	# Incrementing reference register
	addi a0, a0, 0x001

	# Branch if counter < max iterations
	blt a7, t1, vgarloop

	# Reset counter
	lui a7, 0x00000

	# a0 = a0 - 1, because at this point a0 is 1 ahead of the value in a6
	# we could also do a move from a6, but that would rely on the memory working correctly, which what we're testing
	sub a0, a0, a1

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

	bne a6, a0, error

	addi a4, a4, 0x010
	addi a7, a7, 0x001

	addi a0, a0, 0x001

	blt a7, t1, scratchrloop

	# Reset counter
	lui a7, 0x00000

	# a0 = a0 - 1, because at this point a0 is 1 ahead of the value in a6
	# we could also do a move from a6, but that would rely on the memory working correctly, which what we're testing
	sub a0, a0, a1

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

	bne a6, a0, error

	addi a5, a5, 0x010
	addi a7, a7, 0x001

	addi a0, a0, 0x001

	blt a7, t1, testiorloop

	jal allgood

error:
	lui a0, 0xFFFFF
	addi a0, a0, -0x001
	jal end

allgood:
	lui a0, 0x00000
	addi a0, a0, 0x000

	lui a6, 0x00000
	addi a6, a6, 0x042

	lui a5, 0x2000F # testio space
	addi a5, a5, 0x7FF # FFF
	addi a5, a5, 0x700
	addi a5, a5, 0x100

	# addi a5, a5, 0x3F0		# 4F0 is somehow too much
	# nop
	# addi a5, a5, 0x030
	#
	# sw a6, 0(a5)
	#
	# lui a5, 0x20000
	# addi a5, a5, -0x001

	sw a6, 0(a5) # store byte sinon ça devrait déborder

end:
	nop
