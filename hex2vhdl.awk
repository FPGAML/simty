#!/usr/bin/awk -f
BEGIN {
print "library ieee;";
print "use ieee.std_logic_1164.all;";
print "";
print "entity Instruction_ROM is";
print "	port (";
print "		clock : in std_logic;";
print "		addr : in std_logic_vector(7 downto 0);";
print "		data : out std_logic_vector(31 downto 0)";
print "	);";
print "end entity;";
print "";
print "architecture structural of Instruction_ROM is";
print "	signal addr_1 : std_logic_vector(7 downto 0);";
print "begin";
print "	process(clock)";
print "	begin";
print "		if rising_edge(clock) then";
#print "			addr_1 <= addr;";
print "			case addr is";
}
{
printf "\t\t\t\twhen X\"%02x\" => data <= X\"%s\";\n", NR-1, $1;
#print "	with addr_1 select data <=";
#printf "\t\tX\"%s\" when X\"%02x\",\n", $1, NR-1;
}
END {
print "				when others => data <= (others => '-');";
print "			end case;";
print "		end if;";
print "	end process;";
#print "		X\"--------\" when others;";
print "end architecture;";
}

