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

architecture structural2 of Context_Compact_Sort is
	signal agtb, bgtc, agtc, aeqb, beqc, aeqc, bgea, cgeb, cgea : boolean;
	signal ab_valid, bc_valid, ac_valid : boolean;
	signal a2, b2 : Path;
	signal acomb, bcomb : mask;
begin
	-- BUG: in case of equality, should discard second path
	-- compact first, set valid bits, then compute xy_valid
	ab_valid <= (a.valid and b.valid) = '1';
	aeqb <= a.mpc = b.mpc and ab_valid;
	bc_valid <= (b.valid and c.valid) = '1';
	beqc <= b.mpc = c.mpc and bc_valid;
	ac_valid <= (a.valid and c.valid) = '1';
	aeqc <= a.mpc = c.mpc and ac_valid;

	agtb <= (a.mpc > b.mpc and ab_valid) or (b.valid = '1' and a.valid = '0');
	bgea <= not agtb;
	
	bgtc <= (b.mpc > c.mpc and bc_valid) or (c.valid = '1' and b.valid = '0');
	cgeb <= not bgtc;
	
	agtc <= (a.mpc > c.mpc and ac_valid) or (c.valid = '1' and a.valid = '0');
	cgea <= not agtc;

	-- Compact
	-- In case of equality, the lowest letter gets the mask
	acomb <= b.vmask or c.vmask when aeqb and beqc else
	         b.vmask when aeqb else
	         c.vmask when aeqc else
	         (others => '0');
	a2 <= (vmask => a.vmask or acomb, valid => a.valid, mpc => a.mpc, calldepth => a.calldepth);

	bcomb <= c.vmask when beqc else (others => '0');
	b2 <= (vmask => b.vmask or bcomb, valid => b.valid, mpc => b.mpc, calldepth => b.calldepth);
	
	x <= c  when bgtc and agtc else
	     b2 when agtb and cgeb else
	     a2;	-- when bgea and cgea
	z <= a2 when agtb and agtc else
	     b2 when bgtc and bgea else
	     c;	-- when cgea and cgeb
	y <= a2 when (cgea and agtb) or (bgea and agtc) else
	     b2 when (cgeb and bgea) or (agtb and bgea) else
	     c; -- when (agtc and cgeb) or (bgtc and cgea)
end architecture;

architecture behavioral of Context_Compact_Sort is
begin
	process(a, b, c)
		variable agtb, bgtc, agtc, aeqb, beqc, aeqc, bgea, cgeb, cgea : boolean;
		variable ab_valid, bc_valid, ac_valid : boolean;
		variable a2, b2, c2 : Path;
	begin
		ab_valid := (a.valid and b.valid) = '1';
		aeqb := a.mpc = b.mpc and ab_valid;
		bc_valid := (b.valid and c.valid) = '1';
		beqc := b.mpc = c.mpc and bc_valid;
		ac_valid := (a.valid and c.valid) = '1';
		aeqc := a.mpc = c.mpc and ac_valid;
		a2 := a;
		b2 := b;
		c2 := c;
		-- Compact
		-- In case multiple entries are equal, merge them
		-- into the first one by alphabetical order
		if aeqb and beqc then	-- and aeqc
			-- Merge b and c into a
			a2.vmask := a.vmask or b.vmask or c.vmask;
			b2.valid := '0';
			c2.valid := '0';
		elsif aeqb then
			-- Merge b into a
			a2.vmask := a.vmask or b.vmask;
			b2.valid := '0';
		elsif aeqc then
			-- Merge c into a
			a2.vmask := a.vmask or c.vmask;
			c2.valid := '0';
		elsif beqc then
			-- Merge c into b
			b2.vmask := b.vmask or c.vmask;
			c2.valid := '0';
		end if;
		
		-- Sort
		-- Recompute valid bit pairs
		ab_valid := (a2.valid and b2.valid) = '1';
		bc_valid := (b2.valid and c2.valid) = '1';
		ac_valid := (a2.valid and c2.valid) = '1';
		-- Perform all comparisons
		agtb := (a.mpc > b.mpc and ab_valid) or (b.valid = '1' and a.valid = '0');
		bgea := not agtb;	-- For convenience
		bgtc := (b.mpc > c.mpc and bc_valid) or (c.valid = '1' and b.valid = '0');
		cgeb := not bgtc;
		agtc := (a.mpc > c.mpc and ac_valid) or (c.valid = '1' and a.valid = '0');
		cgea := not agtc;
		
		-- Mux everything
		if bgtc and agtc then
			x <= c2;
		elsif agtb and cgeb then
			x <= b2;
		else	-- bgea and cgea
			x <= a2;
		end if;
		if (cgea and agtb) or (bgea and agtc) then
			y <= a2;
		elsif (agtc and cgeb) or (bgtc and cgea) then
			y <= c2;
		else 	-- (cgeb and bgea) or (agtb and bgea)
			y <= b2;
		end if;
		if agtb and agtc then
			z <= a2;
		elsif bgtc and bgea then
			z <= b2;
		else	-- cgea and cgeb
			z <= c2;
		end if;
	end process;
end architecture;


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
