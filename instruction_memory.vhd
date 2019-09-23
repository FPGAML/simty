library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;
use work.Simty_Pkg.all;

entity Instruction_Memory is
	port (
		clock : in std_logic;
		reset : in std_logic;
		-- Interface to Fetch
		request : in ICache_Request;
		response : out ICache_Response
	);
end entity;

architecture structural of Instruction_Memory is
	constant rambits : natural := 10;
	type ram is array(0 to 2**rambits - 1) of instruction_word;
	constant use_rom : boolean := false;


	-- Initialization function for simulation: plain hex format
	-- Thanks Altera for ignoring textio calls SILENTLY
	impure function Read_File(fname : string) return ram is
		file fh       : text open read_mode is fname;
		variable ln   : line;
		variable addr : natural := 0;
		variable word : instruction_word;
		variable output : ram;
	begin
		report "Opened file " & fname;
		while addr < 2**rambits loop
			if endfile(fh) then
				report "EOF!";
				output(addr) := X"baadf00d";
				exit;
			end if;
			readline(fh, ln);
			--report "line(" & integer'image(addr) & ")= " & ln.all;
			hread(ln, word);
			output(addr) := word;
			addr := addr + 1;
		end loop;
		return output;
	end function;

	--signal imem : ram := Read_File("tests/rainbow.hex");
	--signal imem : ram := Read_File("tests/rainCopies.hex");
	--signal imem : ram := Read_File("tests/rainTinyCopies.hex");
	--signal imem : ram := Read_File("tests/rainbowPlusEpsilon.hex");
	--signal imem : ram := Read_File("tests/manyCopies.hex");
	--signal imem : ram := Read_File("tests/writeAndRead.hex");
	--signal imem : ram := Read_File("tests/fullTest.hex");
	--signal imem : ram := Read_File("tests/mandelbrot.hex");
	--signal imem : ram := Read_File("tests/fCall.hex");
	--signal imem : ram := Read_File("tests/mwp.hex");
	--signal imem : ram := Read_File("tests/invert.hex");
	--signal imem : ram := Read_File("tests/bytewrites.hex");
	signal imem : ram := Read_File("tests/switch_colors.hex");





	signal address : integer := 0;
	signal iw_sent_to_simty : instruction_word;
begin
	using_the_rom : if use_rom generate
		rom : Instruction_ROM
		port map (
			clock => clock,
			addr => request.address(9 downto 2),
			data => response.data
		);
	end generate;
	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				response.valid <= '0';
				response.wid <= (others => '0');
				response.address <= DummyPC;
			else
				address <= to_integer(unsigned(request.address(rambits + 1 downto 2)));
				response.valid <= request.valid;
				response.wid <= request.wid;
				response.address <= request.address;
			end if;
		end if;
	end process;
	response.data <= imem(address);
	iw_sent_to_simty <= imem(address);
end architecture;
