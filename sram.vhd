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
--			rd_data : out std_logic_vector(width - 1 downto 0);


			wr_enable : in std_logic;
			wr_address : in unsigned(logdepth - 1 downto 0);
			wr_data : in std_logic_vector(32 - 1 downto 0);
--			wr_data : in std_logic_vector(width - 1 downto 0);

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
--				rd_data => rd_data(i * width + 31 downto i * width),

				wr_enable => sa_enable(i),
				wr_address => wr_address,
				wr_data => wr_data(i * 32 + 31 downto i * 32),
--				wr_data => wr_data(i * width + 31 downto i * width),

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
