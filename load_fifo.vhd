library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- Writeback FIFO for returning loads
entity Load_Fifo is
	port (
		clock : in std_logic;
		reset : in std_logic;
		push_full : out std_logic;
		push_valid : in std_logic;
		--push_mpc : in code_address;
		push_wid : in warpid;
		push_data : in vector;
		push_mask : in mask;
		push_rd : in register_id;

		pop_valid : out std_logic;
		pop_wid : out warpid;
		pop_data : out vector;
		pop_mask : out mask;
		pop_rd : out register_id;
		pop_ack : in std_logic
	);
end entity;

-- Single-entry implementation
architecture structural of Load_Fifo is
	signal data_1 : vector;
	signal mask_1 : mask;
	signal wid_1 : warpid;
	signal valid_1 : std_logic;
	signal rd_1 : register_id;
begin

	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				data_1 <= (others => '0');
				mask_1 <= EmptyMask;
				wid_1 <= (others => '0');
				valid_1 <= '0';
				rd_1 <= (others => '0');
			else
				if pop_ack = '1' then
					valid_1 <= '0';
				end if;
				if push_valid = '1' then
					data_1 <= push_data;
					mask_1 <= push_mask;
					wid_1 <= push_wid;
					rd_1 <= push_rd;
					valid_1 <= '1';
				end if;
			end if;
		end if;
	end process;
	pop_valid <= valid_1;
	pop_wid <= wid_1;
	pop_data <= data_1;
	pop_mask <= mask_1;
	pop_rd <= rd_1;
	push_full <= valid_1 and not pop_ack;
end architecture;
