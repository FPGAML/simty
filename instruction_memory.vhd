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
		--dummy_addr : in unsigned(7 downto 0);
		--dummy_data : in instruction_word;
		--dummy_valid : in std_logic;
		-- Interface to Fetch
		request : in ICache_Request;
		response : out ICache_Response
	);
end entity;

architecture structural of Instruction_Memory is
	constant rambits : natural := 8;
	type ram is array(0 to 2**rambits - 1) of instruction_word;

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
			report "line(" & integer'image(addr) & ")= " & ln.all;
			hread(ln, word);
			--report "word(" & integer'image(addr) & ")(0)= " & std_logic'image(word(0));
			output(addr) := word;
			--output(addr) := X"f0000137";
			--output(addr) := std_logic_vector(to_unsigned(addr, 32));
			addr := addr + 1;
		end loop;
		return output;
	end function;

	--signal imem : ram;-- := Read_File("/home/sylvain/Projects/simty/imem.hex");
	--attribute ram_init_file : string;
	--attribute ram_init_file of imem : signal is "../imem.mif";
	--attribute ramstyle : string;
	--attribute ramstyle of imem : signal is "M4K,no_rw_check";
	--attribute preserve : boolean;
	--attribute noprune : boolean;
	--attribute keep : boolean;
	--attribute preserve of imem : signal is true;
	--attribute noprune of imem : signal is true;
	--attribute keep of imem : signal is true;
	--attribute romstyle : string;
	--attribute romstyle of imem : signal is "M4K";	-- Hopeless :(
	--signal address : integer := 0;
	--signal data : instruction_word;
begin
	-- I gave up.
	rom : Instruction_ROM
		port map (
			clock => clock,
			addr => request.address(9 downto 2),
			data => response.data
		);
	--data <= response.data;
	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				--address <= 0;
				response.valid <= '0';
				response.wid <= (others => '0');
				response.address <= DummyPC;
			else
				--address <= to_integer(unsigned(request.address(rambits + 1 downto 2)));
				response.valid <= request.valid;
				response.wid <= request.wid;
				response.address <= request.address;
				--if dummy_valid = '1' then
				--	imem(to_integer(dummy_addr)) <= dummy_data;
				--end if;
			end if;
		end if;
	end process;
	--response.data <= imem(address);
end architecture;
