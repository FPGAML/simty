library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package simty_pkg is
	constant log_warpcount : natural := 3;
	constant log_warpsize : natural := 2;
	constant warpcount : natural := 2**log_warpcount;
	constant warpsize : natural := 2**log_warpsize;
	constant log_blocksize : natural := log_warpsize + 2;	-- In bytes
	constant log_codesize : natural := 32;

	constant calldepth_width : natural := 8;
	
	--type std_logic_matrix is array (natural range <>) of std_logic_vector;
	subtype address is std_logic_vector(31 downto 0);
	subtype code_address is std_logic_vector(log_codesize - 1 downto 2);	-- Always 4-byte aligned, potentially limited physical memory area
	type code_address_vector is array(warpsize - 1 downto 0) of code_address;
	subtype scalar is std_logic_vector(31 downto 0);
	subtype instruction_word is std_logic_vector(31 downto 0);
	subtype warpid is std_logic_vector(log_warpcount - 1 downto 0);
	subtype laneid is std_logic_vector(log_warpsize - 1 downto 0);
	subtype block_address is std_logic_vector(31 downto log_blocksize);
	subtype calldepth_count is std_logic_vector(calldepth_width - 1 downto 0);
	
	subtype opcode is std_logic_vector(6 downto 0);
	subtype register_id is std_logic_vector(4 downto 0);
	type alu_op is (Addsub, Sl, Compare, Bxor, Sr, Bor, Band, FTPC, PassB, Nop);
	type compop_t is (EQ, NE, LT, LTU, GE, GEU);
	type branchop_t is (BCC, JAL, JALR, Spawn, Everywhere, Nop);
	type memop_t is (LD, ST, Nop);
	type sysop_t is (CSRR, Nop);
	type predecoded_opcode is (LUI, AUIPC, JAL, JALR, BR, LD, ST, ALUI, ALU, FENCE, SYS, SIMTCTL, Invalid);
	type predecoded_instruction is
		record
			iw : std_logic_vector(31 downto 7);	-- Without opcode
			valid : std_logic;
			opcode : predecoded_opcode;
			rd_valid : std_logic;
			rs1_valid : std_logic;
			rs2_valid : std_logic;
		end record;
	
	constant NopPredec : predecoded_instruction := (iw => (others => '0'), valid => '0',
		opcode => Invalid, rd_valid => '0', rs1_valid => '0', rs2_valid => '0');
	
	type decoded_instruction is
		record
			valid : std_logic;
			--itype : instruction_type;
			alu_ctl : alu_op;
			alu_alt : std_logic;
			
			a_is_pc : std_logic;	-- Is ALU input a PC?
			b_is_imm : std_logic;	-- Is ALU input b an immediate? RS2 may be used elsewhere.
			compop : compop_t;
			writeback_d : std_logic;	-- Should we write back ALU output?
			branchop : branchop_t;
			memop : memop_t;
			sysop : sysop_t;
			mem_size : std_logic_vector(2 downto 0);
			
			-- Invalid registers set to register 0
			rd : register_id;
			rs1 : register_id;
			rs2 : register_id;
			imm : address;
		end record;
	
	constant NopDec : decoded_instruction := (valid => '0', alu_ctl => Nop, alu_alt => '0',
		a_is_pc => '0', b_is_imm => '0', compop => EQ, writeback_d => '0', branchop => Nop,
		memop => Nop, sysop => Nop, mem_size => "000", rd => (others => '0'), rs1 => (others => '0'), rs2 => (others => '0'),
		imm => (others => '0'));
	
	constant DummyPC : code_address := (others => '1');
	constant StartPC : code_address := (9 => '1', others => '0');	-- 0x200
	
	subtype vector is std_logic_vector(32 * warpsize - 1 downto 0);
	subtype rfbank_address is std_logic_vector(4 + log_warpcount - 1 downto 0);	-- log(32*nwarps/2)
	subtype mask is std_logic_vector(warpsize - 1 downto 0);

	constant EmptyMask : mask := (others => '0');
	constant FullMask : mask := (others => '1');

	function to_scalar(c : code_address) return scalar;
	
	type Path is record
		valid : std_logic;
		mpc : code_address;
		vmask : mask;
		calldepth : calldepth_count;
	end record;
	type CCT_Command is (Push, Pop, Nop);

	type ICache_Request is record
		valid : std_logic;
		wid : warpid;
		address : code_address;
	end record;

	type ICache_Response is record
		valid : std_logic;
		wid : warpid;
		address : code_address;
		data : instruction_word;
	end record;

	type Bus_Request is record
		valid : std_logic;
		wid : warpid;
		--rd : register_id;
		address : block_address;
		data : vector;
		write_mask : mask;
		shared_byte_enable : std_logic_vector(3 downto 0);
		is_read : std_logic;
		is_write : std_logic;
	end record;
	
	type Bus_Response is record
		valid : std_logic;
		wid : warpid;
		--rd : register_id;
		address : block_address;
		data : vector;
	end record;

	component Simty is
		port (
			clock, reset : in std_logic;
		
			-- Memory access interface
			pu_request : out Bus_Request;
			pu_response : in Bus_Response;
		
			mmio_in : in std_logic_vector(31 downto 0);
			mmio_out : out std_logic_vector(31 downto 0)
		);
	end component;

	-- SRAM
	-- 1 write port, 1 read port
	component SRAM is
		generic (
			width : positive := 128;
			logdepth : positive := 7
		);
		port (
			clock : in std_logic;
			reset : in std_logic;
			--rd_enable : in std_logic;
			rd_address : in unsigned(logdepth - 1 downto 0);
			rd_data : out std_logic_vector(width - 1 downto 0);

			wr_enable : in std_logic;
			wr_address : in unsigned(logdepth - 1 downto 0);
			wr_data : in std_logic_vector(width - 1 downto 0);
			--wr_byteenable : in std_logic_vector((width+7)/8 - 1 downto 0)
			wr_common_byteenable : in std_logic_vector(3 downto 0) := "1111";
			wr_wordenable : in std_logic_vector(width / 32 - 1 downto 0)
		);
	end component;

	component SRAM32_dp is
		generic (
			logdepth : positive := 7
		);
		port (
			a_clock : in std_logic;
			a_address : in unsigned(logdepth - 1 downto 0);
			a_rd_data : out std_logic_vector(32 - 1 downto 0);
			a_wr_enable : in std_logic;
			a_wr_data : in std_logic_vector(32 - 1 downto 0);
			a_wr_byteenable : in std_logic_vector(3 downto 0);
		
			b_clock : in std_logic;
			b_address : in unsigned(logdepth - 1 downto 0);
			b_rd_data : out std_logic_vector(32 - 1 downto 0);
			b_wr_enable : in std_logic;
			b_wr_data : in std_logic_vector(32 - 1 downto 0);
			b_wr_byteenable : in std_logic_vector(3 downto 0)
		);
	end component;

	component Funnel_Shifter is
		port (
			hi : in std_logic_vector(31 downto 0);
			lo : in std_logic_vector(31 downto 0);
			shamt : in std_logic_vector(4 downto 0);
			c : in std_logic;	-- For left shifts by 0
			r : out std_logic_vector(31 downto 0)
		);
	end component;
	component FFS is
		generic (logw : natural := 2);
		port (
			mask : in std_logic_vector(2**logw - 1 downto 0);
			defaultv : in std_logic_vector(logw - 1 downto 0) := (others => '0');
			fs : out std_logic_vector(logw - 1 downto 0);
			zero : out std_logic;
			one_hot : out std_logic_vector(2**logw - 1 downto 0)
		);
	end component;
	component SALU is
		port (
			mpc : in code_address;
			wid : in warpid;
			insn : in decoded_instruction;
			fallthrough_pc : in code_address;
			s1 : in scalar;
			s2 : in scalar;
			d : out scalar;
			cond : out std_logic;
			indirect_target : out code_address	-- Branch target for JALR
		);
	end component;
	component CSR is
		port (
			clock : in std_logic;
			reset : in std_logic;
			mpc : in code_address;
			wid : in warpid;
			insn : in decoded_instruction;
			csr : out vector
			--retired : in std_logic
		);
	end component;

	component Fetch_Steering is
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
	end component;

	component Fetch is
		port (
			clock : in std_logic;
			reset : in std_logic;
			mpc_in : in code_address;
			mpc_valid_in : in std_logic;
			wid_in : in warpid;
			iw : out instruction_word;
			valid : out std_logic;
			mpc_out : out code_address;
			wid_out : out warpid;
			-- NMPC bypass logic
			nmpc_valid : in std_logic;
			nmpc_wid : in warpid;
			ignorepath : out std_logic;
		
			-- Interface to Imem/Icache
			icache_req : out ICache_Request;
			icache_resp : in ICache_Response
		);
	end component;

	component Predecode is
		port (
			mpc_in : in code_address;
			wid_in : in warpid;
			iw_in : in instruction_word;
			iw_valid : in std_logic;
			ignorepath : in std_logic;	-- NMPC has been bypassed, do not update

			instruction : out predecoded_instruction;

			mpc_out : out code_address;
			wid_out : out warpid;
		
			nmpc : out code_address;		-- Feedback to fetch steering unit: speculative next MPC (static branch prediction)
			nmpc_valid : out std_logic;
			nmpc_wid : out warpid;
			ack_refill : in std_logic
		);
	end component;
	component Schedule is
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
		
			mem_wakeup_valid : in std_logic;	-- LD and ST need to assert this
			mem_wakeup_wid : in warpid;

			ready_insn : out predecoded_instruction;
			ready_mpc : out code_address;
			ready_wid : out warpid
		);
	end component;
	component Collect is
		port (
			clock : in std_logic;
			reset : in std_logic;
			mpc_in : in code_address;
			wid_in : in warpid;
			insn_in : in predecoded_instruction;

			accept_even : out std_logic;	-- scheduler hints
			accept_odd : out std_logic;

			writeback_d : in vector;
			writeback_wid : in warpid;
			writeback_rd : in register_id;
			writeback_mask : in mask;
		
			memwriteback : in vector;
			memwriteback_valid : in std_logic;
			memwriteback_wid : in warpid;
			memwriteback_rd : in register_id;
			memwriteback_mask : in mask;
			memwriteback_ack : out std_logic;
		
			s1 : out vector;
			s2 : out vector;
			insn_out : out predecoded_instruction;	-- Won't use rs1 and rs2 any more, but trust logic optimization
			mpc_out : out code_address;
			wid_out : out warpid
		);
	end component;
	component Decode is
		port (
			mpc_in : in code_address;
			wid_in : in warpid;
			insn_in : in predecoded_instruction;
			instruction : out decoded_instruction;
			mpc_out : out code_address;
			wid_out : out warpid
		);
	end component;

	component Execute is
		port (
			clock : in std_logic;
			reset : in std_logic;
			mpc_in : in code_address;
			wid_in : in warpid;
			insn_in : in decoded_instruction;
			s1 : in vector;
			s2 : in vector;
			d : out vector;
			cond : out mask;
			--d_valid : out std_logic;	-- Do writeback
			--d_mask : out mask;
			s2_out : out vector;
			insn_out : out decoded_instruction;
			indirect_target : out code_address_vector;
			fallthrough_pc : out code_address;
			mpc_out : out code_address;
			wid_out : out warpid
		);
	end component;
	component Membership is
		port (
			clock : in std_logic;
			reset : in std_logic;
			mpc_in : in code_address;
			wid_in : in warpid;
			insn_in : in decoded_instruction;

			pcs : out code_address_vector;	-- To BU
			alive : out mask;

			valid_mask : out mask;
			leader : out laneid;
			leader_mask : out mask;
			invalid : out std_logic;
		
			nextpcs : in code_address_vector;
			nextwid : in warpid;
			nextalive : in mask;
			nextpcs_invalid : in std_logic
		
			--insn_out : out decoded_instruction;
			--mpc_out : out address;
			--wid_out : out warpid
		);
	end component;
	component Branch is
		port (
			clock : in std_logic;
			reset : in std_logic;
			wid_in : in warpid;
			insn_in : in decoded_instruction;
			vector_branch_target : in code_address_vector;
			fallthrough_pc : in code_address;

			context_in : in Path;
			condition : in mask;
			leader : in laneid;
		
			default_npc : out code_address;
			taken_replay_npc : out code_address;
			taken_replay_mask : out mask;
		
			taken_replay_calldepth : out calldepth_count;
			default_calldepth : out calldepth_count;
			insn_out : out decoded_instruction;
			--mpc_out : out address;
			wid_out : out warpid
		);
	end component;
	component Branch_Arbiter is
		port (
			-- Branch arbiter mode
			nextpcs : in code_address_vector;	-- From BU
			alive_mask : in mask;	-- All active threads, regardless of PC
			active_mask : in mask;
			is_branch : in std_logic;

			nextmpc : out code_address;	-- To fetch steering
			nextmpc_alive : out std_logic;
			nextmpc_valid : out std_logic
		);
	end component;
	component Memory_Arbiter is
		port (
			addresses : in vector;
			valid_mask : in mask;
			is_mem : in std_logic;
		
			-- vector of addresses for multi-bank memory
			bank_address : out block_address;							-- To L1D$
			address_valid : out std_logic;
			offsets : out std_logic_vector(warpsize * (log_blocksize - 2) - 1 downto 0);
			subwords : out std_logic_vector(warpsize * 2 - 1 downto 0);
			replay_mask : out mask										-- To Membership
		);
	end component;
	component Coalescing is
		port (
			clock : in std_logic;
			reset : in std_logic;
			mpc_in : in code_address;
			wid_in : in warpid;
			insn_in : in decoded_instruction;
		
			valid_mask : in mask;	-- From MSHP
			leader : in laneid;		-- binary
			leader_mask : in mask;	-- one-hot
			--invalid : in std_logic;
		
			vector_address : in vector;	-- From EX
			store_data_in : in vector;

			request : out Bus_Request;
			broadcast_mask : out mask;
			replay_mask : out mask;

			leader_offset : out std_logic_vector(log_blocksize - 1 downto 0);

			insn_out : out decoded_instruction;
			mpc_out : out code_address;
			wid_out : out warpid
		);
	end component;
	component Replay is
		port (
			--clock : in std_logic;
			--reset : in std_logic;
			--mpc_in : in code_address;
			wid_in : in warpid;
			--insn_in : in decoded_instruction;
			--fallthroughpc : in code_address;
			pcs : in code_address_vector;
			nextpcs_in : in code_address_vector;
			replay_mask : in mask;	-- From MA
			--valid_mask : in mask;
			nextpcs_out : out code_address_vector;	-- To MSHP
		
		
			--insn_out : out decoded_instruction;
			--mpc_out : out address;
			wid_out : out warpid
		);
	end component;
	component Scratchpad is
		port (
			clock : in std_logic;
			reset : in std_logic;
			request : in Bus_Request;
			response : out Bus_Response
		);
	end component;
	component Crossbar is
		generic (
			log_win : natural;
			log_wout : natural;
			w : natural
		);
		port (
			-- Flat input/output
			--data_in : in std_logic_matrix(0 to 2**log_win-1)(w-1 downto 0);
			--data_out : out std_logic_matrix(0 to 2**log_wout-1)(w-1 downto 0);
			data_in : in std_logic_vector(w * 2**log_win - 1 downto 0);
			data_out : out std_logic_vector(w * 2**log_wout - 1 downto 0);
			control : in std_logic_vector(log_win * 2**log_wout - 1 downto 0)
		);
	end component;
	component Backward_Crossbar is
		generic (
			log_win : natural;
			log_wout : natural;
			w : natural
		);
		port (
			data_in : in std_logic_vector(w * 2**log_win - 1 downto 0);
			data_out : out std_logic_vector(w * 2**log_wout - 1 downto 0);
			control : in std_logic_vector(log_win * 2**log_wout - 1 downto 0)
		);
	end component;
	component Gather is
		port (
			clock : in std_logic;
			reset : in std_logic;
			wid_in : in warpid;
			insn_in : in decoded_instruction;

			address : in block_address;
			data_block : in vector;
			valid_mask : in mask;
			leader_offset : in std_logic_vector(log_blocksize - 1 downto 0);
			broadcast_mask : in mask;
			valid_in : std_logic;

			memwriteback : out vector;
			memwriteback_valid : out std_logic;
			memwriteback_mask : out mask;

			insn_out : out decoded_instruction;
			wid_out : out warpid
		);
	end component;
	component Load_Fifo is
		port (
			clock : in std_logic;
			reset : in std_logic;
			push_full : out std_logic;
			push_valid : in std_logic;
			push_wid : in warpid;
			push_data : in vector;
			push_mask : in mask;
			push_rd : in register_id;

			pop_valid : out std_logic;
			pop_wid : out warpid;
			pop_data : out vector;
			pop_mask : out mask;
			pop_rd : out register_id;
			pop_ack : in std_logic
		);
	end component;
	component Banked_RF is
		port (
			clock : in std_logic;
			reset : in std_logic;
		
			-- Read ports a, b
			-- a has the priority: always succeed
			a_valid : in std_logic;
			a_addr : in rfbank_address;
			a_bank : in std_logic;
			a_data : out vector;
		
			b_valid : in std_logic;
			b_addr : in rfbank_address;
			b_bank : in std_logic;
			b_data : out vector;
			b_conflict : out std_logic;
		
			-- Write ports x, y
			-- x has the priority
			x_valid : in std_logic;
			x_addr : in rfbank_address;
			x_bank : in std_logic;
			x_data : in vector;
			x_wordenable : in mask;
		
			y_valid : in std_logic;
			y_addr : in rfbank_address;
			y_bank : in std_logic;
			y_data : in vector;
			y_wordenable : in mask;
			y_conflict : out std_logic
		);
	end component;
	component Initialize is
		port (
			clock : in std_logic;
			reset : in std_logic;
			init : out std_logic;

			nextpcs : out code_address_vector;
			alive_mask : out mask;
			nextwid : out warpid;
		
			nmpc : out code_address;
			nmpc_wid : out warpid;
			nmpc_alive : out std_logic
		);
	end component;
	component Convergence_Tracker is
		port (
			clock : in std_logic;
			reset : in std_logic;
			mpc_6 : in code_address;
			wid_6 : in warpid;
			insn_6 : in decoded_instruction;

			-- Output to Writeback/Branch/Coalescing
			context_7 : out Path;
			--pcs_7 : out code_address_vector;	-- To BU (for now)
			leader_7 : out laneid;
			leader_mask_7 : out mask;
		
			-- Feedback from Branch/Coalescing units
			wid_8 : in warpid;
			--insn_8 : in decoded_instruction;
			is_mem_8 : in std_logic;
			memory_replay_mask_8 : in mask;	-- From coalescer
		
			--nextpcs_8 : in code_address_vector;	-- From BU (for now)
		
			is_branch_8 : in std_logic;
			branch_default_npc_8 : in code_address;
			branch_default_calldepth_8 : in calldepth_count;
			branch_taken_replay_npc_8 : in code_address;
			branch_taken_replay_mask_8 : in mask;
			branch_taken_replay_calldepth_8 : in calldepth_count;
			--branch_taken_mask_8 : in mask;	-- From BU
			--branch_target_8 : in code_address;
			--branch_fallthrough_mask_8 : in mask;	-- not taken and not fallthrough -> replay
			--fallthrough_pc_8 : in code_address;
		
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
	end component;
	component Cold_Context_Table is
		port (
			clock : in std_logic;
			reset : in std_logic;
			wid : in warpid;
			command : in CCT_Command;
			y_in : in Path;
			z_in : in Path;
			y_out : out Path;
			wid_out : out warpid;
			y_changed : out std_logic
		);
	end component;
	component Hot_Context_Table is
		port (
			clock : in std_logic;
			reset : in std_logic;
			wid_read : in warpid;
			context_read : out Path;
			write_enable : in std_logic;
			wid_write : in warpid;
			context_write : in Path
		);
	end component;
	component Context_Compact_Sort is
		port (
			a : in Path;
			b : in Path;
			c : in Path;
		
			x : out Path;
			y : out Path;
			z : out Path
		);
	end component;
	component Convergence_Tracker_CT is
		port (
			clock : in std_logic;
			reset : in std_logic;
			mpc_6 : in code_address;
			wid_6 : in warpid;
			insn_6 : in decoded_instruction;

			-- Output to Writeback/Branch/Coalescing
			context_7 : out Path;
			leader_7 : out laneid;
			leader_mask_7 : out mask;
		
			-- Feedback from Branch/Coalescing units
			wid_8 : in warpid;
			is_mem_8 : in std_logic;
			memory_replay_mask_8 : in mask;	-- From coalescer
		
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
	end component;
	component Instruction_Memory is
		port (
			clock : in std_logic;
			reset : in std_logic;
			-- Interface to Fetch
			request : in ICache_Request;
			response : out ICache_Response
		);
	end component;
	component Graphics_Memory is
		port (
			pu_clock : in std_logic;
			reset : in std_logic;
			pu_request : in Bus_Request;
			pu_response : out Bus_Response;
		
			vga_clock : in std_logic;
			vga_addr : in std_logic_vector(15 downto 0);
			vga_out : out std_logic_vector(7 downto 0)
		);
	end component;
	component Instruction_ROM is
		port (
			clock : in std_logic;
			addr : in std_logic_vector(7 downto 0);
			data : out std_logic_vector(31 downto 0)
		);
	end component;

end package;

package body simty_pkg is
	function to_scalar(c : code_address) return scalar is
	begin
		if c'high < 31 then
			return (31 downto c'high + 1 => '0') & c & "00";
		else
			return c & "00";
		end if;
	end function;
end package body;
