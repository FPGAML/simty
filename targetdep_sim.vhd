-- Target-dependent components. Generic version

---------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- 2 read/write ports, 2 clocks
entity SRAM32_dp is
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
architecture portable of SRAM32_dp is
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
