-------------------------------------------------------------------------------
-- From Jeremie Detrey, TutoRISC
-- Adapted for Altera DE-2 with 50MHz clock
--
-- Package for VGA output components
--
-- Types:
--   - timing : record for VGA timing settings
--
-- Functions:
--   - find_timing : looks up the VGA timing settings corresponding to given
--                   resolution and frequency
--
-- Components:
--   - vga_timing_gen : generates the correct timing and sync signals for given
--                      resolution and frequency
--   - vga_out        : displays the image stored in the RAM
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package pkg_vga_out is

  -----------------------------------------------------------------------------
  -- Record for VGA timing settings
  --
  -- Attributes:
  --   - res_x   [positive] : X resolution
  --   - res_y   [positive] : Y resolution
  --   - freq    [positive] : frequency (Hz)
  --   - dcm_m   [positive] : DCM multiplier for pixel clock generation
  --   - dcm_d   [positive] : DCM divider for pixel clock generation
  --   - h_fp    [positive] : pixels for horizontal front porch
  --   - h_sync  [positive] : pixels for horizontal sync
  --   - h_bp    [positive] : pixels for horizontal back porch
  --   - h_total [positive] : total pixels for one line
  --                          h_total = res_x + h_fp + h_sync + h_bp
  --   - v_fp    [positive] : lines for vertical front porch
  --   - v_sync  [positive] : lines for vertical sync
  --   - v_bp    [positive] : lines for vertical back porch
  --   - v_total [positive] : total lines for one frame
  --                          v_total = res_y + v_fp + v_sync + v_bp
  -----------------------------------------------------------------------------

  type timing is
  record
    res_x   : positive;
    res_y   : positive;
    freq    : positive;
    dcm_m   : positive;
    dcm_d   : positive;
    h_fp    : positive;
    h_sync  : positive;
    h_bp    : positive;
    h_total : positive;
    v_fp    : positive;
    v_sync  : positive;
    v_bp    : positive;
    v_total : positive;
  end record;

  -----------------------------------------------------------------------------
  -- Looks up the VGA timing settings corresponding to given resolution and
  -- frequency
  -----------------------------------------------------------------------------
  
  function find_timing ( res_x : positive;
                         res_y : positive;
                         freq  : positive ) return timing;

  -----------------------------------------------------------------------------
  -- Generates the correct timing and sync signals for given resolution and
  -- frequency
  -----------------------------------------------------------------------------
  
  component vga_timing_gen is
    generic ( res_x : positive := 640;
              res_y : positive := 480;
              freq  : positive := 60 );
    port ( system_clk : in  std_logic;
           rst_l      : in  std_logic;
           clk        : out std_logic;
           pixel_cnt  : out std_logic_vector(10 downto 0);
           line_cnt   : out std_logic_vector(10 downto 0);
           blank_l    : out std_logic;
           hsync      : out std_logic;
           vsync      : out std_logic;
           locked     : out std_logic );
  end component;

  -----------------------------------------------------------------------------
  -- Displays the image stored in the RAM
  -----------------------------------------------------------------------------

  component vga_out is
    port ( clk : in  std_logic;
           rst : in  std_logic;

           ram_addr : out std_logic_vector(16 downto 0);
           ram_dout : in  std_logic_vector(7 downto 0);

           pixel_cnt : in  std_logic_vector(10 downto 0);
           line_cnt  : in  std_logic_vector(10 downto 0);
           blank_l_g : in  std_logic;
           hsync_g   : in  std_logic;
           vsync_g   : in  std_logic;
         
           red       : out std_logic_vector(7 downto 0);
           green     : out std_logic_vector(7 downto 0);
           blue      : out std_logic_vector(7 downto 0);
           pixel_clk : out std_logic;
           blank_l   : out std_logic;
           sync_l    : out std_logic;
           hsync     : out std_logic;
           vsync     : out std_logic );
  end component;

end package;

-------------------------------------------------------------------------------

package body pkg_vga_out is

  -----------------------------------------------------------------------------
  -- Array of VGA timing settings records
  -----------------------------------------------------------------------------
  
  type timing_array is array (positive range <>) of timing;

  -----------------------------------------------------------------------------
  -- List of all supported VGA timing settings
  --
  -- The marked settings are exact settings; the others are approximations.
  -----------------------------------------------------------------------------
  
  constant timing_list : timing_array(1 to 16) :=
    ( ( 640,  480, 60,  1,  4, 16,  96,  48,  800,  9, 2, 29,  520),
      ( 640,  480, 72,  5, 16, 24,  40, 128,  832, 10, 3, 29,  522),
      ( 640,  480, 75,  5, 16, 18,  96,  42,  796, 11, 2, 31,  524),
      ( 640,  480, 85,  5, 14, 32,  48, 108,  828,  1, 3, 23,  507),
      ( 800,  600, 60,  4, 10, 40, 128,  88, 1056,  1, 4, 23,  628), -- Exact
      ( 800,  600, 72,  1,  2, 56, 120,  64, 1040, 37, 6, 23,  666), -- Exact
      ( 800,  600, 75,  1,  2, 16,  80, 168, 1064,  1, 2, 23,  626),
      ( 800,  600, 85, 11, 20, 32,  64, 144, 1040,  1, 3, 18,  622),
      (1024,  768, 60, 13, 20, 24, 136, 160, 1344,  3, 6, 29,  806), -- Exact
      (1024,  768, 72, 15, 20, 16,  96, 172, 1308,  1, 3, 24,  796),
      (1024,  768, 75,  8, 10, 24,  96, 184, 1328,  2, 4, 29,  803),
      (1024,  768, 85, 19, 20, 48,  96, 208, 1376,  2, 4, 38,  812),
      (1280, 1024, 60, 11, 10, 52, 120, 256, 1708,  3, 5, 42, 1074),
      (1280, 1024, 72, 13, 10, 16, 144, 248, 1688,  2, 4, 40, 1070),
      (1280, 1024, 75, 27, 20, 16, 144, 248, 1688,  1, 3, 38, 1066), -- Exact
      (1280, 1024, 85,  3,  2, 40, 144, 224, 1688,  1, 3, 28, 1056) );

  -----------------------------------------------------------------------------
  -- Looks up the VGA timing settings corresponding to given resolution and
  -- frequency
  --
  -- Inputs:
  --   - res_x [positive] : required X resolution
  --   - res_y [positive] : required Y resolution
  --   - freq  [positive] : required frequency
  --
  -- Return:
  --   - [timing] : corresponding VGA timing settings, if found
  --
  -- Aborts if no timing was found.
  -----------------------------------------------------------------------------

  function find_timing ( res_x : positive;
                         res_y : positive;
                         freq  : positive ) return timing is
  begin
    for i in timing_list'low to timing_list'high loop
      if (timing_list(i).res_x = res_x) and (timing_list(i).res_y = res_y) and
         (timing_list(i).freq = freq) then
        return timing_list(i);
      end if;
    end loop;
    
    assert false
      report   "Error: Unsupported video mode."
      severity failure;
    
    return (1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1); -- Dummy settings
  end function;

end package body;

-------------------------------------------------------------------------------
-- Generates the correct timing and sync signals for given resolution and
-- frequency
--
-- Generics:
--   - res_x [positive] : required X resolution
--   - res_y [positive] : required Y resolution
--   - freq  [positive] : required frequency
--
-- Ports:
--   - system_clk [in]  : 100MHz clock from the board
--   - rst_l      [in]  : active-low reset signal
--   - clk        [out] : VGA pixel clock
--   - pixel_cnt  [out] : pixel counter
--   - line_cnt   [out] : line counter
--   - blank_l    [out] : active-low blanking signal
--   - hsync      [out] : horizontal sync signal, delayed by 2 pixel clock
--                        cycles to account for the DAC pipeline delay
--   - vsync      [out] : vertical sync signal, delayed by 2 pixel clock
--                        cycles to account for the DAC pipeline delay
--   - locked     [out] : asserts when the pixel clock is locked
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
--library unisim;
--use unisim.vcomponents.all;
library altera_mf;
--use altera_mf.altera_mf_components.all;
use altera_mf.all;
library work;
use work.pkg_util.all;
use work.pkg_vga_out.all;

entity vga_timing_gen is
  generic ( res_x : positive := 640;
            res_y : positive := 480;
            freq  : positive := 60 );
  port ( system_clk : in  std_logic;
         rst_l      : in  std_logic;
         clk        : out std_logic;
         pixel_cnt  : out std_logic_vector(10 downto 0);
         line_cnt   : out std_logic_vector(10 downto 0);
         blank_l    : out std_logic;
         hsync      : out std_logic;
         vsync      : out std_logic;
         locked     : out std_logic );
end entity;

architecture arch of vga_timing_gen is
  constant tm : timing := find_timing(res_x, res_y, freq);
  
  constant h_fp : positive := tm.h_total - tm.h_sync - tm.h_bp;
  constant h_bp : positive := tm.h_total - tm.h_bp;
  constant v_fp : positive := tm.v_total - tm.v_sync - tm.v_bp;
  constant v_bp : positive := tm.v_total - tm.v_bp;

  signal not_rst_l : std_logic;
  
  signal clk0      : std_logic;
  signal clk0_buf  : std_logic;
  signal clkfx     : std_logic;
  signal clkfx_buf : std_logic;
  signal locked_0  : std_logic;

  signal vga_clk : std_logic;
  signal rst     : std_logic;

  signal pixel_cnt_0 : std_logic_vector(10 downto 0);
  signal pixel_cnt_r : std_logic_vector(10 downto 0) := "00000000000";
  signal line_cnt_0  : std_logic_vector(10 downto 0);
  signal line_cnt_r  : std_logic_vector(10 downto 0) := "00000000000";

  signal htotal_b : boolean;
  signal vtotal_b : boolean;
  signal hsync_b  : boolean;
  signal vsync_b  : boolean;
  signal hblank_b : boolean;
  signal vblank_b : boolean;

  signal hblank_0 : std_logic;
  signal hblank_r : std_logic := '0';
  signal vblank_0 : std_logic;
  signal vblank_r : std_logic := '0';

  signal hsync_0  : std_logic;
  signal hsync_r  : std_logic := '0';
  signal vsync_0  : std_logic;
  signal vsync_r  : std_logic := '0';
	COMPONENT altpll
	GENERIC (
		clk0_divide_by		: NATURAL;
		clk0_duty_cycle		: NATURAL;
		clk0_multiply_by		: NATURAL;
		clk0_phase_shift		: STRING;
		compensate_clock		: STRING;
		inclk0_input_frequency		: NATURAL;
		intended_device_family		: STRING;
		invalid_lock_multiplier		: NATURAL;
		lpm_hint		: STRING;
		lpm_type		: STRING;
		operation_mode		: STRING;
		pll_type		: STRING;
		port_activeclock		: STRING;
		port_areset		: STRING;
		port_clkbad0		: STRING;
		port_clkbad1		: STRING;
		port_clkloss		: STRING;
		port_clkswitch		: STRING;
		port_configupdate		: STRING;
		port_fbin		: STRING;
		port_inclk0		: STRING;
		port_inclk1		: STRING;
		port_locked		: STRING;
		port_pfdena		: STRING;
		port_phasecounterselect		: STRING;
		port_phasedone		: STRING;
		port_phasestep		: STRING;
		port_phaseupdown		: STRING;
		port_pllena		: STRING;
		port_scanaclr		: STRING;
		port_scanclk		: STRING;
		port_scanclkena		: STRING;
		port_scandata		: STRING;
		port_scandataout		: STRING;
		port_scandone		: STRING;
		port_scanread		: STRING;
		port_scanwrite		: STRING;
		port_clk0		: STRING;
		port_clk1		: STRING;
		port_clk3		: STRING;
		port_clk4		: STRING;
		port_clk5		: STRING;
		port_clkena0		: STRING;
		port_clkena1		: STRING;
		port_clkena3		: STRING;
		port_clkena4		: STRING;
		port_clkena5		: STRING;
		port_extclk0		: STRING;
		port_extclk1		: STRING;
		port_extclk2		: STRING;
		port_extclk3		: STRING;
		valid_lock_multiplier		: NATURAL
	);
	PORT (
			clk	: OUT STD_LOGIC_VECTOR (5 DOWNTO 0);
			inclk	: IN STD_LOGIC_VECTOR (1 DOWNTO 0);
			locked	: OUT STD_LOGIC 
	);
	END COMPONENT;

begin

  not_rst_l <= not rst_l;

	altpll_component : altpll
	GENERIC MAP (
		clk0_divide_by => 2,
		clk0_duty_cycle => 50,
		clk0_multiply_by => 1,
		clk0_phase_shift => "0",
		compensate_clock => "CLK0",
		inclk0_input_frequency => 20000,
--		intended_device_family => "Cyclone",
		intended_device_family => "Cyclone IV",
		invalid_lock_multiplier => 5,
		lpm_hint => "CBX_MODULE_PREFIX=testpll",
		lpm_type => "altpll",
		operation_mode => "NORMAL",
		pll_type => "AUTO",
		port_activeclock => "PORT_UNUSED",
		port_areset => "PORT_UNUSED",
		port_clkbad0 => "PORT_UNUSED",
		port_clkbad1 => "PORT_UNUSED",
		port_clkloss => "PORT_UNUSED",
		port_clkswitch => "PORT_UNUSED",
		port_configupdate => "PORT_UNUSED",
		port_fbin => "PORT_UNUSED",
		port_inclk0 => "PORT_USED",
		port_inclk1 => "PORT_UNUSED",
		port_locked => "PORT_USED",
		port_pfdena => "PORT_UNUSED",
		port_phasecounterselect => "PORT_UNUSED",
		port_phasedone => "PORT_UNUSED",
		port_phasestep => "PORT_UNUSED",
		port_phaseupdown => "PORT_UNUSED",
		port_pllena => "PORT_UNUSED",
		port_scanaclr => "PORT_UNUSED",
		port_scanclk => "PORT_UNUSED",
		port_scanclkena => "PORT_UNUSED",
		port_scandata => "PORT_UNUSED",
		port_scandataout => "PORT_UNUSED",
		port_scandone => "PORT_UNUSED",
		port_scanread => "PORT_UNUSED",
		port_scanwrite => "PORT_UNUSED",
		port_clk0 => "PORT_USED",
		port_clk1 => "PORT_UNUSED",
		port_clk3 => "PORT_UNUSED",
		port_clk4 => "PORT_UNUSED",
		port_clk5 => "PORT_UNUSED",
		port_clkena0 => "PORT_UNUSED",
		port_clkena1 => "PORT_UNUSED",
		port_clkena3 => "PORT_UNUSED",
		port_clkena4 => "PORT_UNUSED",
		port_clkena5 => "PORT_UNUSED",
		port_extclk0 => "PORT_UNUSED",
		port_extclk1 => "PORT_UNUSED",
		port_extclk2 => "PORT_UNUSED",
		port_extclk3 => "PORT_UNUSED",
		valid_lock_multiplier => 1
	)
	PORT MAP (
		inclk(0) => system_clk,
		clk(0) => clkfx_buf,
		locked => locked_0
	);
--  dcm_0 : altpll
--    generic map (
--	   operation_mode => "NORMAL",
--    	clk0_divide_by => tm.dcm_d,
--    	clk0_multiply_by => tm.dcm_m * 2,
--		inclk0_input_frequency => 20000,
--		inclk1_input_frequency => 20000,	-- WTF??
--		port_inclk1 => "PORT_UNUSED"
--		)
--    port map (
--    	inclk(0) => system_clk,
--    	clk(0) => clkfx_buf,
--    	locked => locked_0
--    );
  --dcm_dv : if tm.dcm_m = 1 generate
  --  dcm_0 : dcm
  --    generic map ( clkdv_divide   => real(tm.dcm_d) )
  --    port map ( clkin    => system_clk,
  --               clkfb    => clk0_buf,
  --               rst      => not_rst_l,
  --               clk0     => clk0,
  --               clkdv    => clkfx,
  --               locked   => locked_0 );
  --end generate;

  --dcm_fx : if tm.dcm_m > 1 generate
  --  dcm_0 : dcm
  --    generic map ( clkin_period   => 10.0,
  --                  clkfx_multiply => tm.dcm_m,
  --                  clkfx_divide   => tm.dcm_d )
  --    port map ( clkin    => system_clk,
  --               clkfb    => clk0_buf,
  --               rst      => not_rst_l,
  --               clk0     => clk0,
  --               clkfx    => clkfx,
  --               locked   => locked_0 );
  --end generate;
  

  --bufg_clk0 : bufg
  --  port map ( i => clk0,
  --             o => clk0_buf );

  --bufg_clkfx : bufg
  --  port map ( i => clkfx,
  --             o => clkfx_buf );

  vga_clk <= clkfx_buf;
  rst     <= (not rst_l) or (not locked_0);

  htotal_b <= pixel_cnt_r = conv_std_logic_vector(tm.h_total-1, 11);
  vtotal_b <= line_cnt_r  = conv_std_logic_vector(tm.v_total-1, 11);
  
  hsync_b <= pixel_cnt_r = conv_std_logic_vector(h_fp-1, 11) or
             pixel_cnt_r = conv_std_logic_vector(h_bp-1, 11);
  vsync_b <= line_cnt_r  = conv_std_logic_vector(v_fp-1, 11) or
             line_cnt_r  = conv_std_logic_vector(v_bp-1, 11);

  hblank_b <= pixel_cnt_r = conv_std_logic_vector(tm.res_x-1, 11) or htotal_b;
  vblank_b <= line_cnt_r  = conv_std_logic_vector(tm.res_y-1, 11) or vtotal_b;


  pixel_cnt_0 <= pixel_cnt_r + "00000000001" when not htotal_b else
                 "00000000000";

  line_cnt_0  <= line_cnt_r                 when not htotal_b else
                 line_cnt_r + "00000000001" when not vtotal_b else
                 "00000000000";

  hsync_0 <= not hsync_r when hsync_b else
             hsync_r;

  vsync_0 <= not vsync_r when htotal_b and vsync_b else
             vsync_r;

  hblank_0 <= not hblank_r when hblank_b else
              hblank_r;
  
  vblank_0 <= not vblank_r when htotal_b and vblank_b else
              vblank_r;
  
  process(vga_clk, rst)
  begin
    if rst = '1' then
      pixel_cnt_r <= "00000000000";
      line_cnt_r  <= "00000000000";
      hblank_r    <= '0';
      vblank_r    <= '0';
      hsync_r     <= '0';
      vsync_r     <= '0';
    elsif vga_clk'event and vga_clk = '1' then
      pixel_cnt_r <= pixel_cnt_0;
      line_cnt_r  <= line_cnt_0;
      hblank_r    <= hblank_0;
      vblank_r    <= vblank_0;
      hsync_r     <= hsync_0;
      vsync_r     <= vsync_0;
    end if;
  end process;

  clk <= vga_clk;
  
  pixel_cnt <= pixel_cnt_r;
  line_cnt  <= line_cnt_r;

  blank_l <= not (hblank_r or vblank_r);

  delay_hsync : delay
    generic map ( n => 2 )
    port map ( i   => hsync_r,
               o   => hsync,
               clk => vga_clk );

  delay_vsync : delay
    generic map ( n => 2 )
    port map ( i   => vsync_r,
               o   => vsync,
               clk => vga_clk );

  locked <= locked_0;

end architecture;

-------------------------------------------------------------------------------
-- Displays the image stored in the RAM
--
-- Ports:
--   - clk [in]  : RAM and pixel clock signal
--   - rst [in]  : global reset signal
--
--   - ram_addr [out] : RAM address
--   - ram_dout [in]  : RAM data output
--
--   - pixel_cnt [in]  : pixel counter
--   - line_cnt  [in]  : line counter
--   - blank_l_g [in]  : active-low blanking signal from the timing generator
--   - hsync_g   [in]  : horizontal sync signal from the timing generator
--   - vsync_g   [in]  : vertical sync signal from the timing generator
--
--   - red       [out] : 8-bit red pixel component
--   - green     [out] : 8-bit green pixel component
--   - blue      [out] : 8-bit blue pixel component
--   - pixel_clk [out] : pixel clock for the RGB DAC
--   - blank_l   [out] : active-low blanking signal
--   - sync_l    [out] : active-low composite sync signal (unused)
--   - hsync     [out] : horizontal sync signal
--   - vsync     [out] : vertical sync signal
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
--library unisim;
--use unisim.vcomponents.all;
LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;
library work;
use work.pkg_util.all;

entity vga_out is
  port ( clk : in  std_logic;
         rst : in  std_logic;

         ram_addr : out std_logic_vector(16 downto 0);
         ram_dout : in  std_logic_vector(7 downto 0);

         pixel_cnt : in  std_logic_vector(10 downto 0);
         line_cnt  : in  std_logic_vector(10 downto 0);
         blank_l_g : in  std_logic;
         hsync_g   : in  std_logic;
         vsync_g   : in  std_logic;
         
         red       : out std_logic_vector(7 downto 0);
         green     : out std_logic_vector(7 downto 0);
         blue      : out std_logic_vector(7 downto 0);
         pixel_clk : out std_logic;
         blank_l   : out std_logic;
         sync_l    : out std_logic;
         hsync     : out std_logic;
         vsync     : out std_logic );
end entity;

architecture arch of vga_out is
  signal ram_dout_r : std_logic_vector(7 downto 0);

  signal red_0   : std_logic_vector(7 downto 0);
  signal red_r   : std_logic_vector(7 downto 0) := "00000000";
  signal green_0 : std_logic_vector(7 downto 0);
  signal green_r : std_logic_vector(7 downto 0) := "00000000";
  signal blue_0  : std_logic_vector(7 downto 0);
  signal blue_r  : std_logic_vector(7 downto 0) := "00000000";

  signal blank_l_r : std_logic := '0';
  signal hsync_r   : std_logic := '1';
  signal vsync_r   : std_logic := '1';

  signal not_clk : std_logic;
begin

  ram_addr <= ("00000000" & pixel_cnt(10 downto 2))     +
              --("000" & line_cnt(9 downto 2) & "000000") +
              ("0" & line_cnt(9 downto 2) & "00000000");

  red_0   <= ram_dout_r(7 downto 5) & "00000";
  green_0 <= ram_dout_r(4 downto 3) & "000000";
  blue_0  <= ram_dout_r(2 downto 0) & "00000";

  process(clk, rst)
  begin
    if rst = '1' then
      ram_dout_r <= "00000000";
      red_r      <= "00000000";
      green_r    <= "00000000";
      blue_r     <= "00000000";
    elsif clk'event and clk = '1' then
      ram_dout_r <= ram_dout;
      red_r      <= red_0;
      green_r    <= green_0;
      blue_r     <= blue_0;
    end if;
  end process;

  delay_blank_l : delay
    generic map ( n => 3 )
    port map ( i   => blank_l_g,
               o   => blank_l_r,
               clk => clk );

  delay_hsync : delay
    generic map ( n => 3 )
    port map ( i   => hsync_g,
               o   => hsync_r,
               clk => clk );

  delay_vsync : delay
    generic map ( n => 3 )
    port map ( i   => vsync_g,
               o   => vsync_r,
               clk => clk );

  red     <= red_r;
  green   <= green_r;
  blue    <= blue_r;
  blank_l <= blank_l_r;
  sync_l  <= '0';
  hsync   <= hsync_r;
  vsync   <= vsync_r;

  not_clk <= not clk;
  --pixel_clk_gen : fddrrse
  --  port map ( q  => pixel_clk,
  --             d0 => '0',
  --             d1 => '1',
  --             c0 => clk,
  --             c1 => not_clk,
  --             ce => '1',
  --             r  => '0',
  --             s  => '0' );
  pixel_clk_gen : altddio_out
	generic map (
		extend_oe_disable => "OFF",
		intended_device_family => "Cyclone IV E",
		invert_output => "OFF",
		lpm_hint => "UNUSED",
		lpm_type => "altddio_out",
		oe_reg => "UNREGISTERED",
		power_up_high => "OFF",
		width => 1
	)
	port map (
		-- I have no idea what I am doing
		datain_h(0) => '1',
		datain_l(0) => '0',
		outclock => clk,
		dataout(0) => pixel_clk
	);

end architecture;
