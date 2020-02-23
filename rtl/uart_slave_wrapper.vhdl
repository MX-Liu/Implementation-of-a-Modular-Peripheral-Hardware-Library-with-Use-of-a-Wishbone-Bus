library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity uart_slave_wrapper is
	port(
			clock		: in std_ulogic;
			reset_n		: in std_ulogic;
			
			---- bus interface
			wb_in		: in wb_slave_in;
			wb_out		: out wb_slave_out;
			
			---- fifo interface
			full		: in std_ulogic;
			data_out	: out std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			push 		: out std_ulogic;
			fifo_busy	: in std_ulogic
		);
end uart_slave_wrapper;
	
architecture rtl of uart_slave_wrapper is 
	
	type wb_state is ( IDLE, W_ACK, W_FINISH, R_ACK, R_FINISH);
	signal wb_ack_state   			: wb_state := IDLE;
	signal wb_ack_state_nxt   		: wb_state := IDLE;
	
begin
	
	access_bus: process(wb_in, wb_ack_state,full,fifo_busy)
    begin
		wb_ack_state_nxt 	<= wb_ack_state;
		wb_out.ack_o 		<= '0';	
		wb_out.dat_o		<= (others => '0');
		push				<= '0';
		data_out			<= (others => '0');
    	--bus write uart module
		case wb_ack_state is
			when IDLE =>
				--bus write mode
				if(wb_in.we_i = '1' and wb_in.cyc_i = '1' and wb_in.stb_i = '1') then
				--if(wb_in.we_i = '1' and wb_in.cyc_i = '1') then
					-- if the fifo is not full, then it can be wroten.
					if(full = '0') then
						wb_ack_state_nxt 	<= W_ACK;
						wb_out.ack_o     	<= '0';
					-- coverage off
					else
						-- maybe there can add the busy or error signal 
						wb_ack_state_nxt 	<= IDLE;
						wb_out.ack_o     	<= '0';
					end if;
					-- coverage on
				end if;
				
				
				--bus read mode
				if(wb_in.we_i = '0' and wb_in.cyc_i = '1' and wb_in.stb_i = '1') then
					--if(L_empty = '0') then
						wb_ack_state_nxt 	<= R_ACK;
						wb_out.ack_o    	<= '0';
					--else
						-- maybe there can add the busy or error signal 
					--	wb_ack_state_nxt<= IDLE;
					--	wb_out.ack_o	<= '0';
					--end if;
				end if;
			when W_ACK =>
				if(fifo_busy = '0') then
					wb_out.ack_o	<= '1';
					push			<= '1';
					data_out 		<= wb_in.dat_i;
					wb_ack_state_nxt<= W_FINISH;
				else
					wb_ack_state_nxt <= W_ACK;
				end if;
			when W_FINISH =>
    			wb_out.ack_o		<= '0';
				wb_ack_state_nxt 	<= IDLE;
			-- bus read ankowledge
			when R_ACK	=>
				wb_out.ack_o   		<= '1';
				wb_out.dat_o(31 downto 0)		<= x"55555555"; -- now the uart slave can not be read
				wb_ack_state_nxt <= R_FINISH;
			when R_FINISH =>
				wb_out.ack_o   		<= '0';
				wb_ack_state_nxt 	<= IDLE;
			-- coverage off
			when others =>
				wb_out.ack_o   		<= '0';
				wb_ack_state_nxt 	<= IDLE;
			-- coverage on
		end case;	
    end process access_bus;
	
	register_prc : process(clock,reset_n)
    begin
		if(reset_n = '0') then
			wb_ack_state<= IDLE;
    	elsif(rising_edge(clock)) then
			wb_ack_state<= wb_ack_state_nxt;	
		end if;
	end process register_prc;
end rtl;
