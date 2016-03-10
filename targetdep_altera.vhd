-- Target-dependent components. Altera version

---------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Simty_Pkg.all;
library altera_mf;
use altera_mf.altera_mf_components.all;

-- 2 read/write ports, 2 clocks
entity SRAM32_dp is
	generic (
		logdepth : positive := 7
	);
	port (
		a_clock : in std_logic;
		a_address : in unsigned(logdepth - 1 downto 0);
		a_rd_data : out std_logic_vector(32 - 1 downto 0);
		a_wr_enable : in std_logic;
		a_wr_data : in std_logic_vector(32 - 1 downto 0);
		a_wr_byteenable : in std_logic_vector(3 downto 0);
		
		b_clock : in std_logic;
		b_address : in unsigned(logdepth - 1 downto 0);
		b_rd_data : out std_logic_vector(32 - 1 downto 0);
		b_wr_enable : in std_logic;
		b_wr_data : in std_logic_vector(32 - 1 downto 0);
		b_wr_byteenable : in std_logic_vector(3 downto 0)
	);
end entity;


architecture altera of SRAM32_dp is
begin
	altsyncram_component : altsyncram
	generic map (
		address_aclr_a => "NONE",
		address_aclr_b => "NONE",
		address_reg_b => "CLOCK1",
		byteena_aclr_a => "NONE",
		byte_size => 8,
		indata_aclr_a => "NONE",
		indata_aclr_b => "NONE",
		indata_reg_b => "CLOCK1",
		intended_device_family => "Cyclone",
		lpm_type => "altsyncram",
		numwords_a => 2**logdepth,
		numwords_b => 2**logdepth,
		operation_mode => "BIDIR_DUAL_PORT",
		outdata_aclr_a => "NONE",
		outdata_aclr_b => "NONE",
		outdata_reg_a => "UNREGISTERED",
		outdata_reg_b => "UNREGISTERED",
		power_up_uninitialized => "FALSE",
		widthad_a => logdepth,
		widthad_b => logdepth,
		width_a => 32,
		width_b => 32,
		width_byteena_a => 4,
		width_byteena_b => 4,
		wrcontrol_aclr_a => "NONE",
		wrcontrol_aclr_b => "NONE",
		wrcontrol_wraddress_reg_b => "CLOCK1"
	)
	port map (
		byteena_a => a_wr_byteenable,
		clock0 => a_clock,
		wren_a => a_wr_enable,
		address_a => std_logic_vector(a_address),
		data_a => a_wr_data,
		q_a => a_rd_data,
		address_b => std_logic_vector(b_address),
		clock1 => b_clock,
		data_b => b_wr_data,
		wren_b => b_wr_enable,
		q_b => b_rd_data
	);
end architecture;


