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
		wid_in : in warpid;
		insn_in : in decoded_instruction;
		vector_branch_target : in code_address_vector;
		fallthrough_pc : in code_address;

		context_in : in Path;
		condition : in mask;
		leader : in laneid;
		
		default_context : out Path;
		taken_replay_context : out Path;
		insn_out : out decoded_instruction;
		--mpc_out : out address;
		wid_out : out warpid
	);
end entity;

architecture structural of Branch is
	signal mpc_0, scalar_branch_target_0 : code_address;
	signal valid_mask, taken_mask_0 : mask;
	signal leader_target_0 : code_address;
	signal uniform_mask_0, replay_mask_0 : mask;
	
	signal default_npc_0, taken_replay_npc_0 : code_address;
	signal taken_replay_mask_0 : mask;
	signal calldepth_0, default_calldepth_0, taken_replay_calldepth_0 : calldepth_count;
	signal nonetaken_0, alltaken_0 : std_logic;
begin
	valid_mask <= context_in.vmask;
	mpc_0 <= context_in.mpc;
	calldepth_0 <= context_in.calldepth;
	
	-- Vector branch target from ALU for:
	-- JALR: S1 + I-Imm (vector)
	-- Compute scalar branch target here for:
	-- JAL:  PC + J-Imm
	-- Bxx:  PC + B-Imm
	scalar_branch_target_0 <= std_logic_vector(unsigned(mpc_0) + unsigned(insn_in.imm(code_address'high downto 2)));
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
		                      mpc_0                  when others;

	-- Call/return
	-- JALR w/ rd=x1 -> push
	-- JALR w/ rd=x0, rs=x1 -> pop
	default_calldepth_0 <= calldepth_count(unsigned(calldepth_0) + 1) when insn_in.branchop = JALR and insn_in.rd = "00001" else
	                       calldepth_count(unsigned(calldepth_0) - 1) when insn_in.branchop = JALR and insn_in.rd = "00000" and insn_in.rs1 = "00001" else
	                       calldepth_0;
	taken_replay_calldepth_0 <= calldepth_0;	-- No change

	nonetaken_0 <= '1' when taken_replay_mask_0 = EmptyMask else '0';
	alltaken_0 <= '1' when taken_replay_mask_0 = valid_mask else '0';
	
	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				wid_out <= (others => '0');
				default_context <= (
					valid => '0',
				    mpc => DummyPC,
				    calldepth => (others => '0'),
				    vmask => EmptyMask);
				taken_replay_context <= (
					valid => '0',
				    mpc => DummyPC,
				    calldepth => (others => '0'),
				    vmask => EmptyMask);
				insn_out <= NopDec;
			else
				wid_out <= wid_in;
				default_context <= (
					valid => not alltaken_0,
				    mpc => default_npc_0,
				    calldepth => default_calldepth_0,
				    vmask => valid_mask and not taken_replay_mask_0);
				taken_replay_context <= (
					valid => not nonetaken_0,
					mpc => taken_replay_npc_0,
					calldepth => taken_replay_calldepth_0,
					vmask => taken_replay_mask_0);
				insn_out <= insn_in;
			end if;
		end if;
	end process;
end architecture;
