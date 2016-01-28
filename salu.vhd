library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- Scalar ALU
entity SALU is
	port (
		--clock : in std_logic;
		--reset : in std_logic;
		mpc : in code_address;
		wid : in warpid;
		insn : in decoded_instruction;
		fallthrough_pc : in code_address;
		s1 : in scalar;
		s2 : in scalar;
		d : out scalar;
		cond : out std_logic;
		indirect_target : out code_address	-- Branch target for JALR
		--d_valid : out std_logic;	-- Do writeback
		--d_mask : out mask;

		--insn_out : out decoded_instruction;
		--s1_out : out vector;
		--mpc_out : out address;
		--wid_out : out warpid
	);
end entity;

architecture structural of SALU is
	signal a, b, bmux : scalar;	-- Adder inputs
	signal rwide : unsigned(32 downto 0);
	signal r_add, r_shift, r_bool, r : scalar;
	signal is_sub : std_logic;
	signal carry_in : unsigned(0 downto 0);
	signal z, n, c, v : std_logic;
	signal cond_alu : std_logic;
	--signal shift_amount : unsigned(4 downto 0);
	signal funnel_hi, funnel_lo : scalar;
	signal funnel_shamt : std_logic_vector(4 downto 0);
	signal funnel_c : std_logic;
begin
	is_sub <= '1' when (insn.alu_alt = '1' and insn.alu_ctl = AddSub) or insn.alu_ctl = Compare else '0';
	a <= to_scalar(mpc) when insn.a_is_pc = '1' else
	     s1;
	bmux <= insn.imm when insn.b_is_imm = '1' else s2;
	b <= not bmux when is_sub = '1' or insn.alu_ctl = SL else bmux;	-- Negate amount for left shifts, can be immediate
	
	carry_in <= "1" when is_sub = '1' else "0";
	rwide <= resize(unsigned(a),33) + unsigned(b) + carry_in;
	r_add <= std_logic_vector(rwide(31 downto 0));
	indirect_target <= r_add(code_address'high downto code_address'low);

	-- Condition
	c <= std_logic(rwide(32));
	n <= r_add(31);
	v <= c xor n;
	z <= '1' when r_add = (31 downto 0 => '0') else '0';
	with insn.compop select
		cond_alu <= z          when EQ,
		        not z      when NE,
		        n xnor c   when LTU,
		        n          when LT,
		        (not n) or z  when GE,
		        (n xor c) or z when GEU,
		        '0'        when others;
	
	r_bool <= X"0000_0001" when cond_alu = '1' else (others => '0');
	cond <= cond_alu;
	
	-- Shifter
	-- Naive trust-the-tool impl, just for fun
	--shift_amount <= unsigned(b(4 downto 0));
	--r_shift <= std_logic_vector(shift_left(unsigned(a), to_integer(shift_amount))) when insn.alu_ctl = SL else
     --         std_logic_vector(shift_right(unsigned(a), to_integer(shift_amount))) when insn.alu_ctl = SR and insn.alu_alt = '0' else
	--			  std_logic_vector(shift_right(signed(a), to_integer(shift_amount)));
	
	-- SL(a,s) = funnel(a:0,/s,1)
	-- SRL(a,s) = funnel(0:a,s,0)
	-- SRA(a,s) = funnel(a31,a,s,0)
	funnel_hi <= a when insn.alu_ctl = SL else
	             (others => a(31)) when insn.alu_ctl = SR and insn.alu_alt = '1' else -- SRA
	             (others => '0'); --SRL
	
	funnel_lo <= (others => '0') when insn.alu_ctl = SL else
	             a; -- SRL, SRA
	funnel_shamt <= b(4 downto 0);	-- Already negated
	funnel_c <= '1' when insn.alu_ctl = SL else '0';	-- Actually the same as carry in
	shifter : Funnel_Shifter
		port map(
			hi => funnel_hi,
			lo => funnel_lo,
			shamt => funnel_shamt,
			c => funnel_c,
			r => r_shift);
	
	-- May move shifter out of the ALU to a multi-cycle exec unit eventually
	
	-- Mux to d
	with insn.alu_ctl select
		d <= r_add   when AddSub,
		     r_shift when SL | SR,
		     r_bool  when Compare,
		     a xor b when BXOR,
		     a or b  when BOR,
		     a and b when BAND,
		     to_scalar(fallthrough_pc) when FTPC,
		     b       when PassB,
		     (others => '0') when others;
	
end architecture;
