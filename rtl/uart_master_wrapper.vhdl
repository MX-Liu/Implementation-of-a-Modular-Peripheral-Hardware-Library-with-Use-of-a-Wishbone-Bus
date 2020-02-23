library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity uart_master_wrapper is
	port(
			clock		: in std_ulogic;
			reset_n		: in std_ulogic;
			
			---- bus interface
			wb_in		: in wb_master_in;
			wb_out		: out wb_master_out;
			
			---- fifo interface
			empty		: in std_ulogic;
			full		: in std_ulogic;
			
			data_in		: in std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			addr_in		: in std_ulogic_vector(31 downto 0);
			data_out 	: out std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			
			push 		: out std_ulogic;
			pop			: out std_ulogic;
			
			busy_o		: out std_ulogic
	
		);
end entity uart_master_wrapper;

architecture rtl of uart_master_wrapper is
	-- the fifo is used to store the data that from bus.
    -- the interface for fifo to master
	signal full_data	: std_ulogic;
	signal full_addr	: std_ulogic;
	
	signal bus_busy		: std_ulogic;
	signal wr_en		: std_ulogic;
	signal wr_en_nxt	: std_ulogic;
	signal rd_en		: std_ulogic;
	signal rd_en_nxt	: std_ulogic;
	signal reg_adr		: std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
	signal reg_adr_nxt	: std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
	signal reg_dat		: std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
	signal reg_dat_nxt	: std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
	
	type t_access_slave_state is (IDLE,W_START,R_START, SEND, RCV, W_FINISH,R_FINISH);
	signal access_slave_state 		: t_access_slave_state;
	signal access_slave_nxt			: t_access_slave_state;
	
	signal cyc_o_nxt	: std_ulogic;
	signal stb_o_nxt	: std_ulogic;
	signal we_o_nxt		: std_ulogic;
	
begin

	-- now this signal is not be used
	wb_out.sel_o	<= "1111";
	wb_out.cti_o    <= (others => '0');
	wb_out.bte_o    <= (others => '0');
	-- this process is the bus read and write state mashine
	access_slave : process(access_slave_state,wb_in,wr_en,rd_en,reg_dat,reg_adr)
	begin
	    
		
		access_slave_nxt<= access_slave_state;
		wb_out.dat_o 	<= (others => '0');
		wb_out.adr_o	<= (others => '0');
		cyc_o_nxt 		<= '0';
		stb_o_nxt 		<= '0';
		we_o_nxt  		<= '0';
		bus_busy		<= '0';
		busy_o			<= '0';
		push 			<= '0';
		data_out		<= (others => '0');
		case access_slave_state is 
			when IDLE =>
				
				if(wr_en = '1') then					
					access_slave_nxt 	<= W_START;
					bus_busy			<= '1';	
				elsif(rd_en = '1') then
					access_slave_nxt <= R_START;
					bus_busy			<= '1';
				else
					access_slave_nxt <= IDLE;
				end if;
			--write slave state mashine,the data comes from fifo_to_m_inst 
			when W_START =>
				cyc_o_nxt 		<= '1';
				stb_o_nxt 		<= '1';
				we_o_nxt  		<= '1';
				access_slave_nxt<= SEND;
				bus_busy		<= '1';
				
			when SEND =>
				cyc_o_nxt 		<= '1';
				stb_o_nxt 		<= '1';
				we_o_nxt  		<= '1';
				bus_busy		<= '1';
				wb_out.dat_o 	<= reg_dat;
				wb_out.adr_o	<= reg_adr;
				
				access_slave_nxt <= W_FINISH;
			when W_FINISH =>
				cyc_o_nxt 		<= '1';
				stb_o_nxt 		<= '1';
				we_o_nxt  		<= '1';
				bus_busy		<= '1';
				wb_out.dat_o 	<= reg_dat;
				wb_out.adr_o	<= reg_adr;
				
				if(wb_in.ack_i = '1') then
					cyc_o_nxt 		<= '0';
					stb_o_nxt 		<= '0';
					we_o_nxt  		<= '0';
					bus_busy		<= '0';
					access_slave_nxt <= IDLE;
				else
					access_slave_nxt <= W_FINISH;
					--wd_nxt_w <= wd_ctr_w + 1;
					-- wait for 100 clock cycle;
					-- if(wd_ctr_w = 99) then 
						-- wd_nxt_w <= 0;
						-- access_slave_nxt <= IDLE;
					-- end if;
				end if;
			
			--read slave state mashine, the data is wroten into fifo_to_uart_inst
			when R_START =>
				cyc_o_nxt 	<= '1';
				stb_o_nxt 	<= '1';
				we_o_nxt  	<= '0';
				bus_busy	<= '1';
				access_slave_nxt <= RCV;
			when RCV =>
				bus_busy	<= '1';
				cyc_o_nxt 	<= '1';
				stb_o_nxt 	<= '1';
				we_o_nxt  	<= '0';
				wb_out.adr_o	 	<= reg_adr;
				access_slave_nxt 	<= R_FINISH;
				
				busy_o		<= '1';
			when R_FINISH =>
				bus_busy	<= '1';
				cyc_o_nxt 	<= '1';
				stb_o_nxt 	<= '1';
				we_o_nxt  	<= '0';
				wb_out.adr_o<= reg_adr;
				busy_o		<= '1';
				if(wb_in.ack_i = '1') then
					--L_push_nxt   	<= '1';
					cyc_o_nxt 		<= '0';
					stb_o_nxt 		<= '0';
					we_o_nxt  		<= '0';
					bus_busy		<= '0';
					push 			<= '1';
					data_out		<= wb_in.dat_i;
					access_slave_nxt <= IDLE;
				else
					access_slave_nxt <= R_FINISH;
					-- wd_nxt_r <= wd_ctr_r + 1;
					-- if(wd_ctr_r = 99) then 
						-- wd_nxt_r <= 0;
						-- access_slave_nxt <= IDLE;
					-- end if;
				end if;
			when others =>
				cyc_o_nxt 		<= '0';
				stb_o_nxt 		<= '0';
				we_o_nxt  		<= '0';
				busy_o			<= '0';
				access_slave_nxt<= IDLE;
		end case;
	end process access_slave;
	
	-- push 		<= L_push;
	-- data_out	<= L_data_in;
	
	
	fetch_data : process(empty,bus_busy,data_in,addr_in, wr_en,rd_en,reg_adr,reg_dat)
	begin
		wr_en_nxt	<= wr_en;
		rd_en_nxt	<= rd_en;
		reg_adr_nxt	<= reg_adr;
		reg_dat_nxt	<= reg_dat;
		if(empty = '0' and bus_busy = '0') then
			pop 		<= '1';
			wr_en_nxt 	<= addr_in(31);
			rd_en_nxt 	<= addr_in(30);
			reg_adr_nxt	<= addr_in(ADDR_WIDTH - 1 downto 0);
			reg_dat_nxt	<= data_in(DATA_WIDTH  - 1 downto 0);
		else
			pop  		<= '0';
			wr_en_nxt 	<= '0';
			rd_en_nxt 	<= '0';
		end if;	
	end process fetch_data;
	
	register_prc : process(clock, reset_n)
	begin
		if(reset_n = '0') then
			wb_out.cyc_o	<= '0';
			wb_out.stb_o	<= '0';
			wb_out.we_o		<= '0';
			access_slave_state<= IDLE;
			
			wr_en			<= '0';
			rd_en			<= '0';
			reg_adr			<= (others => '0');
			reg_dat			<= (others => '0');
    	elsif(rising_edge(clock)) then
			wb_out.cyc_o	<= cyc_o_nxt;
			wb_out.stb_o	<= stb_o_nxt;
			wb_out.we_o		<= we_o_nxt;
			
			access_slave_state	<= access_slave_nxt;

			wr_en			<= wr_en_nxt;
			rd_en			<= rd_en_nxt;
			reg_adr			<= reg_adr_nxt;
			reg_dat			<= reg_dat_nxt;
		end if;
	end process register_prc;
end rtl;

