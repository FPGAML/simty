library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- SRAM
-- 1 write port, 1 read port
-- Split into 32-bit words, same byte-enable mask for all words
entity SRAM is
	generic (
		width : positive := 128;
		logdepth : positive := 7
	);
	port (
		clock : in std_logic;
		reset : in std_logic;
		--rd_enable : in std_logic;
		rd_address : in unsigned(logdepth - 1 downto 0);
		rd_data : out std_logic_vector(width - 1 downto 0);

		wr_enable : in std_logic;
		wr_address : in unsigned(logdepth - 1 downto 0);
		wr_data : in std_logic_vector(width - 1 downto 0);
		--wr_byteenable : in std_logic_vector((width+7)/8 - 1 downto 0)
		wr_common_byteenable : in std_logic_vector(3 downto 0) := "1111";
		wr_wordenable : in std_logic_vector((width + 31) / 32 - 1 downto 0)
	);
end entity;

-- Second attempt at synthesizable SRAM w/ byte-enable
-- split into subarrays
architecture altera of SRAM is
	constant subarrays : positive := (width + 31) / 32;
	component SRAM32we is
		generic (
			logdepth : positive := 7
		);
		port (
			clock : in std_logic;
			reset : in std_logic;
			--rd_enable : in std_logic;
			rd_address : in unsigned(logdepth - 1 downto 0);
			rd_data : out std_logic_vector(32 - 1 downto 0);

			wr_enable : in std_logic;
			wr_address : in unsigned(logdepth - 1 downto 0);
			wr_data : in std_logic_vector(32 - 1 downto 0);
			wr_byteenable : in std_logic_vector(4 - 1 downto 0)
		);
	end component;
	signal sa_enable : std_logic_vector(subarrays - 1 downto 0);
begin
	subarrays_inst : for i in 0 to subarrays - 1 generate
		sa_enable(i) <= wr_enable and wr_wordenable(i);
		subarray_i : SRAM32we
			generic map ( logdepth => logdepth )
			port map (
				clock => clock,
				reset => reset,
				rd_address => rd_address,
				rd_data => rd_data(i * 32 + 31 downto i * 32),
				wr_enable => sa_enable(i),
				wr_address => wr_address,
				wr_data => wr_data(i * 32 + 31 downto i * 32),
				--wr_byteenable => wr_byteenable(i * 4 + 3 downto i * 4)
				wr_byteenable => wr_common_byteenable
			);
	end generate;

end architecture;

-----------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- 1 write port, 1 read port
entity SRAM32we is
	generic (
		logdepth : positive := 7
	);
	port (
		clock : in std_logic;
		reset : in std_logic;
		--rd_enable : in std_logic;
		rd_address : in unsigned(logdepth - 1 downto 0);
		rd_data : out std_logic_vector(32 - 1 downto 0);

		wr_enable : in std_logic;
		wr_address : in unsigned(logdepth - 1 downto 0);
		wr_data : in std_logic_vector(32 - 1 downto 0);
		wr_byteenable : in std_logic_vector(4 - 1 downto 0)
	);
end entity;

-- Second attempt at synthesizable SRAM w/ byte-enable
-- From Altera template, heavily modified
architecture altera of SRAM32we is
	constant w : positive := 32;
	constant bytes : positive := w / 8;
	--  build up 2D array to hold the memory
	type word_t is array (0 to bytes-1) of std_logic_vector(7 downto 0);
	type ram_t is array (0 to 2 ** logdepth - 1) of word_t;
	-- del the RAM with care
	signal ram : ram_t;
	signal q_local : word_t;
begin
	-- Re-organize the read data from the RAM to match the output
	unpack: for i in 0 to bytes - 1 generate    
		rd_data(8*(i+1) - 1 downto 8*i) <= q_local(i);
	end generate unpack;
	
	process(clock)
	begin
		if rising_edge(clock) then
			--if reset = '1' then
			--	q_local <= (others => (others => '0'));
			--else
				q_local <= ram(to_integer(rd_address));
				if wr_enable = '1' then
					-- That would have been too easy!
					--for i in 0 to bytes - 1 loop
					--	if wr_byteenable(i) = '1' then
					--		ram(to_integer(wr_address))(i) <= wr_data(i*8 + 7 downto i*8);
					--	end if;
					--end loop;
					if wr_byteenable(0) = '1' then
						ram(to_integer(wr_address))(0) <= wr_data(0*8 + 7 downto 0*8);
					end if;
					if wr_byteenable(1) = '1' then
						ram(to_integer(wr_address))(1) <= wr_data(1*8 + 7 downto 1*8);
					end if;
					if wr_byteenable(2) = '1' then
						ram(to_integer(wr_address))(2) <= wr_data(2*8 + 7 downto 2*8);
					end if;
					if wr_byteenable(3) = '1' then
						ram(to_integer(wr_address))(3) <= wr_data(3*8 + 7 downto 3*8);
					end if;
				end if;
			--end if;
		end if;
	end process;
end architecture;

---------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- 1 write port, 1 read port
entity SRAM32 is
	generic (
		logdepth : positive := 7
	);
	port (
		clock : in std_logic;
		reset : in std_logic;
		rd_address : in unsigned(logdepth - 1 downto 0);
		rd_data : out std_logic_vector(32 - 1 downto 0);

		wr_enable : in std_logic;
		wr_address : in unsigned(logdepth - 1 downto 0);
		wr_data : in std_logic_vector(32 - 1 downto 0)
	);
end entity;

-- Third attempt: give up byte-enable, dual-port BRAMs are not wider than 32-bit anyway
architecture altera of SRAM32 is
	constant w : positive := 32;
	constant bytes : positive := w / 8;
	type ram_t is array (0 to 2 ** logdepth - 1) of std_logic_vector(31 downto 0);
	signal ram : ram_t;
begin
	process(clock)
	begin
		if rising_edge(clock) then 
			--if reset = '1' then
			--	rd_data <= (others => '0');
			--else
				rd_data <= ram(to_integer(rd_address));
			--end if;
			if wr_enable = '1' then
				ram(to_integer(wr_address)) <= wr_data;
			end if;
		end if;
	end process;
end architecture;


---------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- 2 read/write ports, 2 clocks
entity SRAM32_dp_portable is
	generic (
		logdepth : positive := 7
	);
	port (
		a_clock : in std_logic;
		a_address : in unsigned(logdepth - 1 downto 0);
		a_rd_data : out std_logic_vector(32 - 1 downto 0);
		a_wr_enable : in std_logic;
		a_wr_data : in std_logic_vector(32 - 1 downto 0);
		a_wr_byteenable : in std_logic_vector(3 downto 0);
		
		b_clock : in std_logic;
		b_address : in unsigned(logdepth - 1 downto 0);
		b_rd_data : out std_logic_vector(32 - 1 downto 0);
		b_wr_enable : in std_logic;
		b_wr_data : in std_logic_vector(32 - 1 downto 0);
		b_wr_byteenable : in std_logic_vector(3 downto 0)
	);
end entity;
architecture portable of SRAM32_dp_portable is
	constant w : positive := 32;
	constant bytes : positive := w / 8;
	type ram_t is array (0 to 2 ** logdepth - 1) of std_logic_vector(31 downto 0);
	signal ram : ram_t;
	signal a_address_1, b_address_1 : natural range 0 to 2 ** logdepth - 1;
	signal a_addr_int, b_addr_int : natural range 0 to 2 ** logdepth - 1;
	signal a_actual_byteenable, b_actual_byteenable : std_logic_vector(3 downto 0);
begin
	a_addr_int <= to_integer(a_address);
	b_addr_int <= to_integer(b_address);
	be_gen : for i in 0 to 3 generate
		a_actual_byteenable(i) <= a_wr_byteenable(i) and a_wr_enable;
		b_actual_byteenable(i) <= b_wr_byteenable(i) and b_wr_enable;
	end generate;
	process(a_clock)
	begin
		if rising_edge(a_clock) then 
			--if a_wr_enable = '1' then
				if a_actual_byteenable(0) = '1' then
					ram(a_addr_int)(7 downto 0) <= a_wr_data(7 downto 0);
				end if;
				if a_actual_byteenable(1) = '1' then
					ram(a_addr_int)(15 downto 8) <= a_wr_data(15 downto 8);
				end if;
				if a_actual_byteenable(2) = '1' then
					ram(a_addr_int)(23 downto 16) <= a_wr_data(23 downto 16);
				end if;
				if a_actual_byteenable(3) = '1' then
					ram(a_addr_int)(31 downto 24) <= a_wr_data(31 downto 24);
				end if;
			--end if;
			--a_address_1 <= to_integer(a_address);
			a_rd_data <= ram(a_addr_int);
		end if;
	end process;
	--a_rd_data <= ram(a_address_1);
	
	process(b_clock)
	begin
		if rising_edge(b_clock) then 
--			if b_wr_enable = '1' then
--				if b_actual_byteenable(0) = '1' then
--					ram(b_addr_int)(7 downto 0) <= b_wr_data(7 downto 0);
--				end if;
--				if b_actual_byteenable(1) = '1' then
--					ram(b_addr_int)(15 downto 8) <= b_wr_data(15 downto 8);
--				end if;
--				if b_actual_byteenable(2) = '1' then
--					ram(b_addr_int)(23 downto 16) <= b_wr_data(23 downto 16);
--				end if;
--				if b_actual_byteenable(3) = '1' then
--					ram(b_addr_int)(31 downto 24) <= b_wr_data(31 downto 24);
--				end if;
				
				--ram(to_integer(b_address)) <= b_wr_data;
--			end if;
			--b_address_1 <= to_integer(b_address);
			b_rd_data <= ram(b_addr_int);
		end if;
	end process;
	--b_rd_data <= ram(b_address_1);
	
end architecture;
