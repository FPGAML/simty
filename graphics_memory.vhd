library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

entity Graphics_Memory is
	port (
		pu_clock : in std_logic;
		reset : in std_logic;
		pu_request : in Bus_Request;
		pu_response : out Bus_Response;

		vga_clock : in std_logic;
		vga_addr : in std_logic_vector(15 downto 0);
		vga_out : out std_logic_vector(7 downto 0)
	);
end entity;

architecture structural of Graphics_Memory is
	constant log_capacity : natural := 12;	-- Total memory size in bytes
	constant bank_logdepth : natural := log_capacity - log_blocksize;
	signal valid_in_range : std_logic;
	signal actual_write_mask : mask;
	signal vga_out_row : vector;
	--constant vga_window_start : unsigned(31 downto log_blocksize) := (14 => '1', others => '0');
	constant vga_window_start : unsigned(31 downto log_blocksize) := (others => '0');
	constant vga_window_size : unsigned(31 downto log_blocksize) := (log_capacity => '1', others => '0');
	signal vga_addr_lo : integer;
begin
	-- Comparison of upper bits
	valid_in_range <= pu_request.valid when (unsigned(pu_request.address) - vga_window_start) < vga_window_size else '0';

	-- Instanciate warpsize x 32-wide banks of 16K/warpsize entries each
	banks: for i in 0 to warpsize - 1 generate
		actual_write_mask(i) <= valid_in_range and pu_request.is_write and pu_request.write_mask(i);
		bank_i: SRAM32_dp
			generic map (logdepth => bank_logdepth)
			port map (
				a_clock => pu_clock,
				a_address => unsigned(pu_request.address(log_capacity - 1 downto log_blocksize)),
				a_rd_data => pu_response.data(32 * (i+1) - 1 downto 32 * i),
				a_wr_enable => actual_write_mask(i),
				a_wr_data => pu_request.data(32 * (i+1) - 1 downto 32 * i),
				a_wr_byteenable => pu_request.shared_byte_enable,

				b_clock => vga_clock,
				b_address => unsigned(vga_addr(log_capacity - 1 downto log_blocksize)),
				b_rd_data => vga_out_row(32 * (i+1) - 1 downto 32 * i),
				b_wr_enable => '0',
				b_wr_data => (others => '0'),
				b_wr_byteenable => "0000"
			);
	end generate;

	-- Set response metadata: valid, wid, address
	process(pu_clock)
	begin
		if rising_edge(pu_clock) then
			if reset = '1' then
				pu_response.valid <= '0';
				pu_response.wid <= (others => '-');
				pu_response.address <= (others => '-');
			else
				pu_response.valid <= valid_in_range and pu_request.is_read and pu_request.valid;
				pu_response.wid <= pu_request.wid;
				pu_response.address <= pu_request.address;
			end if;
		end if;
	end process;

	-- Mux VGA output
	vga_addr_lo <= to_integer(unsigned(vga_addr(log_blocksize - 1 downto 0)));
	vga_out <= vga_out_row((vga_addr_lo+1) * 8 - 1 downto vga_addr_lo * 8);
end architecture;
