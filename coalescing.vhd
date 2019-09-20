library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;

-- Address generation unit
-- Memory arbitration unit
entity Coalescing is
	port (
		clock : in std_logic;
		reset : in std_logic;
		mpc_in : in code_address;
		wid_in : in warpid;
		insn_in : in decoded_instruction;

		valid_mask : in mask;	-- From MSHP
		leader : in laneid;		-- binary
		leader_mask : in mask;	-- one-hot
		--invalid : in std_logic;

		vector_address : in vector;	-- From EX
		store_data_in : in vector;

		--address : out block_address;
		--store_data_out : out vector;
		--byte_enable : out std_logic_vector(3 downto 0);	-- One byte-enable shared by everyone!
		--address_valid_mask : out mask;
		request : out Bus_Request;

		broadcast_mask : out mask;
		replay_mask : out mask;

		leader_offset : out std_logic_vector(log_blocksize - 1 downto 0);

		insn_out : out decoded_instruction;
		mpc_out : out code_address;
		wid_out : out warpid
	);
end entity;

architecture structural of Coalescing is
	signal wordstrided_mask : mask;
	signal block_mask : mask;
	signal coalescing_mask : mask;
	signal uniform_ld_mask, uniform_st_mask, broadcast_mask0 : mask;
	signal leader_address : scalar;
	signal leader_data_raw, leader_data : scalar;
	signal leader_data_demux0 : std_logic_vector(15 downto 0);
	signal leader_int : integer;
	signal store_data : vector;
	signal is_mem : boolean;
	signal subword_key : std_logic_vector(3 downto 0);
	signal leader_byteenable : std_logic_vector(3 downto 0);
	signal address_unaligned : std_logic;
	signal write_mask_0, broadcast_mask_0, replay_mask_0 : mask;
	signal is_word_access : std_logic;
begin
	leader_int <= to_integer(unsigned(leader));
	leader_address <= vector_address((leader_int + 1) * 32 - 1 downto leader_int * 32); -- I feel lucky
	-- May try tri-state buffers instead of mux (encode leader in 1-hot as mask)
	-- Altera Quartus does not like tri-state buffers
	--leader_mux : for i in 0 to warpsize - 1 generate
	--	leader_address <= vector_address((i+1) * 32 - 1 downto i * 32) when leader_mask(i) = '1' else (others => 'Z');
	--end generate;

	msb_compare: for i in 0 to warpsize - 1 generate
		block_mask(i) <= '1' when vector_address((i+1) * 32 - 1 downto i * 32 + log_blocksize) = leader_address(31 downto log_blocksize) else '0';
	end generate;

	lsb_compare: for i in 0 to warpsize - 1 generate
		wordstrided_mask(i) <= '1' when vector_address(i * 32 + log_blocksize - 1 downto i * 32 + 2) = std_logic_vector(to_unsigned(i, log_blocksize - 2)) else '0';
		uniform_ld_mask(i) <= '1' when vector_address(i * 32 + log_blocksize - 1 downto i * 32 + 2) = leader_address(log_blocksize - 1 downto 2) else '0';
		uniform_st_mask(i) <= '1' when to_integer(unsigned(leader_address(log_blocksize - 1 downto 2))) = i else '0';
	end generate;

	is_word_access <= '1' when insn_in.mem_size(1 downto 0) = "10" else '0';
	coalescing_mask <= block_mask and wordstrided_mask and valid_mask and is_word_access;
	broadcast_mask0 <= block_mask and uniform_ld_mask when insn_in.memop = LD else leader_mask;

	leader_data_raw <= store_data_in((leader_int + 1) * 32 - 1 downto leader_int * 32); -- I feel really lucky
	-- Leader supports sub-word stores
	-- Sub-word demux: byte insert
	leader_data_demux0(15 downto 8) <= leader_data_raw(7 downto 0) when leader_address(0) = '1' else leader_data_raw(15 downto 8);
	leader_data_demux0(7 downto 0) <= leader_data_raw(7 downto 0);
	leader_data(31 downto 16) <= leader_data_demux0 when leader_address(1) = '1' else leader_data_raw(31 downto 16);
	leader_data(15 downto 0) <= leader_data_demux0(15 downto 0);

	-- Byte mask
	subword_key <= insn_in.mem_size(1 downto 0) & leader_address(1 downto 0);
	with subword_key select
		leader_byteenable <=
			"0001" when "0000", -- 0
			"0010" when "0001", -- 1
			"0100" when "0010", -- 2
			"1000" when "0011", -- 3
			"0011" when "0100", -- 4
			"1100" when "0110", -- 6
			"1111" when "1000", -- 8
			"----" when others;
	with subword_key select
		address_unaligned <= '0' when "0000"|"0001"|"0010"|"0011"|"0100"|"0110"|"1000",
		                     '1' when others;

	data_mux: for i in 0 to warpsize - 1 generate
		store_data((i+1) * 32 - 1 downto i * 32) <=
			--leader_data when leader_mask(i) = '1' else
			store_data_in((i+1) * 32 - 1 downto i * 32) when coalescing_mask(i) = '1' else
			leader_data when to_integer(unsigned(leader_address(log_blocksize - 1 downto 2))) = i else
			(others => '0');
	end generate;


	is_mem <= insn_in.memop = LD or insn_in.memop = ST;
	--write_mask_0 <= valid_mask and (coalescing_mask or broadcast_mask0) when insn_in.memop = ST else EmptyMask;
	write_mask_0 <= uniform_st_mask or coalescing_mask when insn_in.memop = ST else EmptyMask;
	broadcast_mask_0 <= valid_mask and broadcast_mask0 when is_mem else EmptyMask;
	replay_mask_0 <= valid_mask and not (coalescing_mask or broadcast_mask0) when is_mem else EmptyMask;

	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				request.address <= (others => '0');
				request.data <= (others => '0');
				request.shared_byte_enable <= (others => '0');
				request.write_mask <= EmptyMask;
				request.wid <= (others => '0');
				request.valid <= '0';
				request.is_write <= '0';
				request.is_read <= '0';
				broadcast_mask <= EmptyMask;
				replay_mask <= EmptyMask;
				leader_offset <= (others => '0');
				insn_out <= NopDec;
				mpc_out <= (others => '0');
				wid_out <= (others => '0');
			else
				request.address <= leader_address(31 downto log_blocksize);
				request.data <= store_data;
				request.shared_byte_enable <= leader_byteenable;
				request.write_mask <= write_mask_0;
				request.wid <= wid_in;
				if is_mem then request.valid <= '1'; else request.valid <= '0'; end if;
				if insn_in.memop = ST then request.is_write <= '1'; else request.is_write <= '0'; end if;
				if insn_in.memop = LD then request.is_read <= '1'; else request.is_read <= '0'; end if;
				broadcast_mask <= broadcast_mask_0;
				replay_mask <= replay_mask_0;
				leader_offset <= leader_address(log_blocksize - 1 downto 0);
				insn_out <= insn_in;
				mpc_out <= mpc_in;
				wid_out <= wid_in;
			end if;
		end if;
	end process;


end architecture;
