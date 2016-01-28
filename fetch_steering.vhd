library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- Fetch steering and MPC generation
-- No feedback from insn buffer for now!
-- Open question: how to merge outputs from decode (or BP) and from BA?
entity Fetch_Steering is
	port (
		clock : in std_logic;
		reset : in std_logic;
		init : in std_logic;
		
		nmpc_early : in code_address;	-- Guess of branch predictor/decode: potentially speculative next MPC
		nmpc_early_valid : in std_logic;
		nmpc_early_wid : in warpid;
		
		nmpc : in code_address;		-- Feedback from memory and branch unit: nonspeculative next MPC
		nmpc_valid : in std_logic;
		nmpc_alive : in std_logic;
		nmpc_wid : in warpid;
		mpc : out code_address;			-- MPC to fetch from. May be speculative.
		mpc_valid : out std_logic;
		wid : out warpid);			-- Warp ID associated with MPC
end entity;

architecture structural of Fetch_Steering is
	type mpc_buffer_entry is record
		mpc : code_address;
		valid : std_logic;
	end record;
	type mpc_buffer_type is array (0 to warpcount - 1) of mpc_buffer_entry;
	signal mpc_buffer : mpc_buffer_type;
	signal roundrobin_wheel : unsigned(log_warpcount - 1 downto 0);
	
	signal read_entry : mpc_buffer_entry;
	signal wid1 : warpid;
begin
	-- Round-robin between speculative PC entries

	process(clock)
		variable nmpc_entry : mpc_buffer_entry;
	begin
		if rising_edge(clock) then
			if reset = '1' then
				roundrobin_wheel <= to_unsigned(0, roundrobin_wheel'length);
				for i in 0 to warpcount - 1 loop
					mpc_buffer(i) <= (mpc => (others => '0'), valid => '1');
				end loop;
				read_entry <= (mpc => DummyPC, valid => '0');
				wid1 <= (others => '0');
			else
				if init = '0' then
					-- 2 Write ports: will never make it to a BRAM
					-- Not such a big table anyway
					if nmpc_early_valid = '1' then
						mpc_buffer(to_integer(unsigned(nmpc_early_wid))).mpc <= nmpc_early;
						-- Do not change valid bit?
					end if;
					-- Defaults to next PC
					--mpc_buffer(to_integer(unsigned(wid1))) <= (
					--	mpc => std_logic_vector(unsigned(read_entry.mpc) + 1),
					--	valid => read_entry.valid);
				end if;
				-- Select feedback from branch arbiter when available
				if nmpc_valid = '1' or init = '1' then
					nmpc_entry.mpc := nmpc;
					nmpc_entry.valid := nmpc_alive;
					mpc_buffer(to_integer(unsigned(nmpc_wid))) <= nmpc_entry;
				end if;

				if init = '0' then
					-- Get (mpc[i], valid[i], i)
					-- Bypass branch direction update!
					if nmpc_valid = '1' and nmpc_wid = std_logic_vector(roundrobin_wheel) then
						read_entry <= (mpc => nmpc, valid => '1');
					elsif nmpc_early_valid = '1' and nmpc_early_wid = std_logic_vector(roundrobin_wheel) then
						read_entry <= (mpc => nmpc_early, valid => '1');
					else
						read_entry <= mpc_buffer(to_integer(roundrobin_wheel));
					end if;
					wid1 <= std_logic_vector(roundrobin_wheel);
					roundrobin_wheel <= roundrobin_wheel + to_unsigned(1, roundrobin_wheel'length);
				end if;
			end if;
		end if;
	end process;
	mpc <= read_entry.mpc;
	mpc_valid <= read_entry.valid;
	wid <= wid1;
end architecture;
