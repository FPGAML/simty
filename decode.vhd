library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- Decode for instruction buffer
entity Decode is
	port (
		mpc_in : in code_address;
		wid_in : in warpid;
		--iw_in : in instruction_word;
		--iw_valid : in std_logic;
		insn_in : in predecoded_instruction;

		instruction : out decoded_instruction;

		mpc_out : out code_address;
		wid_out : out warpid
		--nmpc : out address;		-- Feedback to fetch steering unit: nonspeculative next MPC
		--nmpc_valid : out std_logic;
		--nmpc_wid : out warpid
	);
end entity;

-- TODO
architecture structural of Decode is
	signal iw : std_logic_vector(31 downto 7);
	signal op : opcode;
	signal funct3 : std_logic_vector(2 downto 0);
	signal idec : decoded_instruction;
	signal immediate : signed(31 downto 0);
	type instruction_encoding is (R, I, S, SB, U, UJ, Invalid);
	signal encoding : instruction_encoding;
	signal is_alu : std_logic;
	signal alu_aluctl : alu_op;
	signal br_compop : compop_t;
	--type decoded_opcode is (LUI, AUIPC, JAL, JALR, BR, LD, ST, ALUI, ALU, Invalid);
	signal decop : predecoded_opcode;
	constant padding12 : signed(11 downto 0) := (others => '0');
	signal simtctl_branchop : branchop_t;
begin
	iw <= insn_in.iw;
	decop <= insn_in.opcode;
	funct3 <= iw(14 downto 12);

	-- Force unused registers to 0 for debuggability
	idec.rd <= iw(11 downto 7) when insn_in.rd_valid = '1' else (others => '0');
	idec.rs1 <= iw(19 downto 15) when insn_in.rs1_valid = '1' else (others => '0');
	idec.rs2 <= iw(24 downto 20) when insn_in.rs2_valid = '1' else (others => '0');
	
	with decop select
		encoding <= R  when ALU,
		            I  when JALR | LD | ALUI | FENCE | SYS | SIMTCTL,
		            S  when ST,
		            SB when BR,
		            U  when LUI | AUIPC,
		            UJ when JAL,
		            Invalid when others;	-- No fence and system instructions for now

	--with decop select	-- Is this useful??
	--	idec.itype <= ALU when ALU | ALUI | AUIPC | LUI,
	--	              Branch when BR | JAL | JALR,
	--	              LoadStore when LD | ST,
	--	              Invalid when others;
	
	with funct3 select
		alu_aluctl <= Addsub when "000",
		              Sl     when "001",
		              --Slt    when "010",
		              --Sltu   when "011",
		              Compare when "010" | "011",
		              Bxor   when "100",
		              Sr     when "101",
		              Bor    when "110",
		              Band   when "111",
		              Nop    when others;
	with funct3 select
		idec.compop <= EQ  when "000",
		               NE  when "001",
		               LT  when "010",
		               LTU when "011",
		               LT  when "100",
		               GE  when "101",
		               LTU when "110",
		               GEU when "111",
		               EQ  when others;
	
	-- Bit to distinguish Add/Sub and SRL/SRA
	idec.alu_alt <= iw(30) when (decop = ALUI or decop = ALU) and (alu_aluctl = SR or alu_aluctl = AddSub) else '0';
	
	with decop select
		idec.alu_ctl <= alu_aluctl when ALU | ALUI,
		                FTPC       when JAL | JALR,
		                Compare    when BR,
		                Addsub     when LD | ST | AUIPC,
		                PassB      when LUI,
		                Nop        when others;
	
	idec.a_is_pc <= '1' when decop = AUIPC else '0';
	
	with decop select
		idec.b_is_imm <= '1' when ALUI | LUI | LD | ST | AUIPC | JALR,
		                 '0' when others;
	with decop select
		idec.writeback_d <= '0' when BR | LD | ST,
		                    '1' when others;
	with funct3 select
		simtctl_branchop <= Spawn when "000",
		                    Everywhere when "001",
		                    Nop when others;
		
	with decop select
		idec.branchop <= BCC when BR, JAL when JAL, JALR when JALR, simtctl_branchop when SIMTCTL,
		                 Nop when others;
	
	with decop select
		idec.memop <= LD when LD, ST when ST, Nop when others;
	
	idec.sysop <= CSRR when decop = SYS and funct3 = "010" else Nop;
	idec.mem_size <= funct3;
	
	-- Immediate
	with encoding select
		immediate <= resize(signed(iw(31 downto 20)), 32) when I,
		             resize(signed(iw(31 downto 25)) & signed(iw(11 downto 7)), 32) when S,
		             resize(signed(iw(31) & iw(7) & iw(30 downto 25) & iw(11 downto 8) & '0'), 32) when SB,
		             signed(iw(31 downto 12)) & padding12 when U,
		             resize(signed(iw(31) & iw(19 downto 12) & iw(20) & iw(30 downto 21) & '0'), 32) when UJ,
		             (others => '0') when others;
	idec.imm <= std_logic_vector(immediate);
	
	idec.valid <= insn_in.valid;
	
	instruction <= idec;
	mpc_out <= mpc_in;
	wid_out <= wid_in;
end architecture;
