GHDL=~/ghdl/ghdl-0.35-llvm-macosx/bin/ghdl
PROG=simty_output_test
VCD=$(addsuffix .vcd,$(PROG))

# Order matters
SRC=simty_pkg.vhd sram.vhd targetdep_sim.vhd ffs.vhd csr.vhd branch_arbiter.vhd  crossbar.vhd banked_rf.vhd fetch_steering.vhd \
	memory_arbiter.vhd funnel_shifter.vhd salu.vhd      branch.vhd          decode.vhd    fetch.vhd \
	predecode.vhd       schedule.vhd    collect.vhd         execute.vhd   membership.vhd      replay.vhd \
	scratchpad.vhd testio.vhd load_fifo.vhd coalescing.vhd gather.vhd initialize.vhd convergence_tracker.vhd \
	cold_context_table.vhd hot_context_table.vhd context_compact_sort.vhd convergence_tracker_ct.vhd \
	instruction_memory.vhd graphics_memory.vhd simty.vhd instruction_rom.vhd bus_arbiter.vhd simty_test.vhd simty_output_test.vhd

OBJ=$(patsubst %.vhd,%.o,$(SRC))

sim: $(VCD)

#$(OBJ): $(SRC)
%.o: %.vhd
	$(GHDL) -a --std=08 --warn-unused $<

$(PROG): $(OBJ)
	$(GHDL) -e --std=08 Simty_Output_Test

$(VCD): $(PROG)
	#./simty_test --stop-time=200ns --vcd=$@
#	./simty_output_test --stop-time=2048000ns --vcd=$@
#	./simty_output_test --stop-time=2048000ns --vcd=$@
	./simty_output_test --stop-time=2000ns --vcd=$@

#	./simty_output_test --stop-time=8000ns


clean:
	rm -f $(OBJ) $(PROG)
