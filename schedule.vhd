library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- Instruction buffer and instruction scheduler
-- Master for the backend. Obeys control, data dependencies and RF/exec resource constraints:
-- esp. RF bank arbitration
-- and control dependencies: bypass is not speculative!
entity Schedule is
	port (
		clock : in std_logic;
		reset : in std_logic;
		init : in std_logic;
		
		refill_mpc : in code_address;
		refill_wid : in warpid;
		refill_insn : in predecoded_instruction;
		ack_refill : out std_logic;

		accept_even : in std_logic;
		accept_odd : in std_logic;
		
		mem_wakeup_valid : in std_logic;	-- LD needs to assert this
		mem_wakeup_wid : in warpid;

		ready_insn : out predecoded_instruction;
		ready_mpc : out code_address;
		ready_wid : out warpid
	);
end entity;

architecture structural of Schedule is
	--type busy_type is array(0 to warpcount - 1) of std_logic;
	--signal busy : busy_type;
	signal busy : std_logic_vector(warpcount - 1 downto 0);
	signal valid : std_logic_vector(warpcount - 1 downto 0);
	type instruction_buffer_entry is record
		pc : code_address;
		insn : predecoded_instruction;
	end record;
	type instruction_buffer_t is array(0 to warpcount - 1) of instruction_buffer_entry;
	signal instruction_buffer : instruction_buffer_t;
	signal default_wid : warpid;
	signal issue_wid : warpid;
	signal schedulable : std_logic_vector(warpcount - 1 downto 0);
	signal none_schedulable : std_logic;
	signal is_longlatency : std_logic;
	
	signal issued_insn : predecoded_instruction;
	signal issued_mpc : code_address;
	signal issued_wid : warpid;
	
begin
	-- TODO: in no-bypass config, never issue the same warp twice in a row
	enable_gen : for k in 0 to warpcount / 2 - 1 generate
		schedulable(2*k) <= accept_even and valid(2*k) and not busy(2*k);
		schedulable(2*k+1) <= accept_odd and valid(2*k+1) and not busy(2*k+1);
	end generate;
	
	warp_select : FFS
		generic map (logw => log_warpcount)
		port map (
			mask => schedulable,
			defaultv => default_wid,
			fs => issue_wid,
			zero => none_schedulable,
			one_hot => open);
	
	-- Choose defaut
	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				default_wid <= (others => '0');
			elsif init = '0' then
				-- LRR policy
				default_wid <= std_logic_vector(unsigned(default_wid) + 1);
				-- RND policy: use 4-bit LFSR
			end if;
		end if;
	end process;
	
	-- Refill, select
	
	-- Combinatorial feedback
	-- Disallow immediate refill on same slot
	ack_refill <= refill_insn.valid and not valid(to_integer(unsigned(refill_wid)));
	
	process(clock)
		variable refill_wid_int : integer;
		variable issue_wid_int : integer;
		variable slot_read : instruction_buffer_entry;
	begin
		if rising_edge(clock) then
			if reset = '1' then
				valid <= (others => '0');
				--ack_refill <= '0';
			elsif init = '0' then
				-- Issue
				if none_schedulable /= '1' then
					issue_wid_int := to_integer(unsigned(issue_wid));
					issued_wid <= issue_wid;
					slot_read := instruction_buffer(issue_wid_int);
					issued_mpc <= slot_read.pc;
					issued_insn <= slot_read.insn;
					valid(issue_wid_int) <= '0';
				else
					issued_insn <= NopPredec;
				end if;

				-- Refill
				refill_wid_int := to_integer(unsigned(refill_wid));
				if refill_insn.valid = '1' and valid(refill_wid_int) = '0' then
					valid(refill_wid_int) <= '1';
					instruction_buffer(refill_wid_int) <= (pc => refill_mpc, insn => refill_insn);
				end if;
			end if;
		end if;
	end process;
	ready_wid <= issued_wid;
	ready_mpc <= issued_mpc;
	ready_insn <= issued_insn;
	
	-- Scoreboarding
	-- Naive scoreboarding for now: loads and stores stall the warp until resolved
	-- (very bad for bank conflict replays!)
	-- Stage 1
	-- Warning: busy signal is LATE!
	-- OK for 2-cycle bypass config. Back-to-back config may need earlier is_longlatency signal to update issue_wid entry on stage 0
	with issued_insn.opcode select
		is_longlatency <= '1' when LD, '0' when others;
	
	process(clock)
		variable issued_wid_int : integer;
		variable wakeup_wid_int : integer;
	begin
		if rising_edge(clock) then
			if reset = '1' then
				busy <= (others => '0');
			elsif init = '0' then
				issued_wid_int := to_integer(unsigned(issued_wid));
				if issued_insn.valid = '1' then
					busy(issued_wid_int) <= is_longlatency;
				end if;
				if mem_wakeup_valid = '1' then
					wakeup_wid_int := to_integer(unsigned(mem_wakeup_wid));
					busy(wakeup_wid_int) <= '0';
				end if;
			end if;
		end if;
	end process;
end architecture;
