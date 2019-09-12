library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- Instruction Fetch
entity Fetch is
	port (
		clock : in std_logic;
		reset : in std_logic;
		mpc_in : in code_address;
		mpc_valid_in : in std_logic;
		wid_in : in warpid;
		iw : out instruction_word;
		valid : out std_logic;
		mpc_out : out code_address;
		wid_out : out warpid;

		-- NMPC bypass logic
		nmpc_valid : in std_logic;
		nmpc_wid : in warpid;
		ignorepath : out std_logic;

		-- Interface to Imem/Icache
		--icache_request_address : out code_address;
		--icache_request_valid : out std_logic;
		--icache_request_wid : out warpid;
		--icache_response_data : in instruction_word;
		--icache_response_valid : in std_logic;
		--icache_response_wid : in warpid
		icache_req : out ICache_Request;
		icache_resp : in ICache_Response
	);
end entity;

architecture structural of Fetch is
	--signal iw_read : instruction_word;
	signal iw_valid : std_logic;
	signal ignorepath_0 : std_logic;
begin
	-- Placeholder implementation: test a few instructions
--	with to_integer(unsigned(mpc_in)) select iw_read <=
--		X"f0000" & "00010" & "0110111" when 16#80#,							-- lui x2, 0xf0000000
--		X"ff0" & "00010" & "000" & "00010" & "0010011" when 16#81#,			-- addi x2, x2, 0xff0
--		X"f10" & "00000" & "010" & "00011" & "1110011" when 16#82#,			-- rdhartid x3
--		X"002" & "00011" & "001" & "00011" & "0010011" when 16#83#,			-- slli x3, x3, 2
--		"0000000" & "00010" & "00011" & "010" & "00000" & "0100011" when 16#84#, -- sw x3, x2, 0
--		X"000" & "00011" & "010" & "00100" & "0000011" when 16#85#,				-- lw x4, x3, 0
--		"0000000" & "00011" & "00010" & "000" & "00010" & "0110011" when 16#86#,	-- add x2, x2, x3
--		"1111111" & "00010" & "00010" & "101" & "10101" & "1100011" when 16#87#,	-- bge x2, x2, -12
--		X"0000_0000" when others;
--	iw_valid <= '1';
	icache_req.valid <= mpc_valid_in;
	icache_req.wid <= wid_in;
	icache_req.address <= mpc_in;
	ignorepath_0 <= '1' when nmpc_valid = '1' and nmpc_wid = wid_in else '0';
	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
--				iw <= (others => '0');
--				valid <= '0';
--				mpc_out <= DummyPC;
--				wid_out <= (others => '0');
				ignorepath <= '0';
			else
--				iw <= iw_read;
--				valid <= mpc_valid_in and iw_valid;
--				mpc_out <= mpc_in;
--				wid_out <= wid_in;
				ignorepath <= ignorepath_0;
			end if;
		end if;
	end process;

	--iw_read <= icache_resp.data;
	iw <= icache_resp.data;
	valid <= icache_resp.valid;
	mpc_out <= icache_resp.address;
	wid_out <= icache_resp.wid;
end architecture;
