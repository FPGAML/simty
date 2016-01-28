library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- SIMT execution units
entity Execute is
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
end entity;

architecture structural of Execute is
	signal fallthrough_pc_0, fallthrough_pc_1 : code_address;
	signal csr_0, d_alu_0, d_0, d_1 : vector;
	signal indirect_target_0, indirect_target_1 : code_address_vector;
	signal cond_0, cond_1 : mask;
	signal d_valid_0, d_valid_1 : std_logic;
	signal insn_1 : decoded_instruction;
	signal mpc_1 : code_address;
	signal wid_1 : warpid;
begin
	fallthrough_pc_0 <= std_logic_vector(unsigned(mpc_in) + 1); --to_unsigned(1,30));	-- ?

	-- Instantiate individual ALUs
	alus: for i in 0 to warpsize - 1 generate
		alu_i: SALU
			port map(
				mpc => mpc_in,
				wid => wid_in,
				insn => insn_in,
				fallthrough_pc => fallthrough_pc_0,
				s1 => s1(i * 32 + 31 downto i * 32),
				s2 => s2(i * 32 + 31 downto i * 32),
				d => d_alu_0(i * 32 + 31 downto i * 32),
				cond => cond_0(i),
				indirect_target => indirect_target_0(i)
			);
	end generate;
	
	sys: CSR
		port map(
			clock => clock,
			reset => reset,
			mpc => mpc_in,
			wid => wid_in,
			insn => insn_in,
			csr => csr_0);
	
	d_0 <= csr_0 when insn_in.sysop = CSRR else d_alu_0;
	
	-- Register outputs
	process(clock) is
	begin
		if rising_edge(clock) then
			if reset = '1' then
				d_1 <= (others => '0');
				cond_1 <= (others => '0');
				insn_1 <= NopDec;
				indirect_target_1 <= (others => (others => '0'));
				mpc_1 <= DummyPC;
				wid_1 <= (others => '0');
				fallthrough_pc_1 <= (others => '0');
				s2_out <= (others => '0');
			else
				d_1 <= d_0;
				cond_1 <= cond_0;
				insn_1 <= insn_in;
				indirect_target_1 <= indirect_target_0;
				mpc_1 <= mpc_in;
				wid_1 <= wid_in;
				fallthrough_pc_1 <= fallthrough_pc_0;
				s2_out <= s2;
			end if;
		end if;
	end process;
	
	d <= d_1;
	insn_out <= insn_1;
	mpc_out <= mpc_1;
	wid_out <= wid_1;
	cond <= cond_1;
	indirect_target <= indirect_target_1;
	fallthrough_pc <= fallthrough_pc_1;
end architecture;
