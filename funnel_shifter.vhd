library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- Scalar 32-bit funnel shifter
-- returs hi:lo >> shamt+c
entity Funnel_Shifter is
	port (
		hi : in std_logic_vector(31 downto 0);
		lo : in std_logic_vector(31 downto 0);
		shamt : in std_logic_vector(4 downto 0);
		c : in std_logic;	-- For left shifts by 0
		r : out std_logic_vector(31 downto 0)
	);
end entity;

-- Could save one mux level by removing c: require shamt in 2s-complement, special case for 0-bit left shifts
architecture structural of Funnel_Shifter is
	type array_t is array(0 to 5) of std_logic_vector(63 downto 0);
	signal row : array_t;
begin
	row(5) <= hi & lo;
	funnel: for i in 4 downto 0 generate
		-- Reduce to 32+2**i values
		row(i)(31+2**i downto 0) <=
			row(i+1)(31+2**(i+1) downto 2**i) when shamt(i) = '1' else
		   row(i+1)(31+2**i downto 0);
	end generate;
	r <= row(0)(32 downto 1) when c = '1' else
	     row(0)(31 downto 0);
end architecture;
