----------------------------------------------------------------------------
-- naming rule, L_ this signal is used to connecte between slave and fifo, 
-- it is internal siganl
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity slave_wrapper_dma is
    port(
            clock       : in std_ulogic;
            reset_n     : in std_ulogic;
            
            dma_clock	: in std_ulogic;
            
            ---- bus interface
            wb_in       : in wb_slave_in;
            wb_out      : out wb_slave_out;
            
            ---- fifo interface
            empty       : out std_ulogic;
            full        : out std_ulogic;
            
            data_in     : in std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
            data_out    : out std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
            --the fifo to store the intern register addr,the control and status signal is same as the master_to_uart_fifo.
            addr_out    : out std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
            
            push        : in std_ulogic;
            pop         : in std_ulogic 
        );
end slave_wrapper_dma;
    
architecture rtl of slave_wrapper_dma is 
    -- the fifo is used to store the data that from bus.
    -- the interface for fifo to slave
    signal L_data_out   : std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal L_pop        : std_ulogic;
    signal L_pop_nxt    : std_ulogic;
    signal L_empty      : std_ulogic;
    -- the interface for slave to fifo, there are to fifo, one for data, another for addr, 
    -- while the control and status signal are same for the two fifo
    signal L_push       : std_ulogic;
    signal L_push_nxt   : std_ulogic;
    signal L_full       : std_ulogic;
    signal L_data_in    : std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal L_data_in_nxt: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal L_addr_in    : std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal L_addr_in_nxt: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    
    signal L_full_dat   : std_ulogic;
    signal L_full_adr   : std_ulogic;
    signal empty_dat    : std_ulogic;
    signal empty_adr    : std_ulogic;
    
    type wb_state is ( IDLE, W_ACK, W_FINISH, R_ACK, R_FINISH);
    signal wb_ack_state             : wb_state := IDLE;
    signal wb_ack_state_nxt         : wb_state := IDLE;
     
    
begin
    -- this fifo is used to store the data from other module, like uart, and will be wroten in bus.
    fifo_to_slave_inst : asyn_fifo
    generic map(
        fifo_width => DATA_WIDTH,
        fifo_depth => FIFO_DEPTH
        )
    port map(

        reset_n		=> reset_n,
		wr_en		=> push,
		wr_clk		=> dma_clock,
		data_i		=> data_in,
		full		=> full,
		rd_en 		=> L_pop,
		rd_clk		=> clock,
		data_o 		=> L_data_out,
		empty 		=> L_empty
		
    );
    -- this two fifo is used to store the data and address from the bus, and then will be wroten in other
    -- module, like uart module.
    
    -- this fifo is used to store the data 
    slave_to_fifo_inst : asyn_fifo
    generic map(
        fifo_width => DATA_WIDTH,
        fifo_depth => FIFO_DEPTH
    )
    port map(
        
        reset_n		=> reset_n,
		wr_en		=> L_push,
		wr_clk		=> clock,
		data_i		=> L_data_in,
		full		=> L_full_dat,
		rd_en 		=> pop,
		rd_clk		=> dma_clock,
		data_o 		=> data_out,
		empty 		=> empty_dat
		
    );
    -- this fifo is used to store the addr 
    slave_to_fifo_addr_inst : asyn_fifo
    generic map(
       fifo_width => DATA_WIDTH,
       fifo_depth => FIFO_DEPTH
    )
    port map(
        
        -- the only difference of this addr fifo from the data fifo is the data_in and data_out signal,
        -- other signal is same      
        reset_n		=> reset_n,
        wr_en		=> L_push,
        wr_clk		=> clock,
        data_i		=> L_addr_in,
        full		=> L_full_adr,
        rd_en 		=> pop,
        rd_clk		=> dma_clock,
        data_o 		=> addr_out,
        empty 		=> empty_adr
        
    );
    
    --???when I used one signal connect to the two inst, a error will be taken place, nonresolved signal.
    empty <= empty_adr or empty_dat;
    L_full <= L_full_adr or L_full_dat;
    
    access_bus: process(wb_in, wb_ack_state,L_data_in,L_empty,L_pop,L_push,L_data_out,L_addr_in,L_full)
    begin
        wb_ack_state_nxt    <= wb_ack_state;
        L_pop_nxt           <= L_pop;
        L_push_nxt          <= L_push;
        L_data_in_nxt       <= L_data_in;
        L_addr_in_nxt       <= L_addr_in;
        wb_out.ack_o        <= '0'; 
        wb_out.dat_o        <= (others => '0');
        --bus write uart module
        case wb_ack_state is
            when IDLE =>
                --bus write mode
                if(wb_in.we_i = '1' and wb_in.cyc_i = '1' and wb_in.stb_i = '1') then
                    -- if the fifo is not full, then it can be wroten.
                    if(L_full = '0') then
                        wb_ack_state_nxt    <= W_ACK;
                    else
                        -- maybe there can add the busy or error signal 
                        wb_ack_state_nxt    <= IDLE;
                    end if;
                end if;
                
                --bus read mode
                if(wb_in.we_i = '0' and wb_in.cyc_i = '1' and wb_in.stb_i = '1') then
                    if(L_empty = '0') then
                        wb_ack_state_nxt    <= R_ACK;
                        L_pop_nxt           <= '1';
                    else
                        -- maybe there can add the busy or error signal 
                        wb_ack_state_nxt<= IDLE;
                    end if;
                end if;
            when W_ACK =>
                wb_out.ack_o                            <= '1';
                L_push_nxt                              <= '1';
                L_data_in_nxt                           <= wb_in.dat_i;
                L_addr_in_nxt(ADDR_WIDTH - 1 downto 0)  <= wb_in.adr_i;
                
                -- judge if it is the burst mode 
                if((wb_in.cti_i = "001" or wb_in.cti_i = "010") and wb_in.cyc_i = '1') then
                    wb_ack_state_nxt <= W_ACK;
                else
                    wb_ack_state_nxt <= W_FINISH;
                end if;
            when W_FINISH =>
                L_push_nxt          <= '0';
                wb_out.ack_o        <= '0';
                wb_ack_state_nxt    <= IDLE;
            -- bus read ankowledge
            when R_ACK  =>
                wb_out.ack_o        <= '1';
                wb_out.dat_o        <= L_data_out;
                if((wb_in.cti_i = "001" or wb_in.cti_i = "010") and wb_in.cyc_i = '1') then
                    L_pop_nxt           <= '1';
                    wb_ack_state_nxt <= R_ACK;  
                else
                    L_pop_nxt           <= '0';
					--wb_out.ack_o        <= '0';
                    wb_ack_state_nxt <= R_FINISH;
                end if;
            when R_FINISH =>
                wb_out.ack_o        <= '0';
                wb_ack_state_nxt    <= IDLE;
            when others =>
                wb_out.ack_o        <= '0';
                L_pop_nxt           <= '0';
                L_push_nxt          <= '0';
                wb_ack_state_nxt    <= IDLE;
        end case;   
    end process access_bus;
    
    register_prc : process(clock,reset_n)
    begin
        if(reset_n = '0') then
            L_pop       <= '0';
            L_push      <= '0';
            L_data_in   <= (others => '0');
            L_addr_in   <= (others => '0');
            wb_ack_state<= IDLE;
        elsif(rising_edge(clock)) then
            L_pop       <= L_pop_nxt;
            L_push      <= L_push_nxt;
            L_data_in   <= L_data_in_nxt;
            L_addr_in   <= L_addr_in_nxt;
            wb_ack_state<= wb_ack_state_nxt;    
        end if;
    end process register_prc;
end rtl;
