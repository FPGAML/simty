-- This compenent is designed to intercept all memory traffic between Simty
-- and the different memories to be included. It uses the addresses in requests
-- and responses to determine where to send the data or where it's coming from.

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

	-- Debugging signals
	-- signal sig_write_mask : mask;
	-- signal sig_shared_byte_enable : std_logic_vector(3 downto 0);
	-- signal address_in_request : block_address;
	-- signal address_in_response : block_address;
	-- signal data_in_request : vector;
	-- signal data_in_response : vector;
	-- signal req_valid : std_logic;
	-- signal vga_req_valid : std_logic;
	-- signal testio_req_valid : std_logic;
	-- signal scratchpad_req_valid : std_logic;
	-- signal response_valid : std_logic;
	-- signal vga_resp_valid : std_logic;
	-- signal testio_resp_valid : std_logic;
	-- signal scratchpad_resp_valid : std_logic;

--	signal wtf : std_logic_vector(3 downto 0);
begin
	-- msb = Most Significant Bits; these determine which memory to use
	msb <= request.address(31 downto 28);

	-- Debugging code
	-- sig_write_mask <= request.write_mask;
	-- sig_shared_byte_enable <= request.shared_byte_enable;
	-- address_in_request <= request.address;
	-- address_in_response <= response.address;
	-- data_in_request <= request.data;
	-- data_in_response <= response.data;
	-- vga_req_valid			<= vga_request.valid;
	-- testio_req_valid		<= testio_request.valid;
	-- scratchpad_req_valid	<= scratchpad_request.valid;
	-- vga_resp_valid			<= vga_response.valid;
	-- testio_resp_valid		<= testio_response.valid;
	-- scratchpad_resp_valid	<= scratchpad_response.valid;
	-- req_valid <= request.valid;
	-- response_valid <= response.valid;

	-- This sets each memory request with the correct validity bit as determined
	-- from the msb in the original request. For example, if msb = 0000, then
	-- vga_request will be valid and all others will not.
	vga_request			<=	set_request( (msb = "0000" and request.valid = '1'), request);
	scratchpad_request	<=	set_request( (msb = "0001" and request.valid = '1'), request);
	testio_request		<=	set_request( (msb = "0010" and request.valid = '1'), request);

	-- Sets response to whichever of the argument responses is valid.
	-- If none of them is valid, or more than one is, response will be invalid.
	response <= set_response(vga_response, scratchpad_response, testio_response);

	process(clock)
	begin
		if rising_edge(clock) then
			if (request.valid = '1') and (msb /= "0000") and (msb /= "0001") and (msb /= "0010") then
				report "Bus_Arbiter: invalid address in simty request" severity error;
				report "MSB received: " & to_hstring(msb);
				report "Full address: " & to_string(request.address);
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
