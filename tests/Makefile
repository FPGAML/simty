all: rainbow.hex mandelbrot.hex

%.o: %.s
	riscv32-unknown-elf-as -c -o $@ -m32 $<
%.o: %.c
	riscv32-unknown-elf-gcc -c -m32 $<

rainbow: rainbow.o
	riscv32-unknown-elf-ld -o $@ --section-start=.text=0x200 $<

mandelbrot: mandelbrot.o
	riscv32-unknown-elf-ld -o $@ --section-start=.text=0x200 $<


%.hex: %
	elf2hex 4 256 $< > $@


