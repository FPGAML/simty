library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.Simty_Pkg.all;


entity Unit_Tester is
	port (
		-- Inputs
		clock : in std_logic;
		reset : in std_logic
	);
end entity;


architecture structural of Unit_Tester is
	constant ram_lines : natural := 18;
	constant test_ccs : boolean := false;
	constant test_cct : boolean := true;
	constant number_of_tests : natural := 128000;

	type ram is array(0 to 2**ram_lines - 1) of Path; -- 11 hex digits per Path
	subtype path_as_logic_vector is std_logic_vector(log_codesize + warpsize + calldepth_width - 2 downto 0); -- size 43

	signal ram_pointer : natural := 0;
	signal outram_pointer : natural := 0;
	signal res_written : boolean := false;

	signal uta, utb, utc, utx, uty, utz, utyin, utzin, utyout, previous_output : Path;
	signal test_in_path_a, test_in_path_b, test_in_path_y, test_in_path_z, test_ccs_output_path, test_out_path : path_as_logic_vector;

	signal wid_sig : warpid := "000";
	signal wid_out_sig : warpid;
	signal command_sig, command_sig_min1, command_sig_min2 : CCT_Command := Nop;
	signal writeback_sig : std_logic;

	signal it_counter : natural := 0;
	signal int_command, int_command_min1, int_command_min2 : natural := 0;
	signal cct_head : natural := 0;

	type head_array is array(0 to warpcount) of natural;
	signal cct_heads : head_array := (others => 0);
	signal iterations_since_switch : natural := 0;

	signal y_in_valid, y_out_valid, previous_output_valid : std_logic;




	function Path_To_Logic_Vector(p : Path) return path_as_logic_vector is
		variable outvector : path_as_logic_vector;
	begin
		outvector(calldepth_width - 1 downto 0)														:= p.calldepth;
		outvector(warpsize + calldepth_width - 1 downto calldepth_width)							:= p.vmask;
		outvector(log_codesize + warpsize + calldepth_width - 3 downto warpsize + calldepth_width)	:= p.mpc;
		outvector(log_codesize + warpsize + calldepth_width - 2)									:= p.valid;
		return outvector;
	end function;

	function Logic_Vector_To_Path(plv : path_as_logic_vector) return Path is
		variable outpath : Path;
	begin
		-- calldepth_count is std_logic_vector(calldepth_width - 1 downto 0); calldepth_width is 8
		outpath.calldepth	:= plv(calldepth_width - 1 downto 0);
		-- mask is std_logic_vector(warpsize - 1 downto 0); warpsize is 4
		outpath.vmask 		:= plv(warpsize + calldepth_width - 1 downto calldepth_width);
		-- code_address is std_logic_vector(log_codesize - 1 downto 2); log_codesize is 32
		outpath.mpc			:= plv(log_codesize + warpsize + calldepth_width - 3 downto warpsize + calldepth_width);
		-- so that's 42
		outpath.valid		:= plv(log_codesize + warpsize + calldepth_width - 2);
		return outpath;
	end function;


	impure function Read_Path_Input_File(fname : string) return ram is
		file fh      	: text open read_mode is fname;
		variable ln  	: line;
		variable addr	: natural := 0;
		--									42 dowto 0
--		variable word	: std_logic_vector(log_codesize + warpsize + calldepth_width - 2 downto 0);
		variable word	: path_as_logic_vector;
		variable p		: Path;
		variable output : ram;
	begin
		report "Unit_Tester: Opened file " & fname;
		while addr < 2**ram_lines loop
			if endfile(fh) then
				report "EOF!";
				p.valid := '0';
				p.calldepth := X"00";
				p.vmask := X"d";
				p.mpc := "001111000011110000111100001111";
				output(addr) := p;
				exit;
			end if;
			readline(fh, ln);
			--report "line(" & integer'image(addr) & ")= " & ln.all;
			hread(ln, word);
			--report "line(" & integer'image(addr) & ")= " & to_hstring(word);
			p := Logic_Vector_To_Path(word);
			output(addr) := p;
			addr := addr + 1;
		end loop;
		return output;
	end function;

	signal io_ram : ram := Read_Path_Input_File("tests/paths_input.txt");
	signal output_ram : ram;

	procedure Write_Paths_To_File(fname : string) is
		file mem_dump		: text open write_mode is fname;
		variable outline	: line;
		variable addr		: natural := 0;
		variable p			: Path;
		variable outvector	: std_logic_vector(log_codesize + warpsize + calldepth_width - 2 downto 0);
	begin
		report "Opened output file " & fname;
		for i in 0 to 2**ram_lines - 1 loop
			p := output_ram(i);
			outvector := Path_To_Logic_Vector(p);
			write(outline, to_hstring(outvector));
			writeline(mem_dump, outline);
		end loop;
	end procedure;

	procedure Write_Paths_As_CSV(fname : string) is
		file mem_dump		: text open write_mode is fname;
		variable outline	: line;
		variable addr		: natural := 0;
		variable p			: Path;
	begin
		report "Opened output file " & fname;
		for i in 0 to 2**ram_lines - 1 loop
			p := output_ram(i);
			write(outline, (  std_logic'image(p.valid) & ht & to_hstring(p.mpc) & ht & to_hstring(p.vmask) & ht & to_hstring(p.calldepth) ) );
			writeline(mem_dump, outline);
		end loop;
	end procedure;

begin

	test_ccs_gen : if test_ccs generate
		ccs : Context_Compact_Sort
			port map (
				a => uta,
				b => utb,
				c => utc,
				x => utx,
				y => uty,
				z => utz
			);
	end generate;


	test_cct_gen : if test_cct generate
		cct : Cold_Context_Table
			port map (
				clock => clock,
				reset => reset,
				wid => wid_sig,
				command => command_sig,
				y_in => utyin, -- not useful
				z_in => utzin,
				y_out => utyout,
				wid_out => wid_out_sig,
				y_writeback => writeback_sig
			);
	end generate;

	-- command_sig <=	Push when utyin.valid = '1' and utzin.valid = '1' and cct_head < 3 else
	-- 				Pop when utyin.valid = '0' and utzin.valid = '0' and cct_head > 0 else
	-- 				Nop; -- I guess it makes sense to send Nop if Y and Z are valid but the cct is full

	command_sig <=	Push when utyin.valid = '1' and utzin.valid = '1' and cct_heads(to_integer(unsigned(wid_sig))) < 3 else
					Pop when utyin.valid = '0' and utzin.valid = '0' and cct_heads(to_integer(unsigned(wid_sig)))  > 0 else
					Nop; -- I guess it makes sense to send Nop if Y and Z are valid but the cct is full

	with command_sig select int_command <=
		1 when Push,
		2 when Pop,
		3 when Nop,
		4 when others;

	y_in_valid <= utyin.valid;
	y_out_valid <= utyout.valid;
	previous_output_valid <= previous_output.valid;

	utyin <= io_ram(ram_pointer); -- not useful, yet somehow necessary
	utzin <= io_ram(ram_pointer+1);

	test_in_path_y <= Path_To_Logic_Vector(utyin);
	test_in_path_z <= Path_To_Logic_Vector(utzin);

	process(clock)
	begin
		if rising_edge(clock) then
			-- CCS PART
			if test_ccs then
				uta <= io_ram(ram_pointer);
				utb <= io_ram(ram_pointer + 1);
				utc <= io_ram(ram_pointer + 2);

				output_ram(ram_pointer)		<= utx;
				output_ram(ram_pointer + 1)	<= uty;
				output_ram(ram_pointer + 2) <= utz;

				test_in_path_a <= Path_To_Logic_Vector(uta);
				test_ccs_output_path <= Path_To_Logic_Vector(utx);
				test_out_path <= Path_To_Logic_Vector(output_ram(12));
				if ram_pointer < number_of_tests then
					ram_pointer <= ram_pointer + 3;
				end if;
				if ram_pointer = number_of_tests and res_written = false then
					--Write_Paths_To_File("tests/output_paths.txt");
					Write_Paths_As_CSV("tests/output_paths.csv");
					res_written <= true;
				end if;
			end if;

			-- CCT PART
			if test_cct and reset = '0' then

				int_command_min1 <= int_command;
				int_command_min2 <= int_command_min1;
				command_sig_min1 <= command_sig;
				command_sig_min2 <= command_sig_min1;

				previous_output <= utyout;

				-- if command_sig = Push then
				-- 	cct_head <= cct_head + 1;
				-- else
				-- 	if command_sig = Pop and cct_head > 0 then
				-- 		cct_head <= cct_head - 1;
				-- 	end if;
				-- end if;

				if command_sig = Push then
					cct_heads(to_integer(unsigned(wid_sig))) <= cct_heads(to_integer(unsigned(wid_sig))) + 1;
				else
					if command_sig = Pop and cct_heads(to_integer(unsigned(wid_sig))) > 0 then
						cct_heads(to_integer(unsigned(wid_sig))) <= cct_heads(to_integer(unsigned(wid_sig))) - 1;
					end if;
				end if;

				if (command_sig_min2 = Pop or command_sig_min2 = Nop) and previous_output_valid = '1' and outram_pointer < number_of_tests then
					output_ram(outram_pointer) <= previous_output;
					outram_pointer <= outram_pointer + 1;
				end if;

				test_out_path <= Path_To_Logic_Vector(utyout);

				if ram_pointer < number_of_tests then
					ram_pointer <= ram_pointer + 2; -- we have to do it every time since the input paths drive everything here
					it_counter <= it_counter + 1; -- not really necessary here
				end if;

				wid_sig <= std_logic_vector( unsigned(wid_sig) + 1 );

				if ram_pointer = number_of_tests and res_written = false then
					--Write_Paths_To_File("tests/output_paths.txt");
					Write_Paths_As_CSV("tests/cct_output_paths.csv");
					res_written <= true;
				end if;
			end if;
		end if;
	end process;

end architecture;
