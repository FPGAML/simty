library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

entity Crossbar is
	generic (
		log_win : natural;
		log_wout : natural;
		w : natural
	);
	port (
		-- Flat input/output
		--data_in : in std_logic_matrix(0 to 2**log_win-1)(w-1 downto 0);
		--data_out : out std_logic_matrix(0 to 2**log_wout-1)(w-1 downto 0);
		data_in : in std_logic_vector(w * 2**log_win - 1 downto 0);
		data_out : out std_logic_vector(w * 2**log_wout - 1 downto 0);
		--control : in std_logic_matrix(0 to 2**log_wout-1)(log_win-1 downto 0)
		control : in std_logic_vector(log_win * 2**log_wout - 1 downto 0)
	);
end entity;

architecture structural of Crossbar is
	type row is array(0 to 2**log_win-1) of std_logic_vector(w - 1 downto 0);
	--signal data_unpacked : std_logic_matrix(0 to 2**log_wout-1)(w - 1 downto 0);
	signal data_unpacked : row;
begin
	unpack : for i in 0 to 2**log_win - 1 generate
		data_unpacked(i) <= data_in((i + 1) * w - 1 downto i * w);
	end generate;
	
	muxes: for i in 0 to 2**log_wout - 1 generate
		data_out((i + 1) * w - 1 downto i * w) <= data_unpacked(to_integer(unsigned(control((i + 1) * log_win - 1 downto i * log_win))));
	end generate;
end architecture;

----------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

entity Backward_Crossbar is
	generic (
		log_win : natural;
		log_wout : natural;
		w : natural
	);
	port (
		data_in : in std_logic_vector(w * 2**log_win - 1 downto 0);
		data_out : out std_logic_vector(w * 2**log_wout - 1 downto 0);
		--control : in std_logic_matrix(0 to 2**log_wout-1)(log_win-1 downto 0)
		control : in std_logic_vector(log_win * 2**log_wout - 1 downto 0)
	);
end entity;

architecture structural of Backward_Crossbar is
	type row is array(0 to 2**log_wout-1) of std_logic_vector(w - 1 downto 0);
	--signal data_unpacked : std_logic_matrix(0 to 2**log_wout-1)(w - 1 downto 0);
	signal data_unpacked : row;
begin

	muxes: for i in 0 to 2**log_win - 1 generate
		-- does this work??
	--	data_unpacked(to_integer(unsigned(control(i)))) <= data_in((i + 1) * w - 1 downto i * w);
		-- No it doesn't. What did you expect?
		data_unpacked(i) <= data_in((i + 1) * w - 1 downto i * w); -- TODO
	end generate;

	pack : for i in 0 to 2**log_wout - 1 generate
		data_out((i + 1) * w - 1 downto i * w) <= data_unpacked(i);
	end generate;
end architecture;
