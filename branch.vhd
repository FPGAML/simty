library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- Branch unit
-- Also computes NPCs for all instructions
entity Branch is
	port (
		clock : in std_logic;
		reset : in std_logic;
		mpc_in : in code_address;
		wid_in : in warpid;
		insn_in : in decoded_instruction;
		vector_branch_target : in code_address_vector;
		fallthrough_pc : in code_address;

		--pcs : in code_address_vector;

		condition : in mask;
		valid_mask : in mask;
		alive_mask_in : in mask;
		leader : in laneid;
		calldepth_in : in calldepth_count;
		
		default_npc : out code_address;
		taken_replay_npc : out code_address;
		taken_replay_mask : out mask;
		--nextpcs : out code_address_vector;	-- To MSHP
		
		--replay_mask : in mask;	-- From MA
		
		alive_mask_out : out mask;
		taken_replay_calldepth : out calldepth_count;
		default_calldepth : out calldepth_count;
		insn_out : out decoded_instruction;
		--mpc_out : out address;
		wid_out : out warpid
	);
end entity;

architecture structural of Branch is
	signal scalar_branch_target_0 : code_address;
	signal taken_mask_0 : mask;
	signal leader_target_0 : code_address;
	signal uniform_mask_0, replay_mask_0 : mask;
	
	signal default_npc_0, taken_replay_npc_0 : code_address;
	signal taken_replay_mask_0 : mask;
	signal default_calldepth_0, taken_replay_calldepth_0 : calldepth_count;
begin
	-- Vector branch target from ALU for:
	-- JALR: S1 + I-Imm (vector)
	-- Compute scalar branch target here for:
	-- JAL:  PC + J-Imm
	-- Bxx:  PC + B-Imm
	scalar_branch_target_0 <= std_logic_vector(unsigned(mpc_in) + unsigned(insn_in.imm(code_address'high downto 2)));

	-- Serialize indirect branches
	leader_target_0 <= vector_branch_target(to_integer(unsigned(leader)));
	
	comp_row : for i in 0 to warpsize - 1 generate
		uniform_mask_0(i) <= '1' when vector_branch_target(i) = leader_target_0 else '0';
	end generate;
	replay_mask_0 <= valid_mask and not uniform_mask_0;
	
	-- Condition comes from ALU
	-- Taken or Replay mask
	with insn_in.branchop select
		taken_replay_mask_0 <= valid_mask and condition when BCC,		-- conditional
		                       valid_mask               when JAL,		-- all taken
		                       replay_mask_0            when JALR,		-- replay
		                       (others => '0')          when others;    -- all fallthrough
	
	with insn_in.branchop select
		default_npc_0 <= leader_target_0 when JALR,
		                 fallthrough_pc when others;
	
	with insn_in.branchop select
		taken_replay_npc_0 <= scalar_branch_target_0 when BCC | JAL,
		                      mpc_in                 when others;

	-- Call/return
	-- JALR w/ rd=x1 -> push
	-- JALR w/ rd=x0, rs=x1 -> pop
	default_calldepth_0 <= calldepth_count(unsigned(calldepth_in) + 1) when insn_in.branchop = JALR and insn_in.rd = "00001" else
	                       calldepth_count(unsigned(calldepth_in) - 1) when insn_in.branchop = JALR and insn_in.rd = "00000" and insn_in.rs1 = "00001" else
	                       calldepth_in;
	taken_replay_calldepth_0 <= calldepth_in;	-- No change
	
	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				wid_out <= (others => '0');
				alive_mask_out <= (others => '1');	-- Set alive all warp 0 threads
				default_npc <= DummyPC;
				taken_replay_npc <= DummyPC;
				taken_replay_mask <= (others => '0');
				default_calldepth <= (others => '0');
				taken_replay_calldepth <= (others => '0');
				insn_out <= NopDec;
			else
				wid_out <= wid_in;
				alive_mask_out <= alive_mask_in;	-- no kill/spawn instruction yet (or ever?)
				default_npc <= default_npc_0;
				taken_replay_npc <= taken_replay_npc_0;
				taken_replay_mask <= taken_replay_mask_0;
				default_calldepth <= default_calldepth_0;
				taken_replay_calldepth <= taken_replay_calldepth_0;
				insn_out <= insn_in;
			end if;
		end if;
	end process;
end architecture;
