library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- Memory gather: receiver side of memory coalescing logic
entity Gather is
	port (
		clock : in std_logic;
		reset : in std_logic;
		wid_in : in warpid;
		insn_in : in decoded_instruction;

		address : in block_address;
		data_block : in vector;
		valid_mask : in mask;
		leader_offset : in std_logic_vector(log_blocksize - 1 downto 0);
		broadcast_mask : in mask;
		valid_in : std_logic;

		memwriteback : out vector;
		memwriteback_valid : out std_logic;
		memwriteback_mask : out mask;

		insn_out : out decoded_instruction;
		wid_out : out warpid
	);
end entity;

architecture structural of Gather is
	signal broadcast_word : scalar;
	signal leader_offset_word_int : integer;
	signal memwriteback_0 : vector;
begin
	-- Access offset within cache block
	leader_offset_word_int <= to_integer(unsigned(leader_offset(log_blocksize - 1 downto 2)));
	broadcast_word <= data_block((leader_offset_word_int + 1) * 32 - 1 downto leader_offset_word_int * 32);
	
	-- TODO: Shift/mux broadcast word for sub-word access

	data_mux: for i in 0 to warpsize - 1 generate
		memwriteback_0((i+1)*32-1 downto i*32) <=
			broadcast_word when broadcast_mask(i) = '1' else
			data_block((i+1)*32-1 downto i*32);
	end generate;

	process(clock) is
	begin
		if rising_edge(clock) then
			if reset = '1' then
				insn_out <= NopDec;
				memwriteback <= (others => '0');
				memwriteback_valid <= '0';
				wid_out <= (others => '0');
				memwriteback_mask <= (others => '0');
			else
				insn_out <= insn_in;
				memwriteback <= memwriteback_0;
				memwriteback_valid <= valid_in;
				wid_out <= wid_in;
				memwriteback_mask <= valid_mask;
			end if;
		end if;
	end process;
end architecture;
