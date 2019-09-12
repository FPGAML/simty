library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- Banked memory simulating a multi-ported memory
-- 2 banks
entity Banked_RF is
	port (
		clock : in std_logic;
		reset : in std_logic;

		-- Read ports a, b
		-- a has the priority: always succeed
		a_valid : in std_logic;
		a_addr : in rfbank_address;
		a_bank : in std_logic;
		a_data : out vector;

		b_valid : in std_logic;
		b_addr : in rfbank_address;
		b_bank : in std_logic;
		b_data : out vector;
		b_conflict : out std_logic;

		-- Write ports x, y
		-- x has the priority
		x_valid : in std_logic;
		x_addr : in rfbank_address;
		x_bank : in std_logic;
		x_data : in vector;
		x_wordenable : in mask;

		y_valid : in std_logic;
		y_addr : in rfbank_address;
		y_bank : in std_logic;
		y_data : in vector;
		y_wordenable : in mask;
		y_conflict : out std_logic
	);
end entity;

-- No address comparison: conflict when reading/writing the same address on the same bank
-- No bypass if writing and reading at the same address
architecture structural of Banked_RF is
	signal bank0_rdaddr : rfbank_address;
	signal bank0_rddata : vector;
	signal bank1_rdaddr : rfbank_address;
	signal bank1_rddata : vector;
	signal bank0_wraddr, bank1_wraddr : rfbank_address;
	signal bank0_wrdata, bank1_wrdata : vector;
	signal bank0_wren, bank1_wren : std_logic;
	signal bank0_wordenable, bank1_wordenable : std_logic_vector(warpsize - 1 downto 0);

	signal bank0_rmux : std_logic;	-- 0: read from a, 1: read from b
	signal bank1_rmux : std_logic;
	signal bank0_wmux : std_logic;	-- 0: write to x, 1: write to y
	signal bank1_wmux : std_logic;

	signal a_bank_1, b_bank_1 : std_logic;
begin
	-- Arbitration logic
	bank0_rmux <= '0' when a_valid = '1' and a_bank = '0' else
	              '1' when b_valid = '1' and b_bank = '0' else
	              '-';

	bank1_rmux <= '0' when a_valid = '1' and a_bank = '1' else
	              '1' when b_valid = '1' and b_bank = '1' else
	              '-';

	b_conflict <= '1' when (a_valid and b_valid) = '1' and a_bank = b_bank else '0';

	bank0_wmux <= '0' when x_valid = '1' and x_bank = '0' else
	              '1' when y_valid = '1' and y_bank = '0' else
	              '-';

	bank1_wmux <= '0' when x_valid = '1' and x_bank = '1' else
	              '1' when y_valid = '1' and y_bank = '1' else
	              '-';

	y_conflict <= '1' when (x_valid and y_valid) = '1' and x_bank = y_bank else '0';

	-- Read address mux
	bank0_rdaddr <= b_addr when bank0_rmux = '1' else a_addr;
	bank1_rdaddr <= b_addr when bank1_rmux = '1' else a_addr;

	-- Write address mux
	bank0_wraddr <= y_addr when bank0_wmux = '1' else x_addr;
	bank0_wordenable <= y_wordenable when bank0_wmux = '1' else x_wordenable;
	bank0_wrdata <= y_data when bank0_wmux = '1' else x_data;
	-- Do not mux wren signals, compute them!
	bank0_wren <= '1' when (x_valid = '1' and x_bank = '0') or (y_valid = '1' and y_bank = '0') else
	              '0';

	bank1_wraddr <= y_addr when bank1_wmux = '1' else x_addr;
	bank1_wordenable <= y_wordenable when bank1_wmux = '1' else x_wordenable;
	bank1_wrdata <= y_data when bank1_wmux = '1' else x_data;
	--bank1_wren <= y_valid when bank1_wmux = '1' else x_valid;
	bank1_wren <= '1' when (x_valid = '1' and x_bank = '1') or (y_valid = '1' and y_bank = '1') else
	              '0';

	bank0 : SRAM
		generic map (
			width => warpsize * 32,
			logdepth => rfbank_address'length)
		port map (
			clock => clock,
			reset => reset,
			rd_address => unsigned(bank0_rdaddr),
			rd_data => bank0_rddata,
			wr_enable => bank0_wren,
			wr_address => unsigned(bank0_wraddr),
			wr_data => bank0_wrdata,
			wr_wordenable => bank0_wordenable);

	bank1 : SRAM
		generic map (
			width => warpsize * 32,
			logdepth => rfbank_address'length)
		port map (
			clock => clock,
			reset => reset,
			rd_address => unsigned(bank1_rdaddr),
			rd_data => bank1_rddata,
			wr_enable => bank1_wren,
			wr_address => unsigned(bank1_wraddr),
			wr_data => bank1_wrdata,
			wr_wordenable => bank1_wordenable);

	process(clock) is
	begin
		if rising_edge(clock) then
			if reset = '1' then
				a_bank_1 <= '0';
				b_bank_1 <= '0';
			else
				a_bank_1 <= a_bank;
				b_bank_1 <= b_bank;
			end if;
		end if;
	end process;

	-- Read data mux
	-- No bypass for now. Need to mux bypass here eventually
	a_data <= bank1_rddata when a_bank_1 = '1' else bank0_rddata;
	b_data <= bank1_rddata when b_bank_1 = '1' else bank0_rddata;

end architecture;
