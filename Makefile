GHDL=~/usr/ghdl/bin/ghdl
PROG=simty_test
VCD=$(addsuffix .vcd,$(PROG))

# Order matters
SRC=simty_pkg.vhd sram.vhd targetdep_sim.vhd ffs.vhd csr.vhd branch_arbiter.vhd  crossbar.vhd banked_rf.vhd fetch_steering.vhd \
	memory_arbiter.vhd funnel_shifter.vhd salu.vhd      branch.vhd          decode.vhd    fetch.vhd \
	predecode.vhd       schedule.vhd    collect.vhd         execute.vhd   membership.vhd      replay.vhd \
	scratchpad.vhd load_fifo.vhd coalescing.vhd gather.vhd initialize.vhd convergence_tracker.vhd \
	cold_context_table.vhd hot_context_table.vhd context_compact_sort.vhd convergence_tracker_ct.vhd \
	instruction_memory.vhd graphics_memory.vhd simty.vhd instruction_rom.vhd simty_test.vhd

OBJ=$(patsubst %.vhd,%.o,$(SRC))

sim: $(VCD)

#$(OBJ): $(SRC)
%.o: %.vhd
	$(GHDL) -a --std=08 --warn-unused $<

$(PROG): $(OBJ)
	$(GHDL) -e --std=08 Simty_Test

$(VCD): $(PROG)
	./simty_test --stop-time=200ns --vcd=$@

clean:
	rm -f $(OBJ) $(PROG)

