library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- 1 read/write port
entity Cold_Context_Table is
	port (
		clock : in std_logic;
		reset : in std_logic;
		wid : in warpid;
		command : in CCT_Command;
		y_in : in Path;
		z_in : in Path;
		y_out : out Path;
		wid_out : out warpid;
		y_writeback : out std_logic	-- May writeback even if y_out.valid is false
	);
end entity;

architecture structural of Cold_Context_Table is
	-- warpsize * warpcount contexts width warpsize+pcsize+1
	-- warpcount heads width log(warpsize)
	constant entry_width : integer := calldepth_width + warpsize + code_address'length + 1;
	subtype cct_entry is std_logic_vector(entry_width - 1 downto 0);
	type cct_ram is array(0 to warpcount * warpsize - 1) of cct_entry;
	subtype cct_ptr is unsigned(log_warpsize - 1 downto 0);
	constant null_ptr : cct_ptr := (others => '0');
	type pointer_vector is array(0 to warpcount - 1) of cct_ptr;
	signal head : pointer_vector;
	signal cct : cct_ram;
	attribute ramstyle : string;
	attribute ramstyle of cct : signal is "no_rw_check";
	signal idle, idle_1 : std_logic;
	type sorter_state is (ResetHead, Probe); --, Swap);
	type sorter_state_vector is array (0 to warpcount - 1) of sorter_state;
	signal state : sorter_state_vector;
	signal sort_ptr : pointer_vector;
	signal cct_read_address_sig, cct_write_address_sig : unsigned(log_warpcount + log_warpsize - 1 downto 0);
	signal cct_output : cct_entry;
	signal y_1, y_in_1 : Path;
	signal match_found_2 : std_logic_vector(warpcount - 1 downto 0);
	signal wid_1 : warpid;
	signal y_changed_1 : std_logic;

	signal current_ptr_sig : cct_ptr;

	-- debugging type
	subtype path_as_logic_vector is std_logic_vector(log_codesize + warpsize + calldepth_width - 2 downto 0); -- size 43

	-- debugging signals
	-- signal command_sig_cct, state_sig : integer;
	-- signal head0, head7 : cct_ptr;
	-- signal entry0, entry1, entry2, entry3, entry4, entry5, entry6,
	-- entry7, entry8, entry9, entry10, entry11, entry12, entry13, entry14,
	-- entry15, entry16, entry17, entry18, entry19, entry20, entry21, entry22,
	-- entry23, entry24, entry25, entry26, entry27, entry28, entry29, entry30, entry31, entry32 : path_as_logic_vector;


	-- debugging functions
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
	-- end of debugging functions


	function Pack(c : Path) return cct_entry is
		variable e : cct_entry;
	begin
		e(warpsize - 1 downto 0) := c.vmask;
		e(warpsize) := c.valid;
		e(warpsize + code_address'length downto warpsize + 1) := c.mpc;
		e(warpsize + code_address'length + calldepth_width downto warpsize + code_address'length + 1) := c.calldepth;
		return e;
	end function;

	function Unpack(e : cct_entry) return Path is
	begin
		return (vmask => e(warpsize - 1 downto 0),
				valid => e(warpsize),
				mpc => e(warpsize + code_address'length downto warpsize + 1),
				calldepth => e(warpsize + code_address'length + calldepth_width downto warpsize + code_address'length + 1));
	end function;
begin
	idle <= '1' when command = Nop or (command = Pop and head(to_integer(unsigned(wid))) = null_ptr) else '0';
	y_1 <= Unpack(cct_output);


	-- debugging code
	-- command_sig_cct <= 1 when command = Push else 2 when command = Pop else 3 when command = Nop else 4;
	-- state_sig <= 1 when state(to_integer(unsigned(wid))) = ResetHead else 2 when state(to_integer(unsigned(wid))) = Probe else 3;
	-- head0 <= head(0);
	-- head7 <= head(7);
	-- entry0 <= Path_To_Logic_Vector(Unpack(cct(0)));
	-- entry1 <= Path_To_Logic_Vector(Unpack(cct(1)));
	-- entry2 <= Path_To_Logic_Vector(Unpack(cct(2)));
	-- entry3 <= Path_To_Logic_Vector(Unpack(cct(3)));
	-- entry4 <= Path_To_Logic_Vector(Unpack(cct(4)));
	-- entry5 <= Path_To_Logic_Vector(Unpack(cct(5)));
	-- entry6 <= Path_To_Logic_Vector(Unpack(cct(6)));
	-- entry7 <= Path_To_Logic_Vector(Unpack(cct(7)));
	-- entry8 <= Path_To_Logic_Vector(Unpack(cct(8)));
	-- entry9 <= Path_To_Logic_Vector(Unpack(cct(9)));
	-- entry10 <= Path_To_Logic_Vector(Unpack(cct(10)));
	-- entry11 <= Path_To_Logic_Vector(Unpack(cct(11)));
	-- entry12 <= Path_To_Logic_Vector(Unpack(cct(12)));
	-- entry13 <= Path_To_Logic_Vector(Unpack(cct(13)));
	-- entry14 <= Path_To_Logic_Vector(Unpack(cct(14)));
	-- entry15 <= Path_To_Logic_Vector(Unpack(cct(15)));
	-- entry16 <= Path_To_Logic_Vector(Unpack(cct(16)));
	-- entry17 <= Path_To_Logic_Vector(Unpack(cct(17)));
	-- entry18 <= Path_To_Logic_Vector(Unpack(cct(18)));
	-- entry19 <= Path_To_Logic_Vector(Unpack(cct(19)));
	-- entry20 <= Path_To_Logic_Vector(Unpack(cct(20)));
	-- entry21 <= Path_To_Logic_Vector(Unpack(cct(21)));
	-- entry22 <= Path_To_Logic_Vector(Unpack(cct(22)));
	-- entry23 <= Path_To_Logic_Vector(Unpack(cct(23)));
	-- entry24 <= Path_To_Logic_Vector(Unpack(cct(24)));
	-- entry25 <= Path_To_Logic_Vector(Unpack(cct(25)));
	-- entry26 <= Path_To_Logic_Vector(Unpack(cct(26)));
	-- entry27 <= Path_To_Logic_Vector(Unpack(cct(27)));
	-- entry28 <= Path_To_Logic_Vector(Unpack(cct(28)));
	-- entry29 <= Path_To_Logic_Vector(Unpack(cct(29)));
	-- entry30 <= Path_To_Logic_Vector(Unpack(cct(30)));
	-- entry31 <= Path_To_Logic_Vector(Unpack(cct(31)));



	-- Stage 0->1
	-- Nop: sort, optionally swap y
	-- Pop: read entry at head[wid]-1 unless head=0
	--  dec head
	--  Possible optimization if empty
	-- Push: write entry at head[wid]
	--  inc head
	-- Reset: initialize heads
	process(clock)
		variable wid_int : integer;
		variable my_head : cct_ptr;
		variable cct_write_address : unsigned(log_warpcount + log_warpsize - 1 downto 0) := (others => '0');
		variable cct_read_address : unsigned(log_warpcount + log_warpsize - 1 downto 0) := (others => '0');
		variable current_ptr : cct_ptr := null_ptr;
		variable current_entry : Path;
	begin
		if rising_edge(clock) then
			wid_1 <= wid;	-- Always the same warp: no y_in for other warps
			y_in_1 <= y_in;
			idle_1 <= idle;
			if reset = '1' then
				for i in 0 to warpcount - 1 loop
					head(i) <= null_ptr;
				end loop;
				state <= (others => ResetHead);
				--cct_read_address <= (others => '0');
			else
				wid_int := to_integer(unsigned(wid));
				my_head := head(wid_int);
				if idle = '0' then
					case command is
						when Pop =>
							my_head := my_head - to_unsigned(1, log_warpsize);
							cct_read_address := unsigned(wid) & my_head;
							head(wid_int) <= my_head;
							y_changed_1 <= '1';
							if current_ptr >= my_head then
								state(wid_int) <= ResetHead;
							end if;
						when Push =>
							-- Assumes the CCT never overflows
							-- Write z first
							cct_write_address := unsigned(wid) & my_head;
							-- Flatten
							cct(to_integer(cct_write_address)) <= Pack(z_in);
							-- Increment next
							my_head := my_head + to_unsigned(1, log_warpsize);
							head(wid_int) <= my_head;
							y_changed_1 <= '0';
						when others =>
							null;
					end case;
				else	-- idle = '1'
					-- CCT sideband sorter state machine
					case state(wid_int) is
						when ResetHead =>
							-- Not strictly necessary state, makes initialization and control logic easier
							current_ptr := head(wid_int) - to_unsigned(1, log_warpsize);
							sort_ptr(wid_int) <= current_ptr;
							cct_read_address := unsigned(wid) & current_ptr;
							y_changed_1 <= '0';
							if current_ptr /= null_ptr then
								state(wid_int) <= Probe;
							end if;
						when Probe =>
							-- TODO: only 1 state? Certainly buggy timing
							-- Decrement pointer
							current_ptr := sort_ptr(wid_int);
							if match_found_2(wid_int) = '1' then
								-- Match found in previous step
								-- Now keep the same address and swap
								cct_write_address := unsigned(wid) & current_ptr;
								cct_read_address := cct_write_address;
								cct(to_integer(cct_write_address)) <= Pack(y_in);
								y_changed_1 <= '1';

								state(wid_int) <= ResetHead;
							elsif current_ptr = null_ptr then
								-- Reached bottom of stack
								state(wid_int) <= ResetHead;
								y_changed_1 <= '0';
							else
								-- No match, move on to next cell
								current_ptr := current_ptr - to_unsigned(1, log_warpsize);
								sort_ptr(wid_int) <= current_ptr;
								cct_read_address := unsigned(wid) & current_ptr;
								y_changed_1 <= '0';
							end if;
					end case;
				end if;
				cct_output <= cct(to_integer(cct_read_address));
				cct_read_address_sig <= cct_read_address;
				cct_write_address_sig <= cct_write_address;
				current_ptr_sig <= current_ptr;
			end if;

		end if;
	end process;

	-- Passthrough y if not coming from CCT
	with y_changed_1 select
		y_out <= y_1 when '1',
		         y_in_1 when others;

	wid_out <= wid_1;
	y_writeback <= '1';	-- Passthrough at initialization stage

	-- Stage 1->2
	process(clock)
		variable wid_int : integer;
	begin
		if rising_edge(clock) then
			if reset = '1' then
				match_found_2 <= (others => '0');
			else
				wid_int := to_integer(unsigned(wid_1));
				if idle_1 = '1' then
					-- Compare CCT output with HCT y
					if y_in_1.valid = '1' and y_1.valid = '1' and head(wid_int)(log_warpsize - 1 downto 0) > current_ptr_sig -- null_ptr
						and (y_1.calldepth > y_in_1.calldepth or y_1.mpc < y_in_1.mpc) then
						match_found_2(wid_int) <= '1';
					else
						match_found_2(wid_int) <= '0';
					end if;
				else
					-- abort: head pointer and value may have changed
					match_found_2(wid_int) <= '0';
				end if;
			end if;
		end if;
	end process;

end architecture;
