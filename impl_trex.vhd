library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;
use work.pkg_vga_out.all;

entity Impl_TREX is
	port (
		OSC_50 : in std_logic;
		o_COM : out std_logic_vector(3 downto 0);
		o_SEG7 : out std_logic_vector(7 downto 0);
		key : in std_logic_vector(7 downto 0);
		oLED : out std_logic_vector(7 downto 0);
		vga_r : out std_logic_vector(3 downto 0);
		vga_g : out std_logic_vector(3 downto 0);
		vga_b : out std_logic_vector(3 downto 0);
		hsyncn : out std_logic;
		vsyncn : out std_logic;
		tr_tvres : out std_logic
	);
end entity;

architecture structural of Impl_TREX is
	signal clock, vga_clock : std_logic;
	signal reset, reset_l : std_logic;
	signal mmio_in, mmio_out : std_logic_vector(31 downto 0);
	signal pu_request : Bus_Request;
	signal pu_response : Bus_Response;

	signal vga_locked : std_logic;

	signal vga_pixel_cnt : std_logic_vector(10 downto 0);
	signal vga_line_cnt  : std_logic_vector(10 downto 0);
	signal vga_blank_l_g : std_logic;
	signal vga_hsync_g   : std_logic;
	signal vga_vsync_g   : std_logic;

	signal vga_addr : std_logic_vector(16 downto 0);
	signal vga_dout  : std_logic_vector(7 downto 0);
begin
	clock <= OSC_50;
	reset <= not key(7);
	reset_l <= key(7);
	tr_tvres <= '1';	-- Don't mess with the TV encoder
	
	mmio_in(6 downto 0) <= key(6 downto 0);
	mmio_in(31 downto 7) <= (others => '0');
	oLED <= mmio_out(31 downto 24);
	o_SEG7 <= mmio_out(15 downto 8);
	o_COM <= mmio_out(19 downto 16);
	my_simty : Simty
	port map(clock => clock,
    		reset => reset,
    		pu_request => pu_request,
    		pu_response => pu_response,
    		mmio_in => mmio_in,
    		mmio_out => mmio_out);

	sp_gen : if false generate
	-- Data Memory
	sp : Scratchpad
		port map (
			clock => clock,
			reset => reset,
			request => pu_request,
			response => pu_response
		);
	end generate;
	
	gfxmem : Graphics_Memory
		port map (
			pu_clock => clock,
			reset => reset,
			pu_request => pu_request,
			pu_response => pu_response,
			vga_clock => vga_clock,
			vga_addr => vga_addr(15 downto 0),
			vga_out => vga_dout
		);

  vga_timing_gen_0 : vga_timing_gen
    generic map ( res_x => 640,
                  res_y => 480,
                  freq  => 60 )
    port map ( system_clk => clock,
               rst_l      => reset_l,
               clk        => vga_clock,
               pixel_cnt  => vga_pixel_cnt,
               line_cnt   => vga_line_cnt,
               blank_l    => vga_blank_l_g,
               hsync      => vga_hsync_g,
               vsync      => vga_vsync_g,
               locked     => vga_locked );

  vga_out_0 : vga_out
    port map ( clk => vga_clock,
               rst => reset,

               ram_addr => vga_addr,
               ram_dout => vga_dout,

               pixel_cnt => vga_pixel_cnt,
               line_cnt  => vga_line_cnt,
               blank_l_g => vga_blank_l_g,
               hsync_g   => vga_hsync_g,
               vsync_g   => vga_vsync_g,

               red(7 downto 4) => vga_r,
               blue(7 downto 4) => vga_b,
               green(7 downto 4) => vga_g,
               pixel_clk => open,
               blank_l   => open,
               sync_l    => open,
               hsync     => hsyncn,	-- negated??
               vsync     => vsyncn );
end architecture;
