library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- Simple data memory
entity Scratchpad is
	port (
		clock : in std_logic;
		reset : in std_logic;
		--wid_in : in warpid;
		--address : in block_address;
		--data_in : in vector;
		--op : in memop_t;
		--write_mask : in mask;
		--shared_byte_enable : in std_logic_vector(3 downto 0);
		request : in Bus_Request;

		-- Asynchronous response
		response : out Bus_Response
		--data_out : out vector;
		--data_out_valid : out std_logic;
		--data_out_wid : out warpid
	);
end entity;

architecture structural of Scratchpad is
--	constant log_depth : natural := 7;
--	constant log_depth : natural := 16; -- more memory
	constant log_depth : natural := 17; -- even more memory


	signal rd_address : std_logic_vector(log_depth - 1 downto 0);
	signal wr_address : std_logic_vector(log_depth - 1 downto 0);
	signal wr_enable : std_logic;
	signal is_load_0, is_load_1 : std_logic;
	signal wid_1 : warpid;
	signal data_sig : std_logic_vector(128 - 1 downto 0);
begin
	rd_address <= request.address(log_depth + log_blocksize - 1 downto log_blocksize); -- 7+4 downto 4 ; 11 downto 4
	wr_address <= rd_address;
	wr_enable <= request.is_write and request.valid;
	is_load_0 <= request.is_read and request.valid;

	subarrays : SRAM
		generic map (
			width => 32 * warpsize,
			logdepth => log_depth
		)
		port map (
			clock => clock,
			reset => reset,
			rd_address => unsigned(rd_address),
			rd_data => response.data,
			wr_enable => wr_enable,
			wr_address => unsigned(wr_address),
			wr_data => request.data,
			wr_common_byteenable => request.shared_byte_enable,
			wr_wordenable => request.write_mask
		);
	process(clock) is
	begin
		if rising_edge(clock) then
			if reset = '1' then
				is_load_1 <= '0';
				wid_1 <= (others => '0');
				response.address <= (others => '-');
			else
				is_load_1 <= is_load_0;
				wid_1 <= request.wid;
				response.address <= request.address;
			end if;
		end if;
	end process;
	response.valid <= is_load_1;
	response.wid <= wid_1;
	data_sig <= response.data;
end architecture;
