library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- Warp membership check, convergence detection and individual PC update
-- Manages vector PC register
-- Computes actual nonspeculative write mask
-- Stage 6->7
-- Stage 8->9
-- Warning: currently assumes that 7->8 is single-cycle stage!
entity Convergence_Tracker is
	port (
		clock : in std_logic;
		reset : in std_logic;
		mpc_6 : in code_address;
		wid_6 : in warpid;
		insn_6 : in decoded_instruction;

		-- Output to Writeback/Branch/Coalescing
		context_7 : out Path;
		--pcs_7 : out code_address_vector;	-- To BU (for now)
		--alive_mask_7 : out mask;

		--active_mask_7_out : out mask;
		leader_7 : out laneid;
		leader_mask_7 : out mask;
		--calldepth_7 : out calldepth_count;
		
		
		-- Feedback from Branch/Coalescing units
		wid_8 : in warpid;
		--insn_8 : in decoded_instruction;
		is_mem_8 : in std_logic;
		memory_replay_mask_8 : in mask;	-- From coalescer
		
		--nextpcs_8 : in code_address_vector;	-- From BU (for now)
		--alive_mask_8 : in mask;
		
		is_branch_8 : in std_logic;	-- From BU
		branch_default_context_8 : in Path;
		branch_taken_replay_context_8 : in Path;
		
		-- Feedback to Front-end
		nmpc : out code_address;
		nmpc_alive : out std_logic;
		nmpc_valid : out std_logic;
		nmpc_wid : out warpid;
		
		-- Init interface
		init : in std_logic;
		init_nextpcs : in code_address_vector;
		init_alive_mask : in mask;
		init_nextwid : in warpid
	);
end entity;

architecture structural of Convergence_Tracker is
	signal nmpc_branch_7, nmpc_branch_8 : code_address;
	signal pcs_invalid_7, pcs_invalid_8 : std_logic;
	signal mshp_nextpcs : code_address_vector;
	signal mshp_alive_mask, alive_mask_8 : mask;
	signal mshp_nextwid : warpid;
	signal mshp_pcs_invalid : std_logic;
	signal pcs_7, pcs_8 : code_address_vector;
	signal nextpcs_8, nextpcs_8b : code_address_vector;
	signal nextwid_8 : warpid;
	signal active_mask_7, active_mask_8 : mask;
	signal nmpc_branch_valid_8 : std_logic;
	signal replay_pc_8 : code_address;
	signal doreplay_8 : std_logic;
	signal mpc_7, mpc_8 : code_address;
begin
	-- NPC mux computes nextpcs_8
	-- 4 possible PC outcomes
	--  * indirect and unmasked: select PC between target and pc
	--  * taken conditional: set PC to scalar target
	--  * fallthrough: increment PC
	--  * replay or masked out: keep same PC
	
	npc_mux: for i in 0 to warpsize - 1 generate
		nextpcs_8(i) <=
			branch_taken_replay_context_8.mpc when branch_taken_replay_context_8.vmask(i) = '1' else
			branch_default_context_8.mpc when active_mask_8(i) = '1' else
			pcs_8(i);	-- TODO: use write-enable signals
	end generate;
	
	-- Merge this with npc mux eventually
	rp : Replay
		port map (
			wid_in => wid_8,
			pcs => pcs_8,	-- From BU
			nextpcs_in => nextpcs_8,	-- From BU
			replay_mask => memory_replay_mask_8,	-- From Coalescer
			nextpcs_out => nextpcs_8b,	-- To Membership
			wid_out => nextwid_8
		);

	alive_mask_8 <= (others => '1');

	mshp_nextpcs <= init_nextpcs when init = '1' else nextpcs_8b;
	mshp_nextwid <= init_nextwid when init = '1' else nextwid_8;
	mshp_alive_mask <= init_alive_mask when init = '1' else alive_mask_8;
	mshp_pcs_invalid <= '0' when init = '1' else pcs_invalid_8;
	mshp : Membership
		port map (
			clock => clock,
			reset => reset,
			mpc_in => mpc_6,
			wid_in => wid_6,
			insn_in => insn_6,
			pcs => pcs_7,
			alive => open,
			valid_mask => active_mask_7,
			leader => leader_7,
			leader_mask => leader_mask_7,
			invalid => pcs_invalid_7,
			nextpcs => mshp_nextpcs,	-- Feedback path
			nextwid => mshp_nextwid,
			nextalive => mshp_alive_mask,
			nextpcs_invalid => mshp_pcs_invalid
		);

	context_7.valid <= '1';
	context_7.mpc <= mpc_7;
	context_7.vmask <= active_mask_7;
	context_7.calldepth <= (others => '0');	-- Placeholder!
	-- TODO: get calldepths from membership, expose calldepths(leader), update calldepths, feed back to membership, pass to branch arbiter
	
	
	ba : Branch_Arbiter
		port map (
			nextpcs => nextpcs_8,	-- From BU, skips replay
			alive_mask => alive_mask_8,	-- From BU
			active_mask => active_mask_8,
			is_branch => is_branch_8,
			nextmpc => nmpc_branch_8,
			nextmpc_alive => nmpc_alive,
			nextmpc_valid => nmpc_branch_valid_8
		);
	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				-- Initialize front-end after reset
				mpc_8 <= DummyPC;
				pcs_invalid_8 <= '1';
				active_mask_8 <= (others => '0');
				pcs_8 <= (others => DummyPC);
				
				mpc_7 <= DummyPC;
			else
				-- Should not be here?
				mpc_8 <= mpc_7;
				pcs_invalid_8 <= pcs_invalid_7;
				active_mask_8 <= active_mask_7;	-- Should be input?
				pcs_8 <= pcs_7;
				
				mpc_7 <= mpc_6;
			end if;
		end if;
	end process;

	-- Stage 8
	
	-- NMPC mux, to front-end
	replay_pc_8 <= mpc_8;
	doreplay_8 <= '1' when memory_replay_mask_8 /= EmptyMask else '0';
	nmpc <= replay_pc_8 when (is_mem_8 and doreplay_8) = '1' else nmpc_branch_8;
	nmpc_valid <= nmpc_branch_valid_8 or doreplay_8;
	nmpc_wid <= wid_8;
end architecture;
