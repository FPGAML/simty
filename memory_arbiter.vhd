library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- Memory Arbiter
entity Memory_Arbiter is
	port (
		addresses : in vector;
		valid_mask : in mask;
		is_mem : in std_logic;
		
		-- vector of addresses for multi-bank memory
		bank_address : out block_address;							-- To L1D$
		address_valid : out std_logic;
		--offsets : out std_logic_matrix(warpsize-1 downto 0)(log_blocksize - 3 downto 0);	-- m * log(m)	-- To Xbar
		offsets : out std_logic_vector(warpsize * (log_blocksize - 2) - 1 downto 0);
		subwords : out std_logic_vector(warpsize * 2 - 1 downto 0);
		replay_mask : out mask										-- To Membership
	);
end entity;

-- Access to shared memory
-- Compute access mask for each bank
-- Find first set in each bank

-- Cross-block unaligned addresses? Replay?

architecture structural of Memory_Arbiter is
	--signal common_address : block_address;
	type block_address_vector is array(0 to warpsize - 1) of block_address;
	--signal address_tree : array(0 to log_warpsize - 1) of block_address_vector;
	--signal mask_tree : array(0 to log_warpsize - 1) of mask;
	signal bank_address_0 : block_address;
begin
	-- For now, just 1 bank

	-- Combined Priority encoder and Mux
	-- Attempt at behavioral style this time
	process(addresses, valid_mask, is_mem)
		variable address_row : block_address_vector;
		variable valid_row : mask;
		variable n : integer;
	begin
		if is_mem = '1' then
			valid_row := valid_mask;
		else
			valid_row := (others => '0');
		end if;
		
		for i in 0 to warpsize - 1 loop
			address_row(i) := addresses(32 * i + 31 downto 32 * i + log_blocksize);
		end loop;
		-- Reduce
		for j in log_warpsize - 1 downto 0 loop
			n := 2 ** j;
			for i in 0 to n - 1 loop
				if valid_mask(i) = '0' then
					-- Choose right value
					address_row(i) := address_row(n + i);
					valid_row(i) := valid_row(n + i);
				end if;
				-- Else keep left value
			end loop;
		end loop;
		bank_address_0 <= address_row(0);
		address_valid <= valid_row(0);
	end process;
	
	extract_lo : for i in 0 to warpsize - 1 generate
		--offsets(i) <= addresses(i)(log_blocksize - 1 downto 2);
		offsets((i+1)*(log_blocksize-2) - 1 downto i * (log_blocksize-2))
			<= addresses(32 * i + log_blocksize - 1 downto 32 * i + 2);
		subwords((i+1)*2-1 downto i*2) <= addresses(32 * i + 1 downto 32 * i);
	end generate;
	
	-- Find combinable addresses
	comparator_row : for i in 0 to warpsize - 1 generate
		replay_mask(i) <= '1' when is_mem = '1' and valid_mask(i) = '1' and
		                           addresses(32 * i + 31 downto 32 * i + log_blocksize) /= bank_address_0
		                      else '0';
	end generate;
	bank_address <= bank_address_0;
end architecture;
