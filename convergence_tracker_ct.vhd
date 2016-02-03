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
-- HCT/CCT-based version
entity Convergence_Tracker_CT is
	port (
		clock : in std_logic;
		reset : in std_logic;
		mpc_6 : in code_address;
		wid_6 : in warpid;
		insn_6 : in decoded_instruction;

		-- Output to Writeback/Branch/Coalescing
		alive_mask_7 : out mask;
		active_mask_7_out : out mask;
		leader_7 : out laneid;
		leader_mask_7 : out mask;
		calldepth_7 : out calldepth_count;
		
		-- Feedback from Branch/Coalescing units
		wid_8 : in warpid;
		is_mem_8 : in std_logic;
		memory_replay_mask_8 : in mask;	-- From coalescer
		
		alive_mask_8 : in mask;
		
		is_branch_8 : in std_logic;	-- From BU
		branch_default_npc_8 : in code_address;
		branch_default_calldepth_8 : in calldepth_count;
		branch_taken_replay_npc_8 : in code_address;
		branch_taken_replay_mask_8 : in mask;
		branch_taken_replay_calldepth_8 : in calldepth_count;
		
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

architecture structural of Convergence_Tracker_CT is
	signal active_mask_7, active_mask_8 : mask;
	signal a_8, b_8, a_branch_8, b_branch_8, a_mem_8, b_mem_8, c_8, x_7, x_8, y_8, z_8, y_9 : Path;
	signal wid_7, wid_9 : warpid;
	signal branch_default_mask_8, memory_default_mask_8 : mask;
	signal replay_pc_8 : code_address;
	signal doreplay_8, nonetaken_8, alltaken_8 : std_logic;
	signal cct_op_8 : CCT_Command;
	signal y_changed_9 : std_logic;
	signal hct_x_in_8, hct_y_in_9 : Path;
	signal hct_x_wid_8, hct_y_wid_9 : warpid;
	signal hct_x_wren_8, hct_y_wren_9 : std_logic;
	signal invalid_7, invalid_8 : std_logic;
	signal mpc_7, mpc_8, fallthrough_pc_8 : code_address;
	signal calldepth_8 : calldepth_count;
begin
	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				mpc_8 <= (others => '0');
				active_mask_8 <= EmptyMask;
				invalid_8 <= '1';
				calldepth_8 <= (others => '0');
				mpc_7 <= (others => '0');
				wid_7 <= (others => '0');
			else
				mpc_8 <= mpc_7;
				active_mask_8 <= active_mask_7;
				invalid_8 <= invalid_7;
				calldepth_8 <= x_7.calldepth;
				mpc_7 <= mpc_6;
				wid_7 <= wid_6;
			end if;
		end if;
	end process;
	fallthrough_pc_8 <= std_logic_vector(unsigned(mpc_8) + 1);-- TODO Take as input?
	
	-- Readout PC, mask from HCT1 at stage 6->7, with bypass from x_8
	-- Compare MPC_7 and x_7
	invalid_7 <= '1' when x_7.mpc /= mpc_7 else not x_7.valid;
	-- Do not commit any state when invalid = '1' !
	active_mask_7 <= EmptyMask when invalid_7 = '1' else x_7.vmask;
	active_mask_7_out <= active_mask_7;
	calldepth_7 <= x_7.calldepth;
	-- Compute Leader
	-- Priority encoder to elect leader: find first set
	elect_leader : FFS
		generic map (logw => log_warpsize)
		port map (
			mask => active_mask_7,
			fs => leader_7,
			zero => open,
			one_hot => leader_mask_7);

	alive_mask_7 <= (others => '1');	-- Placeholder: not actually used

	-- Read c_8 from HCT2, 6->7 or 7->8, with bypass from y_9
	
	-- Compute (NPC1, mask1, v1), (NPC2, mask2, v2) stage 8
	replay_pc_8 <= mpc_8;	-- x_8.mpc is next pc!
	doreplay_8 <= '1' when memory_replay_mask_8 /= EmptyMask else '0';
	-- Compute upstream and take as inputs?
	nonetaken_8 <= '1' when branch_taken_replay_mask_8 = EmptyMask else '0';
	alltaken_8 <= '1' when branch_taken_replay_mask_8 = active_mask_8 else '0';

	branch_default_mask_8 <= active_mask_8 and not branch_taken_replay_mask_8;
	a_branch_8 <= (valid => not alltaken_8,
	               mpc => branch_default_npc_8,
	               calldepth => branch_default_calldepth_8,
	               vmask => branch_default_mask_8);
	b_branch_8 <= (valid => not nonetaken_8,
	               mpc => branch_taken_replay_npc_8,
	               calldepth => branch_taken_replay_calldepth_8,
	               vmask => branch_taken_replay_mask_8);
	memory_default_mask_8 <= active_mask_8 and not memory_replay_mask_8;
	a_mem_8 <= (valid => '1',	-- Forward progress: at least 1 thread moves on to next instruction
	            mpc => fallthrough_pc_8,
	            calldepth => calldepth_8,			-- No change
	            vmask => memory_default_mask_8);
	b_mem_8 <= (valid => doreplay_8,
	            mpc => replay_pc_8,
	            calldepth => calldepth_8,			-- No change
	            vmask => memory_replay_mask_8);

	a_8 <= a_mem_8 when is_mem_8 = '1' else a_branch_8;
	b_8 <= b_mem_8 when is_mem_8 = '1' else b_branch_8;
	
	-- Compact and sort contexts
	ccs : Context_Compact_Sort
		port map (
			a => a_8,
			b => b_8,
			c => c_8,
			x => x_8,
			y => y_8,
			z => z_8
		);
	
	-- NMPC, to front-end: combinatorial
	nmpc <= x_8.mpc;
	nmpc_valid <= is_branch_8 or doreplay_8;
	nmpc_alive <= x_8.valid;
	nmpc_wid <= wid_8;
	
	-- Writeback x_8 in HCT1
	hct_x_in_8 <= (mpc => init_nextpcs(0), calldepth => (others => '0'), vmask => init_alive_mask, valid => '1') when init = '1'
		else x_8;
	hct_x_wid_8 <= init_nextwid when init = '1' else wid_8;
	hct_x_wren_8 <= init or not invalid_8;
	hct_x : Hot_Context_Table
		port map (
			clock => clock,
			reset => reset,
			wid_read => wid_6,
			context_read => x_7,
			write_enable => hct_x_wren_8,
			wid_write => hct_x_wid_8,
			context_write => hct_x_in_8
		);
	
	-- CCT command
	cct_op_8 <=
		Push when z_8.valid = '1' else	-- Too many contexts: 3
		Pop when y_8.valid = '0' else		-- Too few contexts: 1
		Nop;
	
	cct : Cold_Context_Table
		port map (
			clock => clock,
			reset => reset,
			wid => wid_8,
			command => cct_op_8,
			y_in => y_8,
			z_in => z_8,
			y_out => y_9,
			wid_out => wid_9,
			y_changed => y_changed_9
		);
		
	-- Writeback y_9 in HCT2
	hct_y_in_9.mpc <= y_9.mpc;
	hct_y_in_9.vmask <= y_9.vmask;
	hct_y_in_9.calldepth <= y_9.calldepth;
	hct_y_in_9.valid <= '0' when init = '1' else y_9.valid;
	hct_y_wid_9 <= init_nextwid when init = '1' else wid_9;
	hct_y_wren_9 <= y_changed_9 or init;
	hct_y : Hot_Context_Table
		port map (
			clock => clock,
			reset => reset,
			wid_read => wid_7,
			context_read => c_8,
			write_enable => hct_y_wren_9,
			wid_write => hct_y_wid_9,
			context_write => hct_y_in_9
		);
	
end architecture;

configuration defaultconf of Convergence_Tracker_CT is
	for structural
		for all : Context_Compact_Sort
			use entity work.Context_Compact_Sort(behavioral);
		end for;
	end for;
end configuration;
