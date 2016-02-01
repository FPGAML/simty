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
	signal broadcast_word_raw, broadcast_word_mux0, broadcast_word : scalar;
	signal leader_offset_word_int : integer;
	signal memwriteback_0 : vector;
	signal sign_extend : std_logic;
begin
	-- Access offset within cache block
	leader_offset_word_int <= to_integer(unsigned(leader_offset(log_blocksize - 1 downto 2)));
	broadcast_word_raw <= data_block((leader_offset_word_int + 1) * 32 - 1 downto leader_offset_word_int * 32);
	
	-- Shift/mux broadcast word for sub-word access
	sign_extend <= insn_in.mem_size(2);
	broadcast_word_mux0(15 downto 0) <= broadcast_word_raw(31 downto 16) when leader_offset(1) = '1' else
	                                    broadcast_word_raw(15 downto 0);
	--broadcast_word_mux0(31 downto 15) <= (others => broadcast_word_raw(15) and sign_extend) when leader_offset(1) = '1' else
	--                                     broadcast_word_raw(31 downto 15);
	
	broadcast_word(7 downto 0) <= broadcast_word_mux0(15 downto 8) when leader_offset(0) = '1' else
	                              broadcast_word_mux0(7 downto 0);
	-- Sign- or Zero-extend on sub-word access
	broadcast_word(15 downto 8) <= (others => broadcast_word(7) and sign_extend) when insn_in.mem_size(1 downto 0) = "00" else
	                               broadcast_word_mux0(15 downto 8);
	broadcast_word(31 downto 16) <= (others => broadcast_word_mux0(15) and sign_extend) when insn_in.mem_size(1 downto 0) = "01" else
	                                (others => broadcast_word(7) and sign_extend) when insn_in.mem_size(1 downto 0) = "00" else
	                                broadcast_word_raw(31 downto 16);

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
