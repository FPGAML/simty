library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;
use work.pkg_vga_out.all;

entity Impl_DE2 is
	port (
		CLOCK_50 : in std_logic;
		HEX0 : out std_logic_vector(6 downto 0);
		HEX1 : out std_logic_vector(6 downto 0);
		HEX2 : out std_logic_vector(6 downto 0);
		HEX3 : out std_logic_vector(6 downto 0);
		HEX4 : out std_logic_vector(6 downto 0);
		HEX5 : out std_logic_vector(6 downto 0);
		HEX6 : out std_logic_vector(6 downto 0);
		HEX7 : out std_logic_vector(6 downto 0);
		KEY : in std_logic_vector(3 downto 0);
		LEDG : out std_logic_vector(8 downto 0);
		LEDR : out std_logic_vector(17 downto 0);
		VGA_B : out std_logic_vector(7 downto 0);
		VGA_G : out std_logic_vector(7 downto 0);
		VGA_R : out std_logic_vector(7 downto 0);
		VGA_CLK : out std_logic;
		VGA_BLANK_N : out std_logic;
		VGA_SYNC_N : out std_logic;
		VGA_HS : out std_logic;
		VGA_VS : out std_logic
	);
end entity;

architecture structural of Impl_DE2 is
	component Seg7_Decoder is
		port (
			digit : in std_logic_vector(3 downto 0);
			seg : out std_logic_vector(6 downto 0)
		);
	end component;

	
	signal clock, vga_clock : std_logic;
	signal reset, reset_l : std_logic;
	signal mmio_in, mmio_out : std_logic_vector(31 downto 0);
	signal digits : std_logic_vector(31 downto 0);
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
	clock <= CLOCK_50;
	reset <= not key(0);
	reset_l <= key(0);
	
	mmio_in(2 downto 0) <= key(3 downto 1);
	mmio_in(31 downto 3) <= (others => '0');
	LEDG <= mmio_out(13 downto 5);
	LEDR <= mmio_out(31 downto 14);
	digits <= mmio_out;
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

               red => vga_r,
               blue => vga_b,
               green => vga_g,
               pixel_clk => vga_clk,
               blank_l   => vga_blank_n,
               sync_l    => vga_sync_n,
               hsync     => vga_hs,
               vsync     => vga_vs
             );

	digit0 : Seg7_Decoder port map (digit => digits(3 downto 0), seg => HEX0);
	digit1 : Seg7_Decoder port map (digit => digits(7 downto 4), seg => HEX1);
	digit2 : Seg7_Decoder port map (digit => digits(11 downto 8), seg => HEX2);
	digit3 : Seg7_Decoder port map (digit => digits(15 downto 12), seg => HEX3);
	digit4 : Seg7_Decoder port map (digit => digits(19 downto 16), seg => HEX4);
	digit5 : Seg7_Decoder port map (digit => digits(23 downto 20), seg => HEX5);
	digit6 : Seg7_Decoder port map (digit => digits(27 downto 24), seg => HEX6);
	digit7 : Seg7_Decoder port map (digit => digits(31 downto 28), seg => HEX7);
			
end architecture;

-- 7-segment

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Seg7_Decoder is
	port (
		digit : in std_logic_vector(3 downto 0);
		seg : out std_logic_vector(6 downto 0)
	);
end entity;

architecture structural of Seg7_Decoder is
	signal seg_trex : std_logic_vector(7 downto 0);
begin
	-- Decoder for TREX-C1 board
	with digit select
		seg_trex <=
				B"10010000" when X"0",
				B"10011111" when X"1",
				B"01011000" when X"2",
				B"00011001" when X"3",
				B"00010111" when X"4",
				B"00110001" when X"5",
				B"00110000" when X"6",
				B"10011101" when X"7",
				B"00010000" when X"8",
				B"00010001" when X"9",
				B"00010100" when X"A",
				B"00110010" when X"B",
				B"11110000" when X"C",
				B"00011010" when X"D",
				B"01110000" when X"E",
				B"01110100" when X"F";
	-- Remap to DE-2 encoding: too lazy to shuffle truth table
	seg(0) <= seg_trex(1);
	seg(2 downto 1) <= seg_trex(6 downto 5);
	seg(3) <= seg_trex(2);
	seg(4) <= seg_trex(0);
	seg(5) <= seg_trex(3);
	seg(6) <= seg_trex(7);
end architecture;
