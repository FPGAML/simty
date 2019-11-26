library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

entity Simty_Output_Test is
end entity;

architecture behavioral of Simty_Output_Test is
	signal clock : std_logic := '0';
	signal reset : std_logic := '1';
	signal mmio_in, mmio_out : std_logic_vector(31 downto 0);
	signal simty_request : Bus_Request; -- request from Simty to Bus_Arbiter
	signal simty_response : Bus_Response; -- response from Bus_Arbiter to Simty

	-- request signals from arbiter to memories
	signal sig_vga_request : Bus_Request;
	signal sig_io_request : Bus_Request;
	signal sig_scratch_request : Bus_Request;

	-- response signals from memories to arbiter
	signal sig_vga_response : Bus_Response;
	signal sig_io_response : Bus_Response;
	signal sig_scratch_response : Bus_Response;

	signal i_request : ICache_Request;
	signal i_response : ICache_Response;
--	constant test_gfxmem : boolean := true;
	constant use_vga_mem : boolean := true;
	constant use_scratchpad : boolean := true;
	constant use_inst_mem : boolean := true;
	constant use_testio_mem : boolean := true;
	constant use_arbiter : boolean := true;
	constant use_unit_tester : boolean := false;
begin
	clock <=  '1' after 0.5 ns when clock = '0' else
        '0' after 0.5 ns when clock = '1';

    reset <= '0' after 2 ns;
    mmio_in <= (others => '0');

	-- entity ports on the left side, signals on the right side
    my_simty : Simty
    	port map(
			clock => clock,
    		reset => reset,
    		pu_request => simty_request,
    		pu_response => simty_response,
			icache_req_1 => i_request,
			icache_resp_2 => i_response,
    		mmio_in => mmio_in,
    		mmio_out => mmio_out);

	mem_sp : if use_scratchpad generate
		-- Data Memory
		sp : Scratchpad
			port map (
				clock => clock,
				reset => reset,
				request => sig_scratch_request,
				response => sig_scratch_response
			);
	end generate;

	mem_vga : if use_vga_mem generate
		m_vga : Graphics_Memory
			port map (
				pu_clock => clock,
				reset => reset,
				pu_request => sig_vga_request,
				pu_response => sig_vga_response,
				vga_clock => '0',
				vga_addr => (others => '0'),
				vga_out => open
			);
	end generate;

	mem_testio : if use_testio_mem generate
		t_io : Testio
			port map (
				clock => clock,
				reset => reset,
				request => sig_io_request,
				response => sig_io_response
			);
	end generate;

	mem_instr : if use_inst_mem generate
		instmem : Instruction_Memory
			port map (
				clock => clock,
				reset => reset,
				request => i_request,
				response => i_response
			);
	end generate;

	bus_arb: if use_arbiter generate
		bus_arb : Bus_Arbiter
			port map (
				clock				=> clock,
				reset				=> reset,
				request				=> simty_request,
				response			=> simty_response,
				vga_request			=> sig_vga_request,
				vga_response		=> sig_vga_response,
				testio_request		=> sig_io_request,
				testio_response		=> sig_io_response,
				scratchpad_request	=> sig_scratch_request,
				scratchpad_response	=> sig_scratch_response
			);
	end generate;

	unit_tester_comp: if use_unit_tester generate
		u_tester : Unit_Tester
			port map (
				clock	=> clock,
				reset	=> reset
			);
	end generate;

end architecture;
