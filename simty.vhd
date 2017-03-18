library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

entity Simty is
	port (
		clock, reset : in std_logic;
		
		-- Memory access interface
		pu_request : out Bus_Request;
		pu_response : in Bus_Response;
		
		mmio_in : in std_logic_vector(31 downto 0);
		mmio_out : out std_logic_vector(31 downto 0)
	);
end entity;

architecture structural of Simty is
	signal init : std_logic;
	signal init_nextpcs, mshp_nextpcs : code_address_vector;
	signal init_alive_mask, mshp_alive_mask : mask;
	signal init_nextwid, mshp_nextwid : warpid;
	signal mshp_pcs_invalid : std_logic;
	signal init_nmpc, fs_nmpc : code_address;
	signal init_nmpc_wid, fs_nmpc_wid : warpid;
	signal init_nmpc_alive, fs_nmpc_alive : std_logic;

	signal mpc_1, mpc_2, mpc_3, mpc_4, mpc_5, mpc_6, mpc_7, mpc_8 : code_address;
	signal wid_1, wid_2, wid_3, wid_4, wid_5, wid_6, wid_7, wid_8 : warpid;

	signal icache_req_1 : ICache_Request;
	signal icache_resp_2 : ICache_Response;

	signal iw_2 : instruction_word;
	signal ignorepath_2 : std_logic;
	signal mpc_valid_1, valid_2 : std_logic;
	signal piw_3, piw_4, piw_5 : predecoded_instruction;
	signal pnmpc_3 : code_address;
	signal pnmpc_valid_3 : std_logic;
	signal pnmpc_wid_3 : warpid;
	signal ack_refill_3 : std_logic;
	signal accept_even_4, accept_odd_4 : std_logic;
	signal s1_5, s1_6 : vector;
	signal s2_5, s2_6, s2_7 : vector;
	signal insn_6, insn_7, insn_8, insn_9, insn_10 : decoded_instruction;
	signal d_7 : vector;
	signal cond_7 : mask;
	signal indirect_target_7 : code_address_vector;
	signal context_7 : Path;
	signal leader_7 : laneid;
	signal leader_mask_7 : mask;
	signal writeback_mask_7 : mask;
	signal fallthrough_pc_7 : code_address;

	signal branch_default_context_8, branch_taken_replay_context_8 : Path;
	signal nmpc : code_address;
	signal nmpc_alive : std_logic;
	signal nmpc_valid : std_logic;
	signal nmpc_wid : warpid;
	signal replay_pc_8 : code_address;
	signal doreplay_8 : std_logic;
	signal is_mem_8, is_branch_8 : std_logic;
	signal dmem_write_8 : vector;
	signal byte_enable_8 : std_logic_vector(3 downto 0);
	signal broadcast_mask_8, broadcast_mask_9 : mask;
	signal replay_mask_8 : mask;
	signal leader_offset_8, leader_offset_9 : std_logic_vector(log_blocksize - 1 downto 0);
	--signal stxb_control_7 : std_logic_vector(warpsize * (log_blocksize - 2) - 1 downto 0);
	signal request_8 : Bus_Request;
	signal mem_address_8, mem_address_9 : block_address;
	signal mem_address_valid_7 : std_logic;
	signal response_9 : Bus_Response;
	signal dmem_data_9, scratchpad_data_9 : vector;
	signal memwriteback_9, memwriteback_10, memwriteback_11 : vector;
	signal memwriteback_valid_9, memwriteback_valid_10, memwriteback_valid_11 : std_logic;
	signal memwriteback_wid_9, memwriteback_wid_10, memwriteback_wid_11 : warpid;
	signal write_mask_8, write_mask_9, write_mask_10, write_mask_11 : mask;
	signal memwriteback_ack_5 : std_logic;
	signal memwriteback_rd_11 : register_id;
	--signal ldxb_control_8, ldxb_control_9 : std_logic_vector(warpsize * (log_blocksize - 2) - 1 downto 0);
	--signal subword_mux_7 : std_logic_vector(warpsize * 2 - 1 downto 0);
	signal mmio_in_0, mmio_out_0 : std_logic_vector(31 downto 0);

	-- DEBUG
	--signal rs1_4, rs2_4 : register_id;
	--signal rs1_valid_4, rs2_valid_4, rd_valid_4 : std_logic;
begin
	init_logic : Initialize
		port map (
			clock => clock,
			reset => reset,
			init => init,
			nextpcs => init_nextpcs,
			alive_mask => init_alive_mask,
			nextwid => init_nextwid,
			nmpc => init_nmpc,
			nmpc_wid => init_nmpc_wid,
			nmpc_alive => init_nmpc_alive
		);
	
	fs_nmpc <= init_nmpc when init = '1' else nmpc;
	fs_nmpc_wid <= init_nmpc_wid when init = '1' else nmpc_wid;
	fs_nmpc_alive <= init_nmpc_alive when init = '1' else nmpc_alive;
	
	-- Stage 0
	fs : Fetch_Steering
		port map (
			clock => clock,
			reset => reset,
			init => init,
			nmpc_early => pnmpc_3,
			nmpc_early_valid => pnmpc_valid_3,
			nmpc_early_wid => pnmpc_wid_3,
			nmpc => fs_nmpc,
			nmpc_valid => nmpc_valid,
			nmpc_alive => fs_nmpc_alive,
			nmpc_wid => fs_nmpc_wid,
			mpc => mpc_1,
			mpc_valid => mpc_valid_1,
			wid => wid_1
		);
	
	-- Stage 1
	ifetch : Fetch
		port map (
			clock => clock,
			reset => reset,
			mpc_in => mpc_1,
			mpc_valid_in => mpc_valid_1,
			wid_in => wid_1,
			iw => iw_2,
			valid => valid_2,
			mpc_out => mpc_2,
			wid_out => wid_2,
			nmpc_valid => nmpc_valid,
			nmpc_wid => fs_nmpc_wid,
			ignorepath => ignorepath_2,
			icache_req => icache_req_1,
			icache_resp => icache_resp_2
		);
	imem : Instruction_Memory
		port map (
			clock => clock,
			reset => reset,
			request => icache_req_1,
			response => icache_resp_2
		);
	
	-- Stage 2
	predec : Predecode
		port map (
			mpc_in => mpc_2,
			wid_in => wid_2,
			iw_in => iw_2,
			iw_valid => valid_2,
			ignorepath => ignorepath_2,
			instruction => piw_3,
			mpc_out => mpc_3,
			wid_out => wid_3,
			nmpc => pnmpc_3,
			nmpc_valid => pnmpc_valid_3,
			nmpc_wid => pnmpc_wid_3,
			ack_refill => ack_refill_3
		);
	
	-- Stage 3
	sched : Schedule
		port map (
			clock => clock,
			reset => reset,
			init => init,
			refill_mpc => mpc_3,
			refill_wid => wid_3,
			refill_insn => piw_3,
			ack_refill => ack_refill_3,
			accept_even => accept_even_4,	-- Feedback from collector
			accept_odd => accept_odd_4,
			mem_wakeup_valid => memwriteback_valid_10,
			mem_wakeup_wid => memwriteback_wid_10,
			ready_insn => piw_4,
			ready_mpc => mpc_4,
			ready_wid => wid_4
		);
	
	-- DEBUG
	--rs1_valid_4 <= piw_4.rs1_valid;
	--rs1_4 <= piw_4.iw(19 downto 15);
	--rs2_valid_4 <= piw_4.rs2_valid;
	--rs2_4 <= piw_4.iw(24 downto 20);
	--rd_valid_4 <= piw_4.rd_valid;
	
	-- Stage 4
	coll : Collect
		port map (
			clock => clock,
			reset => reset,
			mpc_in => mpc_4,
			wid_in => wid_4,
			insn_in => piw_4,
			accept_even => accept_even_4,	-- Combinatorial outputs
			accept_odd => accept_odd_4,
			writeback_d => d_7,
			writeback_wid => wid_7,
			writeback_rd => insn_7.rd,
			writeback_mask => writeback_mask_7,
			memwriteback => memwriteback_11,
			memwriteback_valid => memwriteback_valid_11,
			memwriteback_wid => memwriteback_wid_11,
			memwriteback_rd => memwriteback_rd_11,
			memwriteback_mask => write_mask_11,
			memwriteback_ack => memwriteback_ack_5,
			s1 => s1_5,
			s2 => s2_5,
			insn_out => piw_5,
			mpc_out => mpc_5,
			wid_out => wid_5
		);
		
	-- Stage 5
	id : Decode	-- TODO: Merge with collect?
		port map (
			mpc_in => mpc_5,
			wid_in => wid_5,
			insn_in => piw_5,
			instruction => insn_6,
			mpc_out => mpc_6,
			wid_out => wid_6
		);
	s1_6 <= s1_5;	-- Combinatorial stage
	s2_6 <= s2_5;
	
	-- Stage 6
	-- Assumes Execute and Convergence_Tracker have the same latency
	exu : Execute
		port map (
			clock => clock,
			reset => reset,
			mpc_in => mpc_6,
			wid_in => wid_6,
			insn_in => insn_6,
			s1 => s1_6,
			s2 => s2_6,
			d => d_7,
			s2_out => s2_7,
			cond => cond_7,
			insn_out => insn_7,
			indirect_target => indirect_target_7,
			fallthrough_pc => fallthrough_pc_7,
			mpc_out => mpc_7,
			wid_out => wid_7
		);

	ct : Convergence_Tracker_CT	-- TODO generate statement, or configuration
		port map (
			clock => clock,
			reset => reset,
			-- Inputs stage 6
			mpc_6 => mpc_6,
			wid_6 => wid_6,
			insn_6 => insn_6,
			-- Outputs stage 7
			context_7 => context_7,
			--pcs_7 => pcs_7,
			leader_7 => leader_7,
			leader_mask_7 => leader_mask_7,
			-- Input stage 8
			wid_8 => wid_8,
			is_mem_8 => is_mem_8,
			memory_replay_mask_8 => replay_mask_8,
			--nextpcs_8 => nextpcs_8,
			is_branch_8 => is_branch_8,
			branch_default_context_8 => branch_default_context_8,
			branch_taken_replay_context_8 => branch_taken_replay_context_8,

			-- Output stage 8 (combinatorial)
			nmpc => nmpc,
			nmpc_alive => nmpc_alive,
			nmpc_valid => nmpc_valid,
			nmpc_wid => nmpc_wid,
			-- Init interface
			init => init,
			init_nextpcs => init_nextpcs,
			init_alive_mask => init_alive_mask,
			init_nextwid => init_nextwid
		);
	
	writeback_mask_7 <= context_7.vmask when insn_7.writeback_d = '1' else (others => '0');
	
	-- Stage 7
	-- Assumes Branch and Coalescing have the same latency
	bu : Branch
		port map (
			clock => clock,
			reset => reset,
			wid_in => wid_7,
			insn_in => insn_7,
			vector_branch_target => indirect_target_7,
			fallthrough_pc => fallthrough_pc_7,
			context_in => context_7,
			--pcs => pcs_7,
			condition => cond_7,
			leader => leader_7,
			--nextpcs => nextpcs_8,
			default_context => branch_default_context_8,
			taken_replay_context => branch_taken_replay_context_8,
			insn_out => insn_8,
			wid_out => wid_8
		);

	coalescer : Coalescing
		port map (
			clock => clock,
			reset => reset,
			mpc_in => mpc_7,
			wid_in => wid_7,
			insn_in => insn_7,
			valid_mask => context_7.vmask,
			leader => leader_7,
			leader_mask => leader_mask_7,
			--invalid => invalid_7,
			vector_address => d_7,
			store_data_in => s2_7,
			request => request_8,
			broadcast_mask => broadcast_mask_8,
			replay_mask => replay_mask_8,
			leader_offset => leader_offset_8
			-- insn_out, mpc_out, wid_out ignored
		);
	
	-- Stage 8
	-- TODO: proper memory access component connected to async bus
	is_branch_8 <= '1' when insn_8.branchop /= Nop else '0';	
	is_mem_8 <= '1' when insn_8.memop = LD or insn_8.memop = ST else '0';
	
	-- mmio output
	-- Placeholder: actual mmio should use byte enable masks and stuff
	-- And should be outside the core in the first place!
	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				mmio_out_0 <= (others => '0');
			else
				if request_8.valid = '1' and request_8.is_write = '1' and request_8.address = (31 downto log_blocksize => '0') then
					mmio_out_0 <= request_8.data(31 downto 0);
				end if;
				mmio_in_0 <= mmio_in;
			end if;
		end if;
	end process;
	mmio_out <= mmio_out_0;
	
	pu_request <= request_8;
	-- I/O happen here
	response_9 <= pu_response;

	-- mux mmio input here
	dmem_data_9 <= response_9.data;
	memwriteback_valid_9 <= response_9.valid;
	
	-- Assumes synchronous single-cycle memory!
	-- TODO store info in MSHRs for asynchronous memories
	write_mask_8 <= request_8.write_mask;
	mem_address_8 <= request_8.address;
	process(clock) is
	begin
		if rising_edge(clock) then
			if reset = '1' then
				insn_9 <= NopDec;
				--ldxb_control_9 <= (others => '0');
				write_mask_9 <= (others => '0');
				mem_address_9 <= (others => '0');
				leader_offset_9 <= (others => '0');
				broadcast_mask_9 <= (others => '0');
			else
				insn_9 <= insn_8;
				--ldxb_control_9 <= ldxb_control_8;
				write_mask_9 <= write_mask_8;
				mem_address_9 <= mem_address_8;
				leader_offset_9 <= leader_offset_8;
				broadcast_mask_9 <= broadcast_mask_8;
			end if;
		end if;
	end process;
	
	memwriteback_wid_9 <= response_9.wid;
	
	-- Stage 9
	memgather : Gather
		port map (
			clock => clock,
			reset => reset,
			wid_in => memwriteback_wid_9,
			insn_in => insn_9,
			address => mem_address_9,
			data_block => dmem_data_9,
			valid_mask => write_mask_9,
			leader_offset => leader_offset_9,
			broadcast_mask => broadcast_mask_9,
			valid_in => memwriteback_valid_9,
			memwriteback => memwriteback_10,
			memwriteback_valid => memwriteback_valid_10,
			memwriteback_mask => write_mask_10,
			insn_out => insn_10,
			wid_out => memwriteback_wid_10
		);
	
	-- What about a memwriteback/MSHR type?
	
	-- Stage 10
	-- writeback fifo
	-- Move to stage 9?
	mwbfifo : Load_Fifo
		port map (
			clock => clock,
			reset => reset,
			--push_full => 
			push_valid => memwriteback_valid_10,
			push_wid => memwriteback_wid_10,
			push_data => memwriteback_10,
			push_mask => write_mask_10,
			push_rd => insn_10.rd,
			pop_valid => memwriteback_valid_11,
			pop_wid => memwriteback_wid_11,
			pop_data => memwriteback_11,
			pop_mask => write_mask_11,
			pop_rd => memwriteback_rd_11,
			pop_ack => memwriteback_ack_5);
end architecture;
