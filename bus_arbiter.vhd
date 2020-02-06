library ieee;
use ieee.std_logic_1164.all;
use work.Simty_Pkg.all;


entity Bus_Arbiter is
	port (
		-- Inputs
		clock : in std_logic;
		reset : in std_logic;

		request : in Bus_Request; -- from simty

		vga_response : in Bus_Response;
		scratchpad_response : in Bus_Response;
		testio_response : in Bus_Response;

		-- Outputs
		vga_request  : out Bus_Request;
		scratchpad_request : out Bus_Request;
		testio_request : out Bus_Request;

		response : out Bus_Response -- back to simty
	);
end entity;


architecture structural of Bus_Arbiter is
	signal msb : std_logic_vector(3 downto 0);
	signal address_in_request : block_address; -- std_logic_vector(31 downto 4);
	signal address_in_response : block_address;
	signal data_in_request : vector;
	signal data_in_response : vector;
	signal req_valid : std_logic;
	signal vga_req_valid : std_logic;
	signal testio_req_valid : std_logic;
	signal scratchpad_req_valid : std_logic;

	signal vga_resp_valid : std_logic;
	signal testio_resp_valid : std_logic;
	signal scratchpad_resp_valid : std_logic;

	signal response_valid : std_logic;

	signal test : boolean;
	signal sig_write_mask : mask;
	signal sig_shared_byte_enable : std_logic_vector(3 downto 0);

--	signal wtf : std_logic_vector(3 downto 0);
begin
	msb <= request.address(31 downto 28);
--	wtf <= request.address(3 downto 0);
	address_in_request <= request.address;
	address_in_response <= response.address;
--	address_received(31 downto 4) <= request.address(31 downto 4);
	data_in_request <= request.data;
	data_in_response <= response.data;
	req_valid <= request.valid;
	sig_write_mask <= request.write_mask;
	sig_shared_byte_enable <= request.shared_byte_enable;

--	test <= ( (msb = "0000") and (request.valid = '1') );

-- 	process(request)
-- 	variable tmp_request : Bus_Request;
-- 	variable make_valid : std_logic;
-- 	begin
-- 		--vga_request 		:= request;-- when msb = "0000" else vga_request;
-- 		--scratchpad_request	:= request;-- when msb = "0001" else scratchpad_request;
-- 		--testio_request		:= request;-- when msb = "0010" else testio_request;
--
-- 		--make_valid		:= (msb = "0000") and (request.valid = '1');
-- --		vga_request.valid			:= '1' when msb = "0000" and request.valid = '1' else '0';
-- --		tmp_request		:=	set_request_valid(vga_valid, request);
-- --		vga_request		:=	set_request_valid( (msb = "0000" and request.valid = '1'), request);
-- 		--scratchpad_request.valid	:= '1' when msb = "0001" and request.valid = '1' else '0';
-- 		--testio_request.valid		:= '1' when msb = "0010" and request.valid = '1' else '0';
--
-- 	end process;

	vga_request			<=	set_request( (msb = "0000" and request.valid = '1'), request);
	scratchpad_request	<=	set_request( (msb = "0001" and request.valid = '1'), request);
	testio_request		<=	set_request( (msb = "0010" and request.valid = '1'), request);

	vga_req_valid			<= vga_request.valid;
	testio_req_valid		<= testio_request.valid;
	scratchpad_req_valid	<= scratchpad_request.valid;

	vga_resp_valid			<= vga_response.valid;
	testio_resp_valid		<= testio_response.valid;
	scratchpad_resp_valid	<= scratchpad_response.valid;

	response <= set_response(vga_response, scratchpad_response, testio_response);



	-- response <= vga_response when vga_response.valid = '1' else
	-- 			scratchpad_response when scratchpad_response.valid = '1' else
	-- 			testio_response when testio_response.valid = '1';
	--
	-- response.valid <= 	'0' when vga_response.valid /= '1' and scratchpad_response.valid /= '1' and testio_response.valid /= '1'
	-- 					else '1';
	response_valid <= response.valid;

	process(clock)
	begin
		if rising_edge(clock) then
			if request.valid = '1' then
				--report "Full address: " & to_string(request.address);
			end if;
			if (request.valid = '1') and (msb /= "0000") and (msb /= "0001") and (msb /= "0010") then
				report "Bus_Arbiter: invalid address in simty request" severity error;
				report "MSB received: " & to_hstring(msb);
				report "Full address: " & to_string(request.address);
			else
			--	report "Valid address: " & to_hstring(msb);
			end if;


			if(		(vga_response.valid = '1' and scratchpad_response.valid = '1')
				or	(vga_response.valid = '1' and testio_response.valid = '1')
				or	(scratchpad_response.valid = '1' and testio_response.valid = '1') ) then
					report "Bus_Arbiter: at least two memories have sent valid responses at once, and this isn't handled." severity error;
					if(	vga_response.valid = '1') then
						report "Bus_Arbiter: vga says it's valid" severity error;
					end if;
					if(	testio_response.valid = '1' ) then
						report "Bus_Arbiter: testio says it's valid." severity error;
					end if;
					if(	scratchpad_response.valid = '1' ) then
						report "Bus_Arbiter: scratchpad says it's valid." severity error;
					end if;
					report "";
			end if;
		end if;
	end process;

end architecture;
