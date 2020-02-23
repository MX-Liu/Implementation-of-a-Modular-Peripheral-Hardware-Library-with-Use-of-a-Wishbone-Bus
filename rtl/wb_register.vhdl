----------------------------------------------------------------------------
-- naming rule, L_ this signal is used to connecte between slave and fifo, 
-- it is internal siganl
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity wb_register is
	port(
			clock		: in std_ulogic;
			reset_n		: in std_ulogic;
			
			---- bus interface
			wb_in		: in wb_slave_in;
			wb_out		: out wb_slave_out
			
		);
end entity wb_register;
	
architecture rtl of wb_register is 

	constant size 	: integer := 8;
	
	type memory_t is array (0 to size-1) of std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal mem 		: memory_t;
	signal mem_nxt	: memory_t;
	
	type wb_state is ( IDLE, W_ACK, W_FINISH, R_ACK, R_FINISH);
	signal wb_ack_state   			: wb_state := IDLE;
	signal wb_ack_state_nxt   		: wb_state := IDLE;
	
begin
	
	access_bus: process(wb_in, wb_ack_state,mem)
    begin
		wb_ack_state_nxt 	<= wb_ack_state;
		wb_out.ack_o 		<= '0';	
		mem_nxt			 	<= mem;
		wb_out.dat_o		<= (others => '0');
    	--bus write 
		case wb_ack_state is
			when IDLE =>
				--bus write mode
				if(wb_in.we_i = '1' and wb_in.cyc_i = '1' and wb_in.stb_i = '1') then
					wb_ack_state_nxt 	<= W_ACK;
				end if;
				
				--bus read mode
				if(wb_in.we_i = '0' and wb_in.cyc_i = '1' and wb_in.stb_i = '1') then
					wb_ack_state_nxt 	<= R_ACK;
				end if;
				
			when W_ACK =>
				wb_out.ack_o <= '1';
				mem_nxt(to_integer(unsigned(wb_in.adr_i(MODULE_REG_ADDR_WIDTH - 1 downto 0))))	<= wb_in.dat_i;
				if(wb_in.cti_i = "001" or wb_in.cti_i = "010") then
					wb_ack_state_nxt <= W_ACK;
				else
					wb_ack_state_nxt <= W_FINISH;
				end if;
			when W_FINISH =>
    			wb_out.ack_o		<= '0';
				wb_ack_state_nxt 	<= IDLE;
				
			-- bus read ankowledge
			when R_ACK	=>
				wb_out.ack_o   		<= '1';
				wb_out.dat_o		<= mem(to_integer(unsigned(wb_in.adr_i(MODULE_REG_ADDR_WIDTH - 1 downto 0))));
				if(wb_in.cti_i = "001" or wb_in.cti_i = "010") then
					wb_ack_state_nxt <= R_ACK;
				else
					wb_ack_state_nxt <= R_FINISH;
				end if;
			when R_FINISH =>
				wb_out.ack_o   		<= '0';
				wb_ack_state_nxt 	<= IDLE;
			--coverage off
			when others =>
				wb_out.ack_o   		<= '0';
				wb_ack_state_nxt 	<= IDLE;
			--coverage on
		end case;	
    end process access_bus;
	
	register_prc : process(clock,reset_n)
    begin
		if(reset_n = '0') then
			mem <= (others =>(others => '0'));
			wb_ack_state<= IDLE;
    	elsif(rising_edge(clock)) then
			mem <= mem_nxt;
			wb_ack_state<= wb_ack_state_nxt;	
		end if;
	end process register_prc;
end rtl;
