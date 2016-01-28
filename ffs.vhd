library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- Find first bit set in mask
-- that is closest to default
-- Test if zero
-- Returns binary and one-hot encoded values
-- Vector size power of 2
entity FFS is
	generic (logw : natural := 2);
	port (
		mask : in std_logic_vector(2**logw - 1 downto 0);
		defaultv : in std_logic_vector(logw - 1 downto 0) := (others => '0');
		fs : out std_logic_vector(logw - 1 downto 0);
		zero : out std_logic;
		one_hot : out std_logic_vector(2**logw - 1 downto 0)
	);
end entity;

architecture structural of FFS is
	constant w : natural := 2**logw;
	type reduction_array is array(logw downto 0) of std_logic_vector(w - 1 downto 0);
	signal reduce : reduction_array;
	signal digits : std_logic_vector(logw - 1 downto 0);
begin
	reduce(logw) <= mask;
	tree: for i in logw - 1 downto 0 generate
		-- Split in 2 over 2**i, check if low part is all-zero
		digits(i) <= '1' when reduce(i+1)(2**i-1 downto 0) = (2**i-1 downto 0 => '0')
		                      or (defaultv(i) = '1' and reduce(i+1)(2**(i+1)-1 downto 2**i) /= (2**i-1 downto 0 => '0'))
		             else '0';
		-- Select high part if low part is all-zero, select low part otherwise
		reduce(i)(2**i-1 downto 0) <= reduce(i+1)(2**(i+1)-1 downto 2**i) when digits(i) = '1' else
		                              reduce(i+1)(2**i-1 downto 0);
	end generate;
	fs <= digits;
	zero <= not reduce(0)(0);
	
	-- Attemt to use fast carry propagation chain
	--one_hot <= mask and std_logic_vector(-signed(mask));
	-- Decoder more area-efficient
	decoder : for i in 0 to 2**logw - 1 generate
		one_hot(i) <= '1' when to_integer(unsigned(digits))=i else '0';
	end generate;
end architecture;
