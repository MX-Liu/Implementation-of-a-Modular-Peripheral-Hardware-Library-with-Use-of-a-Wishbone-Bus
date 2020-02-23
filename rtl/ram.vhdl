library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity ram is
	port(
		clock 		: in std_ulogic;
		reset_n 	: in std_ulogic;
		mem_en_i    : in std_ulogic;
        mem_wr_i    : in std_ulogic;
        mem_rd_i    : in std_ulogic;
        mem_addr_i  : in std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
        mem_dat_i   : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        mem_dat_o   : out  std_ulogic_vector(DATA_WIDTH - 1 downto 0)
	);
end entity ram;

architecture rtl of ram is
	type t_ram is array (0 to 63) of std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal ram 		: t_ram;

begin

	write_process : process(clock, reset_n)
	begin
		if(reset_n = '0') then
			ram <= (others => (others => '0'));
		elsif(rising_edge(clock)) then
			ram <= ram;
			if(mem_en_i = '1' and mem_wr_i = '1') then
				ram(to_integer(unsigned(mem_addr_i))) <= mem_dat_i;
			end if;
		end if;
	end process write_process;
	
	read_process : process(reset_n, mem_en_i, mem_rd_i,mem_addr_i,ram)
	begin
		mem_dat_o <= (others=>'0');
		if(reset_n = '0') then
			mem_dat_o <= (others=>'0');
		elsif(mem_en_i = '1' and mem_rd_i = '1') then
			mem_dat_o <= ram(to_integer(unsigned(mem_addr_i)));
		end if;
	end process read_process;

end rtl;
