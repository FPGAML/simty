library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- Warp membership check, convergence detection and individual PC update
-- Manages vector PC register
-- Computes actual nonspeculative write mask
entity Membership is
	port (
		clock : in std_logic;
		reset : in std_logic;
		mpc_in : in address;
		wid_in : in warpid;
		insn_in : in decoded_instruction;

		--pcs : out vector;	-- To BU
		valid_mask : out mask;
		
		commit_wid : in warpid;
		commit_mask : in mask;	-- Increment or branch PC
		taken_mask : in mask;	-- Set to branch PC
		npc_taken : in address;
		npc_fallthrough : in address;
		
		--insn_out : out decoded_instruction;
		--mpc_out : out address;
		wid_out : out warpid
	);
end entity;

-- PC-vector implementation
-- Could use HCT/CCT instead
architecture structural of Membership is
	signal wid_1 : warpid;
	signal pcs_1 : vector;
	signal mpc_1 : address;
	
	signal commit_byteenable : std_logic_vector(4 * warpsize - 1 downto 0);
	signal nextpcs_0 : vector;
begin
	-- Stage 0
	-- Select NPCs from npc_taken or npc_fallthrough depending on taken_mask
	npc_mux : for i in 0 to warpsize - 1 generate
		with taken_mask(i) select
			nextpcs_0(32 * i + 31 downto 32 * i) <= npc_taken when '1',
			                                      npc_fallthrough when others;
	end generate;

	genbyteenable: for i in 0 to warpsize - 1 generate
		commit_byteenable(i*4+3 downto i*4) <= (others => commit_mask(i));
	end generate;

	pc_array : SRAM
		generic map (
			width => warpsize * 32,
			logdepth => log_warpcount)
		port map (
			clock => clock,
			rd_address => unsigned(wid_in),
			rd_data => pcs_1,
			wr_enable => '1',
			wr_address => unsigned(commit_wid),
			wr_data => nextpcs_0,
			wr_byteenable => commit_byteenable);

	-- Stage 1
	-- Row of comparators to compute valid_mask
	comp_row : for i in 0 to warpsize - 1 generate
		with pcs_1(32 * i + 31 downto 32 * i) = mpc_1 select
			valid_mask(i) <= '1' when true,
			                 '0' when others;
	end generate;

	process(clock)
	begin
		if rising_edge(clock) then
			wid_1 <= wid_in;
			mpc_1 <= mpc_in;
		end if;
	end process;
	wid_out <= wid_1;
end architecture;
