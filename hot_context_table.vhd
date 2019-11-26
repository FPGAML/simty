library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;
use std.textio.all;


-- 1 read port, 1 write port
entity Hot_Context_Table is
	port (
		clock : in std_logic;
		reset : in std_logic;
		dump : in std_logic;
		isx : in std_logic;
		wid_read : in warpid;
		context_read : out Path;
		write_enable : in std_logic;
		wid_write : in warpid;
		context_write : in Path
	);
end entity;

-- Stores complete context including valid bit
architecture structural of Hot_Context_Table is
	constant entry_width : integer := calldepth_width + warpsize + code_address'length + 1;
	subtype entry is std_logic_vector(entry_width - 1 downto 0);
	type ram is array(0 to warpcount - 1) of entry;
	signal raw_write, raw_read : entry;
	signal do_bypass_0, do_bypass_1 : std_logic;
	signal hct : ram;
	signal context_read_nb, context_write_1 : Path;
	signal dump_count : integer := 0;

	procedure DumpHCT(fname : string ; myram : ram ; wpc : natural) is
		--variable fname		: string := "hct_dump.txt";
		file mem_dump		: text open write_mode is fname;
		variable outline	: line;
		variable addr		: natural := 0;
	begin
		--report "Opened HCT dump file " & fname;
		for i in 0 to wpc - 1 loop
			write(outline, to_hstring(myram(i)));
			writeline(mem_dump, outline);
		end loop;
	end procedure;
begin

	-- Flatten input
	raw_write(warpsize - 1 downto 0) <= context_write.vmask;
	raw_write(warpsize) <= context_write.valid;
	raw_write(warpsize + code_address'length downto warpsize + 1) <= context_write.mpc;
	raw_write(warpsize + code_address'length + calldepth_width downto warpsize + code_address'length + 1) <= context_write.calldepth;

	-- Expand output
	context_read_nb.vmask <= raw_read(warpsize - 1 downto 0);
	context_read_nb.valid <= raw_read(warpsize);
	context_read_nb.mpc <= raw_read(warpsize + code_address'length downto warpsize + 1);
	context_read_nb.calldepth <= raw_read(warpsize + code_address'length + calldepth_width downto warpsize + code_address'length + 1);

	-- Bypass when reading and writing at the same address
	do_bypass_0 <= '1' when wid_read = wid_write and write_enable = '1' else '0';
	context_read <= context_write_1 when do_bypass_1 = '1' else context_read_nb;




	process(clock)
	begin
		if rising_edge(clock) then
			raw_read <= hct(to_integer(unsigned(wid_read)));
			if (write_enable and not reset) = '1' then
				hct(to_integer(unsigned(wid_write))) <= raw_write;
			end if;
			do_bypass_1 <= do_bypass_0;
			context_write_1 <= context_write;
			-- if dump = '1' then
			-- 	DumpHCT("dumps/" & integer'image(dump_count) & "_" & to_string(isx) & "_dead_pc_hct_dump" &  ".txt", hct, warpcount);
			-- else
			-- 	DumpHCT("dumps/" & integer'image(dump_count) & "_" & to_string(isx) & "_live_pc_hct_dump" & ".txt", hct, warpcount);
			-- end if;
			dump_count <= dump_count + 1;
		end if;
	end process;
end architecture;
