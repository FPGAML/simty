library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- Warp membership check, convergence detection and individual PC update
-- Manages vector PC register
-- Computes actual nonspeculative write mask
entity Membership is
	port (
		clock : in std_logic;
		reset : in std_logic;
		mpc_in : in code_address;
		wid_in : in warpid;
		insn_in : in decoded_instruction;

		pcs : out code_address_vector;	-- To BU
		alive : out mask;

		valid_mask : out mask;
		leader : out laneid;
		leader_mask : out mask;
		invalid : out std_logic;
		
		nextpcs : in code_address_vector;
		nextwid : in warpid;
		nextalive : in mask;
		nextpcs_invalid : in std_logic
		
		--insn_out : out decoded_instruction;
		--mpc_out : out address;
		--wid_out : out warpid
	);
end entity;

architecture structural of Membership is
	--signal wid_1 : warpid;
	signal pcs_1 : code_address_vector;
	signal mpc_1 : code_address;
	signal wid_1 : warpid;
	signal alive_1 : mask;
	signal valid_mask_1 : mask;
	signal dobypass_0, dobypass_1 : std_logic;
	
	constant recordsize : natural := 32;	-- need multiple of 32 for word enables
	
	signal commit_wordenable : std_logic_vector(warpsize - 1 downto 0);
	signal nextpcs_0 : code_address_vector;
	signal flat_pcs_1, flat_pcs_byp_1 : std_logic_vector(warpsize * recordsize - 1 downto 0);
	signal flat_nextpcs_0, flat_nextpcs_1 : std_logic_vector(warpsize * recordsize - 1 downto 0);
	signal wr_en : std_logic;
begin
	-- Stage 0
	nextpcs_0 <= nextpcs;

	commit_wordenable <= (others => '1');

	flatten : for i in 0 to warpsize - 1 generate
		-- Embed alive metadata in lowest-order bit
		-- Use low logic level for alive: all zero at boot time sets all threads alive
		flat_nextpcs_0((i + 1) * recordsize - 1 downto i * recordsize) <= (recordsize - 1 downto code_address'high+1 => '0') & nextpcs_0(i) & "0" & (not nextalive(i));
	end generate;

	wr_en <= not nextpcs_invalid;
	pc_array : SRAM
		generic map (
			width => warpsize * recordsize,
			logdepth => log_warpcount)
		port map (
			clock => clock,
			reset => reset,
			rd_address => unsigned(wid_in),
			rd_data => flat_pcs_1,
			wr_enable => wr_en,
			wr_address => unsigned(nextwid),
			wr_data => flat_nextpcs_0,
			wr_wordenable => commit_wordenable);

	-- Bypass control on input
	dobypass_0 <= '1' when nextpcs_invalid = '0' and nextwid = wid_in else '0';
	-- Bypass select on output
	flat_pcs_byp_1 <= flat_nextpcs_1 when dobypass_1 = '1' else flat_pcs_1;

	unflatten : for i in 0 to warpsize - 1 generate
		pcs_1(i) <= flat_pcs_byp_1(i * recordsize + code_address'high downto i * recordsize + code_address'low);
		alive_1(i) <= not flat_pcs_byp_1(i * recordsize);
	end generate;
	
	-- Stage 1
	-- Row of comparators to compute valid_mask
	comp_row : for i in 0 to warpsize - 1 generate
		valid_mask_1(i) <= '0' when alive_1(i) = '0' or pcs_1(i) /= mpc_1 else '1';
	end generate;
	valid_mask <= valid_mask_1;
	
	-- Priority encoder to elect leader: find first set
	elect_leader : FFS
		generic map (logw => log_warpsize)
		port map (
			mask => valid_mask_1,
			fs => leader,
			zero => invalid,
			one_hot => leader_mask);

	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				wid_1 <= (others => '0');
				mpc_1 <= DummyPC;
				dobypass_1 <= '0';
			else
				wid_1 <= wid_in;
				mpc_1 <= mpc_in;
				dobypass_1 <= dobypass_0;
				flat_nextpcs_1 <= flat_nextpcs_0;
			end if;
		end if;
	end process;
	--wid_out <= wid_1;
	pcs <= pcs_1;
	alive <= alive_1;
end architecture;
