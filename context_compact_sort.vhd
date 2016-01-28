library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

entity Context_Compact_Sort is
	port (
		a : in Path;
		b : in Path;
		c : in Path;
		
		x : out Path;
		y : out Path;
		z : out Path
		--valid1_in : in std_logic;
		--mpc1_in : in code_address;
		--mask1_in : in mask;
		
		--valid1_out : out std_logic;
		--mpc1_out : out code_address;
		--mask1_out : out mask;
	);
end entity;

-- Assumes valid bits already computed: no empty mask
architecture structural of Context_Compact_Sort is
	component Compact_Sort2 is
		port (
			a : in Path;
			b : in Path;
			
			min : out Path;
			max : out Path
		);
	end component;
	signal min_ab, max_ab, mid : Path;
begin
	-- Sorting-network based implementation
	-- Latency optimized implementation would use parallel comparators
	-- then 3-way muxes instead.
	
	-- Sort 1 and 2
	sort_1 : Compact_Sort2
		port map(
			a => a,
			b => b,
			min => min_ab,
			max => max_ab
		);
	sort_2 : Compact_Sort2
		port map(
			a => max_ab,
			b => c,
			min => mid,
			max => z
		);
	sort_3 : Compact_Sort2
		port map(
			a => min_ab,
			b => mid,
			min => x,
			max => y
		);
end architecture;

--architecture structural2 of Context_Compact_Sort is
--	signal agtb, bgtc, cgta, aeqb, beqc, ceqa : boolean;
--	signal ab_valid, bc_valid, ca_valid : boolean;
--begin
--	ab_valid <= (a.valid and b.valid) = '1';
--	aeqb <= a.mpc = b.mpc and both_valid;
--	agtb <= (a.mpc > b.mpc and both_valid) or (b.valid = '1' and a.valid = '0');
--	
--	x <= c when bgtc or 
--end architecture;

----------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

entity Compact_Sort2 is
	port (
		a : in Path;
		b : in Path;
		
		min : out Path;
		max : out Path
	);
end entity;

architecture structural of Compact_Sort2 is
	signal both_valid : boolean;
	signal swap, merge : boolean;
begin
	both_valid <= (a.valid and b.valid) = '1';
	merge <= a.mpc = b.mpc and both_valid;	-- Allow merge across different call depth!
	swap <= ((a.calldepth < b.calldepth or a.mpc > b.mpc) and both_valid) or (b.valid = '1' and a.valid = '0');
	
	min.mpc <= b.mpc when swap else a.mpc;
	max.mpc <= a.mpc when swap else b.mpc;
	min.calldepth <= b.calldepth when swap else a.calldepth;
	max.calldepth <= a.calldepth when swap else b.calldepth;
	min.vmask <= a.vmask or b.vmask when merge else
	             b.vmask when swap else
	             a.vmask;
	max.vmask <= a.vmask when swap else
	             b.vmask;
	min.valid <= b.valid when swap else
	             a.valid;
	max.valid <= '0' when merge else
	             a.valid when swap else
	             b.valid;
end architecture;
