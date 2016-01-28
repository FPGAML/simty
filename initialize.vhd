library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

entity Initialize is
	port (
		clock : in std_logic;
		reset : in std_logic;
		init : out std_logic;

		nextpcs : out code_address_vector;
		alive_mask : out mask;
		nextwid : out warpid;
		
		nmpc : out code_address;
		nmpc_wid : out warpid;
		nmpc_alive : out std_logic
	);
end entity;

architecture structural of Initialize is
	signal widctr : unsigned(log_warpcount downto 0);
	signal nextwidctr : unsigned(log_warpcount downto 0);
	signal wid : warpid;
	signal initphase : std_logic;
begin
	nextwidctr <= widctr + 1;
	initphase <= '0' when widctr(log_warpcount) = '1' else '1';
	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				widctr <= (others => '0');
			else
				if initphase = '1' then
					widctr <= nextwidctr;
				end if;
			end if;
		end if;
	end process;
	init <= initphase;
	nextpcs <= (others => StartPC);
	alive_mask <= (others => '1');
	wid <= std_logic_vector(widctr(log_warpcount - 1 downto 0));
	
	nextwid <= wid;
	nmpc <= StartPC;
	nmpc_wid <= wid;
	nmpc_alive <= '1';
end architecture;
