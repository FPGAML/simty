#all: rainbow.hex mandelbrot.hex rainCopies.hex
all: rainbow.hex rainCopies.hex rainTinyCopies.hex rainbowPlusEpsilon.hex manyCopies.hex writeAndRead.hex fullTest.hex mandelbrot.hex fCall.hex mwp.hex
#all: rainbow.hex #rainCopies.hex
CFLAGS=-march=rv32i -mabi=ilp32

%.o: %.s
#	/opt/riscv/bin/riscv32-unknown-elf-as -c -o $@ -m32 $<
	/opt/riscv/bin/riscv32-unknown-elf-as -c $(CFLAGS) -o $@ $<

%.o: %.c
#	/opt/riscv/bin/riscv32-unknown-elf-gcc -c -m32 $<
	/opt/riscv/bin/riscv32-unknown-elf-gcc -c $(CFLAGS) $<


fCall: fCall.o
	/opt/riscv/bin/riscv32-unknown-elf-ld -o $@ --section-start=.text=0x200 $<

rainbow: rainbow.o
	/opt/riscv/bin/riscv32-unknown-elf-ld -o $@ --section-start=.text=0x200 $<

mandelbrot: start.o mandelbrot.o
	/opt/riscv/bin/riscv32-unknown-elf-ld -o $@ --section-start=.text=0x200 $^

rainCopies: rainCopies.o
	/opt/riscv/bin/riscv32-unknown-elf-ld -o $@ --section-start=.text=0x200 $<

rainTinyCopies: rainTinyCopies.o
	/opt/riscv/bin/riscv32-unknown-elf-ld -o $@ --section-start=.text=0x200 $<

rainbowPlusEpsilon: rainbowPlusEpsilon.o
	/opt/riscv/bin/riscv32-unknown-elf-ld -o $@ --section-start=.text=0x200 $<

manyCopies: manyCopies.o
	/opt/riscv/bin/riscv32-unknown-elf-ld -o $@ --section-start=.text=0x200 $<

writeAndRead: writeAndRead.o
	/opt/riscv/bin/riscv32-unknown-elf-ld -o $@ --section-start=.text=0x200 $<

fullTest: fullTest.o
	/opt/riscv/bin/riscv32-unknown-elf-ld -o $@ --section-start=.text=0x200 $<

mwp: mwp.o
	/opt/riscv/bin/riscv32-unknown-elf-ld -o $@ --section-start=.text=0x200 $<


%.hex: %
	/Users/kouyoumd/spike/riscv-isa-sim/build/elf2hex 4 1024 $< > $@
#	/Users/kouyoumd/spike/riscv-isa-sim/build/elf2hex 8 256 $< > $@

#	/Users/kouyoumd/elf2hex/elf2hex $< > $@

#	elf2hex 4 256 $< > $@
