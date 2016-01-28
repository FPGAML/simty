all: rainbow.hex

%.o: %.s
	riscv32-unknown-elf-as -c -o $@ -m32 $<

rainbow: rainbow.o
	riscv32-unknown-elf-ld -o $@ --section-start=.text=0x200 $<

%.hex: %
	elf2hex 4 256 $< > $@


