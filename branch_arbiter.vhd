library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- Branch Arbiter
entity Branch_Arbiter is
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
end entity;

-- Adapted from Nicolas Brunie, TSI'12
architecture structural of Branch_Arbiter is
	-- I feel lucky
	type pc_2d_array_t is array (0 to log_warpsize) of code_address_vector;
	type comp_pc_val_array_t is array (0 to log_warpsize) of mask;
	signal pc_array : pc_2d_array_t;
	signal comp_pc_val : comp_pc_val_array_t;
begin
	pc_array(0) <= nextpcs;
	comp_pc_val(0) <= alive_mask;
	
	allstages_pc_comp : for j in 0 to log_warpsize - 1 generate
		stage2_pc_comp : for i in 0 to warpsize / 2**(j + 1) - 1 generate
			pc_array(j+1)(i) <=
				pc_array(j)(2*i) when (unsigned(pc_array(j)(2*i)) < unsigned(pc_array(j)(2*i+1)) and comp_pc_val(j)(2*i) = '1') or comp_pc_val(j)(2*i+1) = '0' else
				pc_array(j)(2*i+1);
			comp_pc_val(j+1)(i) <= comp_pc_val(j)(2*i) or comp_pc_val(j)(2*i+1);
		end generate;
	end generate;
	
	nextmpc <= pc_array(log_warpsize)(0);
	nextmpc_alive <= comp_pc_val(log_warpsize)(0);
	nextmpc_valid <= '0' when active_mask = (warpsize - 1 downto 0 => '0') else is_branch;	-- Only deal with branches
	
	-- HDL is always fine until you synthesize it
end architecture;
