library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- Operand collector, bank arbiter and RF management
-- Also does writeback
-- 2 stages
entity Collect is
	port (
		clock : in std_logic;
		reset : in std_logic;
		mpc_in : in code_address;
		wid_in : in warpid;
		insn_in : in predecoded_instruction;
		
		accept_even : out std_logic;	-- scheduler hints
		accept_odd : out std_logic;
		
		-- Result from ALU, for writeback and bypass
		-- No bypass for now
		-- bypass_d : in vector;
		-- bypass_rd : in register_id;
		-- bypass_valid : in std_logic;

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
end entity;

architecture structural of Collect is
	-- type rf_type is array(0 to 16 * warpcount - 1) of vector;
	-- signal bank0_rf : rf_type;
	-- signal bank1_rf : rf_type;
	signal rs1_0, rs1_1, rs1_2, rs2_0, rs2_1, rs2_2 : register_id;

	signal writeback_addr : rfbank_address;
	signal memwriteback_addr : rfbank_address;
	--signal writeback_byteenable : std_logic_vector(warpsize * 4 - 1 downto 0);
	signal enable_writeback, enable_memwriteback : std_logic;
	signal memwriteback_nack : std_logic;
	signal a_1, a_byp_1, a_2 : vector;
	signal b_2 : vector;
	signal a_addr0, b_addr1 : rfbank_address;
	
	signal wid0, wid1, wid2 : warpid;
	signal insn0, insn1, insn2 : predecoded_instruction;
	signal mpc0, mpc1, mpc2 : code_address;
begin
	-- Report next cycle RF bank availability to scheduler
	accept_even <= '0' when wid_in(0) = '0' and insn0.rs2_valid = '1' else '1';
	accept_odd <= '0' when wid_in(0) = '1' and insn0.rs2_valid = '1' else '1';

	rs1_0 <= insn_in.iw(19 downto 15) when insn_in.rs1_valid = '1' else (others => '0');
	rs2_0 <= insn_in.iw(24 downto 20) when insn_in.rs2_valid = '1' else (others => '0');
	
	process(clock) is
	begin
		if rising_edge(clock) then
			if reset = '1' then
				wid2 <=  (others => '0');
				insn2 <= NopPredec;
				mpc2 <= DummyPC;
				a_2 <= (others => '0');

				wid1 <= (others => '0');
				insn1 <= NopPredec;
				mpc1 <= DummyPC;

				rs1_2 <= (others => '0');
				rs1_1 <= (others => '0');
				rs2_2 <= (others => '0');
				rs2_1 <= (others => '0');
			else
				wid2 <= wid1;
				insn2 <= insn1;
				mpc2 <= mpc1;
				rs1_2 <= rs1_1;
				rs2_2 <= rs2_1;
				a_2 <= a_byp_1;

				wid1 <= wid0;
				insn1 <= insn0;
				mpc1 <= mpc0;
				rs1_1 <= rs1_0;
				rs2_1 <= rs2_0;
			end if;
		end if;
	end process;

	-- First stages: compute address
	wid0 <= wid_in;
	insn0 <= insn_in;
	mpc0 <= mpc_in;
	
	a_addr0 <= wid0(wid0'high downto 1) & rs1_0;
	b_addr1 <= wid1(wid1'high downto 1) & rs2_1;

	-- Writeback
	writeback_addr <= writeback_wid(writeback_wid'high downto 1) & writeback_rd;
	memwriteback_addr <= memwriteback_wid(memwriteback_wid'high downto 1) & memwriteback_rd;
	
	enable_writeback <= '0' when writeback_rd = "00000" else '1';
	enable_memwriteback <= '0' when memwriteback_rd = "00000" else memwriteback_valid;
	
	-- Input stage 0/1, output stage 1/2
	rf : Banked_RF
		port map (
			clock => clock,
			reset => reset,

			-- Port a: stage 0 -> stage 1
			a_valid => insn0.rs1_valid,	
			a_addr => a_addr0,
			a_bank => wid0(0),
			a_data => a_1,

			-- Port b: stage 1 -> stage 2
			b_valid => insn1.rs2_valid,
			b_addr => b_addr1,
			b_bank => wid1(0),
			b_data => b_2,
			--b_conflict => open,
			
			x_valid => enable_writeback,
			x_addr => writeback_addr,
			x_bank => writeback_wid(0),
			x_data => writeback_d,
			x_wordenable => writeback_mask,
			
			y_valid => enable_memwriteback,
			y_addr => memwriteback_addr,
			y_bank => memwriteback_wid(0),
			y_data => memwriteback,
			y_wordenable => memwriteback_mask,
			y_conflict => memwriteback_nack);

	memwriteback_ack <= memwriteback_valid and not memwriteback_nack;
	
	-- TODO: Combinatorial bypass from writeback_d to a_1, a_2, b_2

	-- 2-cycle bypass for now: a_1 only
	-- Masked bypass: partial bypass after reconvergence
	bypass : for i in 0 to warpsize - 1 generate
		a_byp_1(32*i+31 downto 32*i) <= writeback_d(32*i+31 downto 32*i) when enable_writeback = '1' and writeback_wid = wid1 and writeback_rd = rs1_1 and writeback_mask(i) = '1' else a_1(32*i+31 downto 32*i);
	end generate;
	
	-- Stage 2: output
	-- R0 maps to zero
	s1 <= (others => '0') when rs1_2 = "00000" else a_2;
	s2 <= (others => '0') when rs2_2 = "00000" else b_2;

	insn_out <= insn2;
	mpc_out <= mpc2;
	wid_out <= wid2;
end architecture;
