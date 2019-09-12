library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

entity Simty_Test is
end entity;

architecture behavioral of Simty_Test is
	signal clock : std_logic := '0';
	signal reset : std_logic := '1';
	signal mmio_in, mmio_out : std_logic_vector(31 downto 0);
	signal pu_request : Bus_Request;
	signal pu_response : Bus_Response;
	signal i_request : ICache_Request;
	signal i_response : ICache_Response;
	constant test_gfxmem : boolean := true;
	constant use_inst_mem : boolean := true;
begin
	clock <=  '1' after 0.5 ns when clock = '0' else
        '0' after 0.5 ns when clock = '1';

    reset <= '0' after 2 ns;
    mmio_in <= (others => '0');
    my_simty : Simty
    	port map(
			clock => clock,
    		reset => reset,
    		pu_request => pu_request,
    		pu_response => pu_response,
--			i_request => i_request,
--			i_response => i_response,
--			i_request => icache_req_1,
--			i_response => icache_resp_2,
			icache_req_1 => i_request,
			icache_resp_2 => i_response,
    		mmio_in => mmio_in,
    		mmio_out => mmio_out);

	mem_sp : if not test_gfxmem generate
		-- Data Memory
		sp : Scratchpad
			port map (
				clock => clock,
				reset => reset,
				request => pu_request,
				response => pu_response
			);
	end generate;

	mem_gfx : if test_gfxmem generate
		gfxmem : Graphics_Memory
			port map (
				pu_clock => clock,
				reset => reset,
				pu_request => pu_request,
				pu_response => pu_response,
				vga_clock => '0',
				vga_addr => (others => '0'),
				vga_out => open
			);
	end generate;

	mem_instr : if use_inst_mem generate
		instmem : Instruction_Memory
			port map (
				clock,
				reset,
				i_request,
				i_response
			);
	end generate;

end architecture;
