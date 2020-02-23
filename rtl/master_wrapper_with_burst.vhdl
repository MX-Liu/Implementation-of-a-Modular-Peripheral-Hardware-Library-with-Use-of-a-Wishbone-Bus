library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity master_wrapper_with_burst is
	port(
			clock		: in std_ulogic;
			reset_n		: in std_ulogic;
			
			---- bus interface
			wb_in		: in wb_master_in;
			wb_out		: out wb_master_out;
			
			---- fifo interface
			empty		: out std_ulogic;
			full		: out std_ulogic;
			
			data_in		: in std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			addr_in 	: in std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			data_out 	: out std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			
			push 		: in std_ulogic;
			pop			: in std_ulogic
	
		);
end entity master_wrapper_with_burst;

architecture rtl of master_wrapper_with_burst is
	-- the fifo is used to store the data that from bus.
    -- the interface for fifo to master
	signal L_data_out	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal L_addr_out	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal L_pop		: std_ulogic;
	signal L_pop_nxt	: std_ulogic;
	signal L_empty		: std_ulogic;
	-- the interface for master to fifo
	signal L_data_in	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal L_data_in_nxt: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal L_push		: std_ulogic;
	signal L_push_nxt	: std_ulogic;
	signal L_full		: std_ulogic;
	
	signal L_empty_data : std_ulogic;
	signal L_empty_addr : std_ulogic;
	
	signal full_data	: std_ulogic;
	signal full_addr	: std_ulogic;
	
	type t_access_slave_state is (IDLE,W_START,R_START, SEND, RCV, W_FINISH,R_FINISH);
	signal access_slave_state 		: t_access_slave_state;
	signal access_slave_nxt			: t_access_slave_state;
	
	signal cyc_o_nxt	: std_ulogic;
	signal stb_o_nxt	: std_ulogic;
	signal we_o_nxt		: std_ulogic;
	
	signal bus_busy		: std_ulogic;
	signal wr_en		: std_ulogic;
	signal wr_en_nxt	: std_ulogic;
	signal rd_en		: std_ulogic;
	signal rd_en_nxt	: std_ulogic;
	signal reg_adr		: std_ulogic_vector(31 downto 0);
	signal reg_adr_nxt	: std_ulogic_vector(31 downto 0);
	signal reg_dat		: std_ulogic_vector(31 downto 0);
	signal reg_dat_nxt	: std_ulogic_vector(31 downto 0);
	
	signal burst_cnt	: std_ulogic_vector(2 downto 0);
	signal burst_cnt_nxt: std_ulogic_vector(2 downto 0);
	
begin
	fifo_to_m_data_inst : fifo
		generic map(
			fifo_width => DATA_WIDTH,
			fifo_depth => FIFO_DEPTH
		)
		port map(
			clock	=> clock,
			reset_n	=> reset_n,
			
			data_in	=> data_in,
			data_out=> L_data_out,
			
			empty	=> L_empty_data,
			full	=> full_data,
			
			pop		=> L_pop,
			push	=> push
		);
		
	fifo_to_m_addr_inst : fifo
		generic map(
			fifo_width => DATA_WIDTH,
			fifo_depth => FIFO_DEPTH
		)
		port map(
			clock	=> clock,
			reset_n	=> reset_n,
			
			data_in	=> addr_in,
			data_out=> L_addr_out,
			
			empty	=> L_empty_addr,
			full	=> full_addr,
			
			pop		=> L_pop,
			push	=> push
		);
		
		L_empty 	<= L_empty_data or L_empty_addr;
		full 		<= full_data	or full_addr;
		
		
	fifo_to_peri_inst : fifo
		generic map(
			fifo_width => DATA_WIDTH,
			fifo_depth => FIFO_DEPTH
		)
		port map(
			clock	=> clock,
			reset_n	=> reset_n,
			
			data_in	=> L_data_in,
			data_out=> data_out,
			
			empty	=> empty,
			full	=> L_full,
			
			pop		=> pop,
			push	=> L_push
		);
	-- now this signal is not be used
	-- wb_out.sel_o	<= "1111";
	--~ wb_out.cti_o    <= (others => '0');
	--~ wb_out.bte_o    <= (others => '0');
	-- this process is the bus read and write state mashine
	access_slave : process(access_slave_state,wb_in,wr_en,rd_en,reg_dat,reg_adr,L_empty,burst_cnt)
	begin

		access_slave_nxt<= access_slave_state;
		wb_out.dat_o 	<= (others => '0');
		wb_out.adr_o	<= (others => '0');
		wb_out.sel_o	<= (others => '0');
		wb_out.cti_o    <= (others => '0');
		wb_out.bte_o    <= (others => '0');
		cyc_o_nxt 		<= '0';
		stb_o_nxt 		<= '0';
		we_o_nxt  		<= '0';
		bus_busy		<= '0';
		L_push 			<= '0';
		L_data_in		<= (others => '0');
		burst_cnt_nxt	<= burst_cnt;
		
		case access_slave_state is 
			when IDLE =>
				
				if(wr_en = '1') then					
					access_slave_nxt 	<= W_START;
					bus_busy			<= '1';	
				elsif(rd_en = '1') then
					access_slave_nxt 	<= R_START;
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
				wb_out.adr_o	<= reg_adr(ADDR_WIDTH - 1 downto 0);
				wb_out.cti_o    <= reg_adr(29 downto 27);
				wb_out.bte_o    <= reg_adr(26 downto 25);
				wb_out.sel_o	<= reg_adr(24 downto 21);
				
				access_slave_nxt <= W_FINISH;
			when W_FINISH =>
				cyc_o_nxt 		<= '1';
				stb_o_nxt 		<= '1';
				we_o_nxt  		<= '1';
				bus_busy		<= '1';
				wb_out.dat_o 	<= reg_dat;
				wb_out.adr_o	<= reg_adr(ADDR_WIDTH - 1 downto 0);
				wb_out.cti_o    <= reg_adr(29 downto 27);
				wb_out.bte_o    <= reg_adr(26 downto 25);
				wb_out.sel_o	<= reg_adr(24 downto 21);
				if(wb_in.ack_i = '1') then
					bus_busy		<= '0';
					if(reg_adr(29 downto 27) = b"001" or reg_adr(29 downto 27) = b"010") then  -- burst mode
						access_slave_nxt <= W_FINISH;
						
						
					else
						cyc_o_nxt 		<= '0';
						stb_o_nxt 		<= '0';
						we_o_nxt  		<= '0';
						access_slave_nxt <= IDLE;
					end if;
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
				wb_out.adr_o<= reg_adr(ADDR_WIDTH - 1 downto 0);
				wb_out.cti_o    <= reg_adr(29 downto 27);
				wb_out.bte_o    <= reg_adr(26 downto 25);
				wb_out.sel_o	<= reg_adr(24 downto 21);
				
				access_slave_nxt 	<= R_FINISH;
			when R_FINISH =>
				bus_busy	<= '1';
				cyc_o_nxt 	<= '1';
				stb_o_nxt 	<= '1';
				we_o_nxt  	<= '0';
				
				if(burst_cnt = "111") then
					wb_out.cti_o <= "000";
				else
					wb_out.cti_o <= reg_adr(29 downto 27);
				end if;
				
				wb_out.bte_o    <= reg_adr(26 downto 25);
				wb_out.sel_o	<= reg_adr(24 downto 21);
				wb_out.adr_o<= reg_adr(ADDR_WIDTH - 1 downto 0);
				if(wb_in.ack_i = '1') then
					L_push 			<= '1';
					L_data_in		<= wb_in.dat_i;
					if(reg_adr(29 downto 27) = b"001" or reg_adr(29 downto 27) = b"010") then  -- burst mode
						burst_cnt_nxt	<= std_ulogic_vector(unsigned(burst_cnt)+1);
						if(burst_cnt = "111") then
							access_slave_nxt <= IDLE;
							cyc_o_nxt 		<= '0';
							stb_o_nxt 		<= '0';
							we_o_nxt  		<= '0';
							bus_busy		<= '0';
						else
							access_slave_nxt <= R_FINISH;
							bus_busy		<= '1';
						end if;
					else
						bus_busy		<= '0';
						cyc_o_nxt 		<= '0';
						stb_o_nxt 		<= '0';
						we_o_nxt  		<= '0';
						access_slave_nxt <= IDLE;
					end if;
				else
					access_slave_nxt <= R_FINISH;
					
					-- wd_nxt_r <= wd_ctr_r + 1;
					-- if(wd_ctr_r = 99) then 
						-- wd_nxt_r <= 0;
						-- access_slave_nxt <= IDLE;
					-- end if;
				end if;
			--coverage off
			when others =>
				cyc_o_nxt 		<= '0';
				stb_o_nxt 		<= '0';
				we_o_nxt  		<= '0';
				bus_busy		<= '0';
				access_slave_nxt<= IDLE;
			--coverage on
		end case;
	end process access_slave;
	
	fetch_data : process(L_empty,L_full, bus_busy,L_data_out,L_addr_out, wr_en,rd_en,reg_adr,reg_dat)
	begin
		wr_en_nxt	<= wr_en;
		rd_en_nxt	<= rd_en;
		reg_adr_nxt	<= reg_adr;
		reg_dat_nxt	<= reg_dat;
		if(L_empty = '0' and bus_busy = '0') then
			L_pop 		<= '1';
			wr_en_nxt 	<= L_addr_out(31);
			rd_en_nxt 	<= L_addr_out(30) and not L_full;
			reg_adr_nxt	<= L_addr_out;
			reg_dat_nxt	<= L_data_out;
		else
			L_pop  		<= '0';
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
			burst_cnt		<= (others => '0');
			
    	elsif(rising_edge(clock)) then
			wb_out.cyc_o	<= cyc_o_nxt;
			wb_out.stb_o	<= stb_o_nxt;
			wb_out.we_o		<= we_o_nxt;
			access_slave_state	<= access_slave_nxt;	
			
			wr_en			<= wr_en_nxt;
			rd_en			<= rd_en_nxt;
			reg_adr			<= reg_adr_nxt;
			reg_dat			<= reg_dat_nxt;
			burst_cnt		<= burst_cnt_nxt;
		end if;
	end process register_prc;
end rtl;



--~ library ieee;
--~ use ieee.std_logic_1164.all;
--~ use ieee.numeric_std.all;
--~ use work.wb_type.all;

--~ entity master_wrapper_with_burst is
	--~ port(
			--~ clock		: in std_ulogic;
			--~ reset_n		: in std_ulogic;
			
			--~ ---- bus interface
			--~ wb_in		: in wb_master_in;
			--~ wb_out		: out wb_master_out;
			
			--~ ---- fifo interface
			--~ empty		: out std_ulogic;
			--~ full		: out std_ulogic;
			
			--~ data_in		: in std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			--~ addr_in 	: in std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			--~ data_out 	: out std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			
	
			--~ push 		: in std_ulogic;
			--~ pop			: in std_ulogic;
	
			--~ -- simulation
			--~ wr_en		: in std_ulogic;
			--~ rd_en		: in std_ulogic
		--~ );
--~ end entity master_wrapper_with_burst;

--~ architecture rtl of master_wrapper_with_burst is
	--~ -- the fifo is used to store the data that from bus.
    --~ -- the interface for fifo to master
	--~ signal L_data_out	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	--~ signal L_addr_out	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	--~ signal L_pop		: std_ulogic;
	--~ signal L_pop_nxt	: std_ulogic;
	--~ signal L_empty		: std_ulogic;
	--~ -- the interface for master to fifo
	--~ signal L_data_in	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	--~ signal L_data_in_nxt: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	--~ signal L_push		: std_ulogic;
	--~ signal L_push_nxt	: std_ulogic;
	--~ signal L_full		: std_ulogic;
	
	--~ signal L_empty_data : std_ulogic;
	--~ signal L_empty_addr : std_ulogic;
	
	--~ signal full_data	: std_ulogic;
	--~ signal full_addr	: std_ulogic;
	
	--~ type t_access_slave_state is (IDLE,START, SEND, RCV, W_FINISH,R_FINISH);
	--~ signal access_slave_state 		: t_access_slave_state;
	--~ signal access_slave_nxt			: t_access_slave_state;
	
	--~ signal cyc_o_nxt	: std_ulogic;
	--~ signal stb_o_nxt	: std_ulogic;
	--~ signal we_o_nxt		: std_ulogic;
	
	--~ signal cti_o_nxt	: std_ulogic_vector(2 downto 0);
	--~ signal bte_o_nxt	: std_ulogic_vector(1 downto 0);
	--~ signal sel_o_nxt	: std_ulogic_vector(3 downto 0);
	--~ signal reg_addr 	: std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
	--~ signal reg_addr_nxt : std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
	--~ signal burst_mode	: std_ulogic;
	--~ signal burst_nxt		: std_ulogic;
--~ begin
	--~ fifo_to_m_data_inst : fifo
		--~ generic map(
			--~ fifo_width => 32,
			--~ fifo_depth => 8
		--~ )
		--~ port map(
			--~ clock	=> clock,
			--~ reset_n	=> reset_n,
			
			--~ data_in	=> data_in,
			--~ data_out=> L_data_out,
			
			--~ empty	=> L_empty_data,
			--~ full	=> full_data,
			
			--~ pop		=> L_pop,
			--~ push	=> push
		--~ );
		
	--~ fifo_to_m_addr_inst : fifo
		--~ generic map(
			--~ fifo_width => 32,
			--~ fifo_depth => 8
		--~ )
		--~ port map(
			--~ clock	=> clock,
			--~ reset_n	=> reset_n,
			
			--~ data_in	=> addr_in,
			--~ data_out=> L_addr_out,
			
			--~ empty	=> L_empty_addr,
			--~ full	=> full_addr,
			
			--~ pop		=> L_pop,
			--~ push	=> push
		--~ );
		
		--~ L_empty 	<= L_empty_data or L_empty_addr;
		--~ full 		<= full_data	or full_addr;
		
		
	--~ fifo_to_uart_inst : fifo
		--~ generic map(
			--~ fifo_width => 32,
			--~ fifo_depth => 8
		--~ )
		--~ port map(
			--~ clock	=> clock,
			--~ reset_n	=> reset_n,
			
			--~ data_in	=> L_data_in,
			--~ data_out=> data_out,
			
			--~ empty	=> empty,
			--~ full	=> L_full,
			
			--~ pop		=> pop,
			--~ push	=> L_push
		--~ );
	

	--~ -- this process is the bus read and write state mashine
	--~ access_slave : process(L_empty,L_full,L_pop,L_push, access_slave_state,L_data_out,wb_in,wr_en,L_data_in,rd_en,L_addr_out,reg_addr,burst_mode)
	--~ begin
	    --~ -- because the out port can not be read
		
		
		
		--~ L_data_in_nxt 		<= L_data_in;
		--~ reg_addr_nxt		<= reg_addr; -- to reserve the address, which is used for burst_mode
		--~ burst_nxt			<= burst_mode;
		--~ access_slave_nxt  	<= access_slave_state;
		--~ wb_out.dat_o 		<= (others => '0');
		--~ wb_out.adr_o		<= (others => '0');
		--~ wb_out.cti_o    	<= (others => '0');
		--~ wb_out.bte_o    	<= (others => '0');
		--~ wb_out.sel_o		<= (others => '0');
		--~ cyc_o_nxt 			<= '0';
		--~ stb_o_nxt 			<= '0';
		--~ we_o_nxt  			<= '0';
		--~ L_push_nxt			<= '0';
		--~ L_pop_nxt			<= '0';
	
		--~ case access_slave_state is 
			--~ when IDLE =>
				--~ --fetch the data from fifo
				--~ if (L_empty = '0') then
					--~ L_pop_nxt 		 <= '1';
					--~ access_slave_nxt <= START;
				--~ else
					--~ access_slave_nxt <= IDLE;
				--~ end if;
			
			--~ --write slave state mashine,the data comes from fifo_to_m_inst 
			--~ when START =>
				--~ L_pop_nxt 		<= '0';
				--~ wb_out.dat_o 	<= L_data_out;
				--~ wb_out.cti_o    <= L_addr_out(29 downto 27);
				--~ wb_out.bte_o    <= L_addr_out(26 downto 25);
				--~ wb_out.sel_o	<= L_addr_out(24 downto 21);
				--~ wb_out.adr_o	<= L_addr_out(ADDR_WIDTH - 1 downto 0);
				--~ reg_addr_nxt	<= L_addr_out(ADDR_WIDTH - 1 downto 0);
				--~ if(L_addr_out(31) = '1') then 
					--~ cyc_o_nxt 		<= '1';
					--~ stb_o_nxt 		<= '1';
					--~ we_o_nxt  		<= '1';
					--~ access_slave_nxt<= SEND;
				--~ elsif(L_addr_out(30) = '1') then 
					--~ cyc_o_nxt 		<= '1';
					--~ stb_o_nxt 		<= '1';
					--~ we_o_nxt  		<= '0';
					--~ access_slave_nxt<= RCV;
				--~ else
					--~ access_slave_nxt <= IDLE;
				--~ end if;
					
			--~ when SEND =>
				--~ cyc_o_nxt 		<= '1';
				--~ stb_o_nxt 		<= '1';
				--~ we_o_nxt  		<= '1';
				--~ wb_out.dat_o 	<= L_data_out;
				--~ wb_out.cti_o    <= L_addr_out(29 downto 27);
				--~ wb_out.bte_o    <= L_addr_out(26 downto 25);
				--~ wb_out.sel_o	<= L_addr_out(24 downto 21);
				--~ L_pop_nxt 		<= '0';
				--~ access_slave_nxt<= W_FINISH;
				
				--~ if(L_addr_out(29 downto 27) = b"001" or L_addr_out(29 downto 27) = b"010") then -- constant address burst mode
					--~ burst_nxt		<= '1';
				--~ else
					--~ burst_nxt		<= '0';
				--~ end if;
				
				--~ if(burst_mode = '1') then
					--~ wb_out.adr_o 	 <= reg_addr;
					--~ access_slave_nxt <= SEND;
					--~ if(wb_in.ack_i = '1') then
						--~ if(L_addr_out(29 downto 27) = b"001") then 
							--~ L_pop_nxt 		<= '1';	
						--~ elsif ( L_addr_out(29 downto 27) = b"010") then
							--~ L_pop_nxt 		<= '1';	
							--~ reg_addr_nxt	<= std_ulogic_vector(unsigned(reg_addr) + 1);
						--~ else
							--~ access_slave_nxt <= IDLE;
							--~ cyc_o_nxt 		<= '0';
							--~ stb_o_nxt 		<= '0';
							--~ we_o_nxt  		<= '0';
						--~ end if;
					--~ end if;
				--~ else
					--~ wb_out.adr_o	<= L_addr_out(ADDR_WIDTH - 1 downto 0);
					--~ reg_addr_nxt	<= L_addr_out(ADDR_WIDTH - 1 downto 0);
				--~ end if;
				
			--~ when W_FINISH =>
				--~ cyc_o_nxt 		<= '1';
				--~ stb_o_nxt 		<= '1';
				--~ we_o_nxt  		<= '1';
				--~ wb_out.dat_o 	<= L_data_out;
				--~ wb_out.cti_o    <= L_addr_out(29 downto 27);
				--~ wb_out.bte_o    <= L_addr_out(26 downto 25);
				--~ wb_out.sel_o	<= L_addr_out(24 downto 21);
				--~ wb_out.adr_o    <= L_addr_out(ADDR_WIDTH - 1 downto 0);
				--~ if(wb_in.ack_i = '1') then
					
					--~ if(burst_mode = '1' and L_empty = '0') then
						--~ access_slave_nxt <= SEND;
						--~ L_pop_nxt 		<= '1';
						--~ if ( L_addr_out(29 downto 27) = b"010") then
							--~ reg_addr_nxt	<= std_ulogic_vector(unsigned(reg_addr) + 1);
						--~ end if;
					--~ else
						--~ access_slave_nxt <= IDLE;
						--~ cyc_o_nxt 		<= '0';
						--~ stb_o_nxt 		<= '0';
						--~ we_o_nxt  		<= '0';
					--~ end if;
				--~ else
					--~ access_slave_nxt <= W_FINISH;
				--~ end if;
			
			--~ --read slave state mashine, the data is wroten into fifo_to_uart_inst
			--~ when RCV =>
				--~ cyc_o_nxt 		<= '1';
				--~ stb_o_nxt 		<= '1';
				--~ we_o_nxt  		<= '0';
				--~ L_pop_nxt 		<= '0';
				--~ wb_out.cti_o    <= L_addr_out(29 downto 27);
				--~ wb_out.bte_o    <= L_addr_out(26 downto 25);
				--~ wb_out.sel_o	<= L_addr_out(24 downto 21);
				--~ access_slave_nxt <= R_FINISH;
				--~ --wb_out.adr_o	<= L_addr_out(4 downto 0);
				
				--~ if(L_addr_out(29 downto 27) = b"001" or L_addr_out(29 downto 27) = b"010") then -- constant address burst mode
					--~ burst_nxt		<= '1';
				--~ else
					--~ burst_nxt		<= '0';
				--~ end if;
				
				--~ if(burst_mode = '1') then
					--~ wb_out.adr_o 	 <= reg_addr;
					--~ access_slave_nxt <= RCV;
					--~ if(wb_in.ack_i = '1') then
						--~ if(L_addr_out(29 downto 27) = b"001") then 
							--~ L_pop_nxt 		<= '1';	
						--~ elsif ( L_addr_out(29 downto 27) = b"010") then
							--~ L_pop_nxt 		<= '1';	
							--~ reg_addr_nxt	<= std_ulogic_vector(unsigned(reg_addr) + 1);
						--~ else
							--~ access_slave_nxt <= IDLE;
							--~ cyc_o_nxt 		<= '0';
							--~ stb_o_nxt 		<= '0';
							--~ we_o_nxt  		<= '0';
						--~ end if;
					--~ end if;
				--~ else
					--~ wb_out.adr_o	<= L_addr_out(ADDR_WIDTH - 1 downto 0);
					--~ reg_addr_nxt	<= L_addr_out(ADDR_WIDTH - 1 downto 0);
				--~ end if;
				
			--~ when R_FINISH =>
				--~ cyc_o_nxt 		<= '1';
				--~ stb_o_nxt 		<= '1';
				--~ we_o_nxt  		<= '0';
				--~ L_push_nxt  	<= '0';
				--~ wb_out.cti_o    <= L_addr_out(29 downto 27);
				--~ wb_out.bte_o    <= L_addr_out(26 downto 25);
				--~ wb_out.sel_o	<= L_addr_out(24 downto 21);
				--~ wb_out.adr_o	<= L_addr_out(ADDR_WIDTH - 1 downto 0); 
				
				--~ if(wb_in.ack_i = '1') then
					--~ L_push_nxt 		<= '1';
					--~ L_data_in_nxt	<= wb_in.dat_i;
					
					--~ if(burst_mode = '1' and L_empty = '0') then
						--~ access_slave_nxt <= RCV;
						--~ L_pop_nxt 		<= '1';
						--~ if ( L_addr_out(29 downto 27) = b"010") then
							--~ reg_addr_nxt	<= std_ulogic_vector(unsigned(reg_addr) + 1);
						--~ end if;
					--~ else
						--~ access_slave_nxt <= IDLE;
						--~ cyc_o_nxt 		<= '0';
						--~ stb_o_nxt 		<= '0';
						--~ we_o_nxt  		<= '0';
						
					--~ end if;
				--~ else
					--~ access_slave_nxt <= W_FINISH;
				--~ end if;
					
			--~ when others =>
				--~ cyc_o_nxt 		<= '0';
				--~ stb_o_nxt 		<= '0';
				--~ we_o_nxt  		<= '0';
				--~ L_push_nxt   	<= '0';
				--~ L_pop_nxt		<= '0';
				--~ access_slave_nxt<= IDLE;
		--~ end case;
	--~ end process access_slave;
	
	--~ register_prc : process(clock, reset_n)
	--~ begin
		--~ if(reset_n = '0') then
			--~ wb_out.cyc_o	<= '0';
			--~ wb_out.stb_o	<= '0';
			--~ wb_out.we_o		<= '0';
			--~ L_push		   	<= '0';
			--~ L_pop			<= '0';
			--~ L_data_in		<= (others => '0');
			--~ reg_addr		<= (others => '0');
			--~ burst_mode		<= '0';
			--~ access_slave_state<= IDLE;	
    	--~ elsif(rising_edge(clock)) then
			--~ wb_out.cyc_o	<= cyc_o_nxt;
			--~ wb_out.stb_o	<= stb_o_nxt;
			--~ wb_out.we_o		<= we_o_nxt;
			
			--~ L_push		   	<= L_push_nxt;
			--~ L_pop			<= L_pop_nxt;
			--~ L_data_in		<= L_data_in_nxt;
			
			--~ reg_addr		<= reg_addr_nxt;
			--~ burst_mode		<= burst_nxt;
			
			--~ access_slave_state	<= access_slave_nxt;	
		--~ end if;
	--~ end process register_prc;
--~ end rtl;

