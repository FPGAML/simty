library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.Simty_Pkg.all;

-- Simple I/O memory, mostly for testing purposes
entity Testio is
	port (
		clock : in std_logic;
		reset : in std_logic;
		request : in Bus_Request;

		-- Asynchronous response
		response : out Bus_Response
	);
end entity;

architecture structural of Testio is
	constant log_depth : natural := 7;
	constant ram_lines : natural := 16;

	type ram is array(0 to 2**ram_lines - 1) of vector; -- a vector is 32*warpsize bits; warpsize is currently 4, so 128 bits or 16B

	-- So this would be 64 kVectors, or 1MB

	-- Initialization function for simulation: plain hex format
	-- Thanks Altera for ignoring textio calls SILENTLY
	impure function Read_File(fname : string) return ram is
		file fh       : text open read_mode is fname;
		variable ln   : line;
		variable addr : natural := 0;
		variable word : vector;
		variable output : ram;
	begin
		report "Opened file " & fname;
		while addr < 2**ram_lines loop
			if endfile(fh) then
				report "EOF!";
				output(addr) := X"baadf00dbaadf00dbaadf00dbaadf00d";
				exit;
			end if;
			readline(fh, ln);
			report "line(" & integer'image(addr) & ")= " & ln.all;
			hread(ln, word);
			output(addr) := word;
			addr := addr + 1;
		end loop;
		return output;
	end function;

	signal io_ram : ram := Read_File("tests/heximage.txt");

	procedure Write_To_File(fname : string ; reqdata : vector) is
		file mem_dump		: text open write_mode is fname;
		variable outline	: line;
		variable addr		: natural := 0;
	begin
		report "Opened output file " & fname;
		for i in 0 to 2**ram_lines - 1 loop
			write(outline, to_hstring(io_ram(i)));
			writeline(mem_dump, outline);
		end loop;
	end procedure;

--	signal imem : ram := Read_File("tests/mandelbrot.hex");
	signal wr_enable : std_logic;
	signal is_load_0, is_load_1 : std_logic;
	signal wid_1 : warpid;
	signal short_address : std_logic_vector(ram_lines - 1 downto 0);

begin

	wr_enable <= request.is_write and request.valid;
	is_load_0 <= request.is_read and request.valid;
	short_address <= request.address(ram_lines - 1 + log_blocksize downto log_blocksize);

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
				if request.valid = '1' then
					if request.is_write = '1' then
						--io_ram(to_integer(unsigned(short_address))) <= request.data;
						io_ram(to_integer(unsigned(short_address))) <= set_io_data(request, io_ram(to_integer(unsigned(short_address))));
					elsif request.is_read = '1' then
						response.data <= io_ram(to_integer(unsigned(short_address)));
					end if;
				end if;

				if request.valid = '1' and request.address = X"2FFFF00" and request.wid = "111" then
					Write_To_File("result.res", request.data);
				end if;
			end if;
		end if;
	end process;
	response.valid <= is_load_1;
	response.wid <= wid_1;
end architecture;
