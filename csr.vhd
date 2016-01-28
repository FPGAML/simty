library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- Manages Control and Status Registers
-- Handles CSRR instruction, and eventually other SYSTEM instructions
entity CSR is
	port (
		clock : in std_logic;
		reset : in std_logic;
		mpc : in code_address;
		wid : in warpid;
		insn : in decoded_instruction;
		csr : out vector
		--retired : in std_logic
	);
end entity;

architecture structural of CSR is
	signal csrid : std_logic_vector(11 downto 0);
	signal scalar_csr : scalar;
	signal hartid : vector;
	--signal cycle_ctr : std_logic_vector(63 downto 0);
	--signal intret_ctr : std_logic_vector(63 downto 0);
begin
	csrid <= insn.imm(11 downto 0);
	-- mhartid 0xF10
	-- cycle cycleh 0xC00 0xC80
	-- time timeh 0xC01 0xC81
	-- instret intreth 0xC02 0xC82
	--with csrid select
	--	scalar_csr <= 
	
	hartid_gen : for i in 0 to warpsize - 1 generate
		hartid(32 * i + 31 downto 32 * i + log_warpcount + log_warpsize) <= (others => '0');
		hartid(32 * i + log_warpcount + log_warpsize - 1 downto 32 * i + log_warpsize) <= wid;
		hartid(32 * i + log_warpsize - 1 downto 32 * i) <= std_logic_vector(to_unsigned(i, log_warpsize));
	end generate;
	
	csr <= hartid when insn.sysop = CSRR and csrid = X"F10" else (others => '0');
end architecture;
