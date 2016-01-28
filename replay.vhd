library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- NPCs late mux
entity Replay is
	port (
		--clock : in std_logic;
		--reset : in std_logic;
		--mpc_in : in code_address;
		wid_in : in warpid;
		--insn_in : in decoded_instruction;
		--fallthroughpc : in code_address;
		pcs : in code_address_vector;
		nextpcs_in : in code_address_vector;
		replay_mask : in mask;	-- From MA
		--valid_mask : in mask;
		nextpcs_out : out code_address_vector;	-- To MSHP
		
		
		--insn_out : out decoded_instruction;
		--mpc_out : out address;
		wid_out : out warpid
	);
end entity;

architecture structural of Replay is
begin
	npc_mux: for i in 0 to warpsize - 1 generate
		nextpcs_out(i) <=
						nextpcs_in(i) when replay_mask(i) = '0' else
			pcs(i);
	end generate;
	wid_out <= wid_in;
end architecture;
