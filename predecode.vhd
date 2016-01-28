library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- Predecode for instruction buffer
entity Predecode is
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
end entity;

architecture structural of Predecode is
	signal op : opcode;
	signal funct3 : std_logic_vector(2 downto 0);
	signal idec : predecoded_instruction;
	signal immediate : signed(31 downto 0);
	type instruction_encoding is (R, I, S, SB, U, UJ, Invalid);
	signal encoding : instruction_encoding;
	signal is_alu : std_logic;
	signal alu_aluctl : alu_op;
	signal br_compop : compop_t;
	signal decop : predecoded_opcode;
	constant one_insn : unsigned(2 downto 2) := "1";
begin
	-- Predecode to iw + metadata (rs/rd valid for op read/scoreboarding)
	idec.iw <= iw_in(31 downto 7);

	op <= iw_in(6 downto 0);
	with op select
		decop <=
			LUI   when "0110111",
			AUIPC when "0010111",
			JAL   when "1101111",
			JALR  when "1100111",
			BR    when "1100011",
			LD    when "0000011",
			ST    when "0100011",
			ALUI  when "0010011",
			ALU   when "0110011",
			FENCE when "0001111",
			SYS   when "1110011",
			SIMTCTL when "1101011",	-- Custom extension: spawn, everywhere
			Invalid when others;
	idec.opcode <= decop;
	
	-- Force unused registers to 0 for debuggability
	with decop select
		idec.rd_valid <= '1' when LUI | AUIPC | JAL | LD | ALUI | ALU | SYS | SIMTCTL,
		                 '0' when others;

	with decop select
		idec.rs1_valid <= '1' when JALR | BR | LD | ST | ALUI | ALU | SIMTCTL,
		                  '0' when others;
	with decop select
		idec.rs2_valid <= '1' when BR | ST | ALU,
		                  '0' when others;
	
	idec.valid <= iw_valid;
	
	instruction <= idec;
	mpc_out <= mpc_in;
	wid_out <= wid_in;
	
	-- Very Dumb Branch Predictor
	-- eventually, should compute branch target and predict min PC
	-- or stall fetch / return low confidence signal
	nmpc <= std_logic_vector(unsigned(mpc_in) + one_insn);
	nmpc_valid <= iw_valid and ack_refill and not ignorepath;	-- Front-end should retry eventually
	nmpc_wid <= wid_in;
end architecture;
