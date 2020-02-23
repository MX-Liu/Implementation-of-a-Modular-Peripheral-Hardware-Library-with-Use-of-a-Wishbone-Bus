library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity timer is 
	port(
		clock		: in std_ulogic;
		reset_n		: in std_ulogic;
		
		wb_in		: in wb_slave_in;
		wb_out		: out wb_master_out;
		
		-- clock generator --
		clkgen_en_o : out std_ulogic; -- enable clock generator
		clkgen_i    : in  std_ulogic_vector(07 downto 0);
    
		irq_o		: out std_ulogic
	);
end entity timer;

architecture rtl of timer is 

	type wb_state is ( IDLE, W_ACK, W_FINISH, R_ACK, R_FINISH);
	signal wb_ack_state   			: wb_state := IDLE;
	signal wb_ack_state_nxt   		: wb_state := IDLE;
	
	signal ctrl_reg					: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal ctrl_reg_nxt				: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	
	signal data_in					: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal data_in_nxt				: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal addr_in 					: std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
	signal addr_in_nxt				: std_ulogic_vector(ADDR_WIDTH - 1 downto 0);

begin
	
	-- timer clock select --
	prsc_tick <= clkgen_i(to_integer(unsigned(ctrl(ctrl_prsc2_bit_c downto ctrl_prsc0_bit_c))));

	-- enable external clock generator --
	clkgen_en_o <= ctrl(ctrl_en_bit_c);
  
	access_bus: process(wb_in, wb_ack_state, addr_in, data_in)
    begin
		wb_ack_state_nxt 	<= wb_ack_state;
		wb_out.ack_o 		<= '0';	
		wb_out.dat_o		<= (others => '0');
		addr_in_nxt			<= addr_in;
		data_in_nxt			<= data_in;
    	--bus write uart module
		case wb_ack_state is
			when IDLE =>
				wb_ack_state_nxt<= IDLE;
				wb_out.ack_o	<= '0';
				--bus write mode
				if(wb_in.we_i = '1' and wb_in.cyc_i = '1' and wb_in.stb_i = '1') then
					wb_ack_state_nxt 	<= W_ACK;
					wb_out.ack_o     	<= '0';
				end if;
				--bus read mode
				if(wb_in.we_i = '0' and wb_in.cyc_i = '1' and wb_in.stb_i = '1') then
					wb_ack_state_nxt 	<= R_ACK;
					wb_out.ack_o    	<= '0';					
				end if;

			when W_ACK =>
				data_in_nxt 							<= wb_in.dat_i;
				data_in_nxt(ADDR_WIDTH - 1 downto 0)	<= wb_in.adr_i;
				wb_ack_state_nxt <= W_FINISH;
			when W_FINISH =>
				wb_out.ack_o		<= '0';
				wb_ack_state_nxt 	<= IDLE;
			-- bus read ankowledge
			when R_ACK	=>
				wb_out.ack_o   		<= '1';
				wb_out.dat_o		<= L_data_out;
				wb_ack_state_nxt 	<= R_FINISH;
			when R_FINISH =>
				wb_out.ack_o   		<= '0';
				wb_ack_state_nxt 	<= IDLE;
			when others =>
				wb_out.ack_o   		<= '0';
				wb_ack_state_nxt 	<= IDLE;
		end case;	
    end process access_bus;
    
    

end rtl;
