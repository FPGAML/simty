-------------------------------------------------------------------------------
-- Utility package
--
-- Functions:
--   - log2 : floor of base-2 logarithm
--
-- Components:
--   - delay     : register delay
--   - delay_bus : register delay (bus version)
--   - demux     : demultiplexer
--   - mux       : multiplexer
--   - mux_bus   : multiplexer (bus version)
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package pkg_util is

  -----------------------------------------------------------------------------
  -- Floor of base-2 logarithm
  -----------------------------------------------------------------------------

  function log2 ( x : natural ) return integer;

  -----------------------------------------------------------------------------
  -- Register delay
  -----------------------------------------------------------------------------
  
  component delay is
    generic ( n : positive );
    port ( i   : in  std_logic;
           o   : out std_logic;
           clk : in  std_logic );
  end component;

  -----------------------------------------------------------------------------
  -- Register delay (bus version)
  -----------------------------------------------------------------------------
  
  component delay_bus is
    generic ( w : positive;
              n : positive );
    port ( i   : in  std_logic_vector(w-1 downto 0);
           o   : out std_logic_vector(w-1 downto 0);
           clk : in  std_logic );
  end component;
  
  -----------------------------------------------------------------------------
  -- Demultiplexer
  -----------------------------------------------------------------------------
  
  component demux is
    generic ( n : positive );
    port ( i : in  std_logic;
           a : in  std_logic_vector(n-1 downto 0);
           o : out std_logic_vector(2**n-1 downto 0) );
  end component;

  -----------------------------------------------------------------------------
  -- Multiplexer
  -----------------------------------------------------------------------------
  
  component mux is
    generic ( n : positive );
    port ( i : in  std_logic_vector(2**n-1 downto 0);
           a : in  std_logic_vector(n-1 downto 0);
           o : out std_logic );
  end component;

  -----------------------------------------------------------------------------
  -- Multiplexer (bus version)
  -----------------------------------------------------------------------------
  
  component mux_bus is
    generic ( w : positive;
              n : positive );
    port ( i : in  std_logic_vector(w*2**n-1 downto 0);
           a : in  std_logic_vector(n-1 downto 0);
           o : out std_logic_vector(w-1 downto 0) );
  end component;

end package;

-------------------------------------------------------------------------------

package body pkg_util is

  -----------------------------------------------------------------------------
  -- Floor of base-2 logarithm
  --
  -- Inputs:
  --   - x [natural] : argument
  --
  -- Return:
  --   - [integer] : base-2 logarithm of x, rounded towards 0
  --
  -- log2(0) -> 0
  -- log2(1) -> 0
  -- log2(2) -> 1
  -- log2(3) -> 1
  -- log2(4) -> 2
  --  .   .   .
  -----------------------------------------------------------------------------

  function log2 ( x : natural ) return integer is
    variable n : natural := 0;
  begin
    while 2**(n+1) <= x loop
      n := n+1;
    end loop;
    return n;
  end function;

end package body;

-------------------------------------------------------------------------------
-- Register delay
--
-- Generics:
--   - n : number of register stages
--
-- Ports:
--   - i   [in]  : input signal
--   - o   [out] : delayed signal
--   - clk [in]  : clock signal
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity delay is
  generic ( n : positive );
  port ( i   : in  std_logic;
         o   : out std_logic;
         clk : in  std_logic );
end entity;

architecture arch of delay is
  signal buf : std_logic_vector(n downto 0);
begin

  buf(0) <= i;

  process(clk)
  begin
    if clk'event and clk = '1' then
      buf(n downto 1) <= buf(n-1 downto 0);
    end if;
  end process;

  o <= buf(n);

end architecture;

-------------------------------------------------------------------------------
-- Register delay (bus version)
--
-- Generics:
--   - n : number of register stages
--
-- Ports:
--   - i   [in]  : input bus
--   - o   [out] : delayed bus
--   - clk [in]  : clock signal
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library work;
use work.pkg_util.all;

entity delay_bus is
  generic ( w : positive;
            n : positive );
  port ( i   : in  std_logic_vector(w-1 downto 0);
         o   : out std_logic_vector(w-1 downto 0);
         clk : in  std_logic );
end entity;

architecture arch of delay_bus is
begin

  bit_delay : for k in w-1 downto 0 generate
    d : delay
      generic map ( n => n )
      port map ( i   => i(k),
                 clk => clk,
                 o   => o(k) );
  end generate;
  
end architecture;

-------------------------------------------------------------------------------
-- Demultiplexer
--
-- Generics:
--   - n : depth of the demultiplexer tree (number of address bits)
--
-- Ports:
--   - i [in]  : input signal
--   - a [in]  : address
--   - o [out] : demultiplexed signals
--
-- Recursive binary tree structure.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity demux is
  generic ( n : positive );
  port ( i : in  std_logic;
         a : in  std_logic_vector(n-1 downto 0);
         o : out std_logic_vector(2**n-1 downto 0) );
end entity;

architecture arch of demux is
  component demux is
    generic ( n : positive );
    port ( i : in  std_logic;
           a : in  std_logic_vector(n-1 downto 0);
           o : out std_logic_vector(2**n-1 downto 0) );
  end component;

  signal i0 : std_logic;
  signal i1 : std_logic;
begin

  i0 <=  i  when a(n-1) = '0' else
        '0';
  i1 <=  i  when a(n-1) = '1' else
        '0';

  single : if n = 1 generate
    o <= i1 & i0;
  end generate;

  recursive : if n > 1 generate
    demux0 : demux
      generic map ( n => n-1 )
      port map ( i => i0,
                 a => a(n-2 downto 0),
                 o => o(2**(n-1)-1 downto 0) );
    demux1 : demux
      generic map ( n => n-1 )
      port map ( i => i1,
                 a => a(n-2 downto 0),
                 o => o(2**n-1 downto 2**(n-1)) );
  end generate;

end architecture;

-------------------------------------------------------------------------------
-- Multiplexer
--
-- Generics:
--   - n : depth of the multiplexer tree (number of address bits)
--
-- Ports:
--   - i [in]  : input signals
--   - a [in]  : address
--   - o [out] : multiplexed signal
--
-- Recursive binary tree structure.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity mux is
  generic ( n : positive );
  port ( i : in  std_logic_vector(2**n-1 downto 0);
         a : in  std_logic_vector(n-1 downto 0);
         o : out std_logic );
end entity;

architecture arch of mux is
  component mux is
    generic ( n : positive );
    port ( i : in  std_logic_vector(2**n-1 downto 0);
           a : in  std_logic_vector(n-1 downto 0);
           o : out std_logic );
  end component;

  signal o0 : std_logic;
  signal o1 : std_logic;
begin

  single : if n = 1 generate
    o0 <= i(0);
    o1 <= i(1);
  end generate;

  recursive : if n > 1 generate
    mux0 : mux
      generic map ( n => n-1 )
      port map ( i => i(2**(n-1)-1 downto 0),
                 a => a(n-2 downto 0),
                 o => o0 );
    mux1 : mux
      generic map ( n => n-1 )
      port map ( i => i(2**n-1 downto 2**(n-1)),
                 a => a(n-2 downto 0),
                 o => o1 );
  end generate;

  o <= o0 when a(n-1) = '0' else
       o1;

end architecture;

-------------------------------------------------------------------------------
-- Multiplexer (bus version)
--
-- Generics:
--   - w : bitwidth of the bus
--   - n : depth of the multiplexer tree (number of address bits)
--
-- Ports:
--   - i [in]  : input signals
--   - a [in]  : address
--   - o [out] : multiplexed bus
--
-- Recursive binary tree structure.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity mux_bus is
  generic ( w : positive;
            n : positive );
  port ( i : in  std_logic_vector(w*2**n-1 downto 0);
         a : in  std_logic_vector(n-1 downto 0);
         o : out std_logic_vector(w-1 downto 0) );
end entity;

architecture arch of mux_bus is
  component mux_bus is
    generic ( w : positive;
              n : positive );
    port ( i : in  std_logic_vector(w*2**n-1 downto 0);
           a : in  std_logic_vector(n-1 downto 0);
           o : out std_logic_vector(w-1 downto 0) );
  end component;

  signal o0 : std_logic_vector(w-1 downto 0);
  signal o1 : std_logic_vector(w-1 downto 0);
begin

  single : if n = 1 generate
    o0 <= i(w-1 downto 0);
    o1 <= i(2*w-1 downto w);
  end generate;

  recursive : if n > 1 generate
    mux0 : mux_bus
      generic map ( w => w,
                    n => n-1 )
      port map ( i => i(w*2**(n-1)-1 downto 0),
                 a => a(n-2 downto 0),
                 o => o0 );
    mux1 : mux_bus
      generic map ( w => w,
                    n => n-1 )
      port map ( i => i(w*2**n-1 downto w*2**(n-1)),
                 a => a(n-2 downto 0),
                 o => o1 );
  end generate;

  o <= o0 when a(n-1) = '0' else
       o1;

end architecture;
