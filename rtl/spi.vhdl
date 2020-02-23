library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity spi is
    port (
        -- host access --
        clock       : in  std_ulogic; -- global clock line
        reset_n 	: in  std_ulogic;
        
        -- fifo interface
        full        : in  std_ulogic;
        empty       : in  std_ulogic;
        push        : out std_ulogic;
        pop         : out std_ulogic;
        data_in     : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        addr_in     : in  std_ulogic_vector(31 downto 0);
        data_out    : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
            
        -- clock generator --
        clkgen_en_o : out std_ulogic; -- enable clock generator
        clkgen_i    : in  std_ulogic_vector(07 downto 0);
        -- com lines --
        spi_irq_o	: out std_ulogic;
        spi_sclk_o  : out std_ulogic; -- SPI serial clock
        spi_mosi_o  : out std_ulogic; -- SPI master out, slave in
        spi_miso_i  : in  std_ulogic; -- SPI master in, slave out
        spi_cs_o    : out std_ulogic_vector(07 downto 0)
    );
end spi;

architecture neo430_spi_rtl of spi is

	

-- control reg bits --
	constant data_reg_c         : std_ulogic_vector := "010";
    constant control_reg_c      : std_ulogic_vector := "001";
    
    constant spi_en_c   	 	: integer :=  0; -- r/w: spi enable
    constant spi_ie_c  	    	: integer :=  1; -- r/w: spi transmission done interrupt enable
    constant spi_cpha_c		  	: integer :=  2; -- r/w: spi clock phase
    constant spi_prsc0_c   		: integer :=  3; -- r/w: spi prescaler select bit 0
    constant spi_prsc1_c   		: integer :=  4; -- r/w: spi prescaler select bit 1
    constant spi_prsc2_c   		: integer :=  5; -- r/w: spi prescaler select bit 2
    constant spi_cs_sel0_c 		: integer :=  6; -- r/w: spi CS select bit 0
    constant spi_cs_sel1_c 		: integer :=  7; -- r/w: spi CS select bit 0
    constant spi_cs_sel2_c 		: integer :=  8; -- r/w: spi CS select bit 0
    constant spi_cs_set_c  		: integer :=  9; -- r/w: spi CS select enable
    constant ctrl_spi_busy_c    : integer := 10; -- r/-: spi transceiver is busy

    -- accessible regs --
	signal control_reg          : std_ulogic_vector(31 downto 0);
	-- bit 0		: spi IE
	-- bit 1 		: spi Enable
	-- bit 2 		: spi irq_cpha
	-- bit 3        : spi_prsc0_c
	-- bit 4        : spi_prsc1_c
	-- bit 5        : spi_prsc2_c
	-- bit 6        : spi_cs_sel0_c
	-- bit 7        : spi_cs_sel1_c
	-- bit 8        : spi_cs_sel2_c
	-- bit 9        : spi_cs_set_c
	
	signal spi_ie 				: std_ulogic;
	signal spi_en 				: std_ulogic;
	signal spi_cpha				: std_ulogic;
	
	signal spi_cs_sel0			: std_ulogic;
	signal spi_cs_sel1			: std_ulogic;
	signal spi_cs_sel2			: std_ulogic;
	signal spi_cs_sel3			: std_ulogic;
	signal spi_cs_set			: std_ulogic;
	
	signal control_reg_nxt    	: std_ulogic_vector(31 downto 0);
	signal data_reg	    		: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal data_reg_nxt    		: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal data_to_send			: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal receive_buf			: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal receive_buf_nxt		: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	
    -- clock generator --
    signal spi_clk : std_ulogic;
	
    -- spi transceiver --
    signal spi_busy     		: std_ulogic;
    signal spi_state0   		: std_ulogic;
    signal spi_state1   		: std_ulogic;
    signal spi_rtx_sreg 		: std_ulogic_vector(07 downto 0);
    
    signal spi_bitcnt   		: std_ulogic_vector(03 downto 0);
    signal spi_miso_buf			: std_ulogic_vector(1 downto 0);
    
    signal fifo_read    		: std_ulogic;
    signal data_ready   		: std_ulogic;
    signal data_ready_nxt 		: std_ulogic;
    signal spi_start			: std_ulogic;
    --signal rtx_byte_cnt			: std_ulogic_vector(2 downto 0);
    signal rtx_byte_cnt			: integer;
    signal spi_finish			: std_ulogic;
    signal pop_enable 			: std_ulogic;
    signal pop_enable_nxt 		: std_ulogic;
    signal spi_irq				: std_ulogic;
	signal dma_ie               : std_ulogic;
	signal push_nxt				: std_ulogic;
	signal data_out_nxt			: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal pop_cnt				: std_ulogic_vector(1 downto 0) := "00";
begin
 
	spi_ie 		<= control_reg(spi_ie_c);
	spi_en 		<= control_reg(spi_en_c);
	spi_cpha	<= control_reg(spi_cpha_c);
	spi_cs_set	<= control_reg(spi_cs_set_c);
	
	-- spi begin to transimit and receive 
    spi_start 	<= data_ready and spi_ie and spi_en;
    
    -- clock enable --
    clkgen_en_o <= control_reg(spi_en_c);
    -- spi clock select --
    spi_clk <= clkgen_i(to_integer(unsigned(control_reg(spi_prsc2_c downto spi_prsc0_c))));
    
	-- Access Fifo
	accessee_fifo : process(clock)
	begin
		if (rising_edge(clock)) then 
			pop <= '0';
			fifo_read <= '0';
			pop_cnt   <= std_ulogic_vector(unsigned(pop_cnt) - 1);
			if (pop_cnt = "00" and empty = '0' and (pop_enable_nxt = '1' or spi_finish = '1')) then 
				pop <= '1';
				fifo_read <= '1';
			end if;
		end if; 
	end process accessee_fifo;
	
	-- write the internal register of the spi 
    write_register : process(fifo_read, data_in, addr_in, data_reg,control_reg,data_ready,pop_enable)
    begin
        data_reg_nxt    <= data_reg;
        control_reg_nxt <= control_reg;
        pop_enable_nxt	<= pop_enable;
        data_ready_nxt  <= '0';
        if(fifo_read = '1') then
            case addr_in(2 downto 0) is
                when data_reg_c =>
                    data_reg_nxt    <= data_in;
                    data_ready_nxt  <= '1';
                    pop_enable_nxt	<= '0';
                when control_reg_c =>
                    control_reg_nxt <= data_in(31 downto 0);
                    data_ready_nxt  <= '0';
                    pop_enable_nxt	<= '1';
                when others =>
                    data_reg_nxt    <= data_reg;
                    control_reg_nxt <= control_reg;
                    data_ready_nxt  <= '0';
                    pop_enable_nxt  <= pop_enable;
            end case;
        end if;
    end process write_register;
    

    -- SPI transceiver ----------------------------------------------------------
    -- -----------------------------------------------------------------------------
    spi_rtx_unit: process(clock,reset_n)
    begin
		if (reset_n = '0') then
			--rtx_byte_cnt	<= "100";
			rtx_byte_cnt	<= 4;
			spi_finish		<= '0';
			spi_bitcnt 		<= "1000";
			spi_state0 		<= '0';
			spi_state1 		<= '0';
			spi_miso_buf	<= (others => '0');
        elsif rising_edge(clock) then
            -- input (MISO) synchronizer --
            spi_miso_buf <= spi_miso_buf(0) & spi_miso_i;
            spi_irq <= '0';
            if (spi_state0 = '0') or (control_reg(spi_en_c) = '0') then -- idle or disabled
                spi_bitcnt <= "1000"; -- 8 bit transfer size
                spi_state1 <= '0';
                spi_mosi_o <= '0';
                spi_sclk_o <= '0';
                
                if (control_reg(spi_en_c) = '0') then -- disabled
					spi_busy <= '0';
                elsif (spi_start = '1' or spi_irq = '1') then	
					
					--if(rtx_byte_cnt = "100") then
					if(rtx_byte_cnt = 4) then
						data_to_send <= data_reg;
						
						if (Big_Endian = 1) then 
							spi_rtx_sreg <= data_reg(DATA_WIDTH - 1 downto DATA_WIDTH - 8);
						else
							spi_rtx_sreg <= data_reg(7 downto 0);
						end if;
						
						spi_finish	 <= '0';
					else
						if (Big_Endian = 1) then
							spi_rtx_sreg <= data_to_send(DATA_WIDTH - 1 downto DATA_WIDTH - 8);
						else
							spi_rtx_sreg <= data_to_send(7 downto 0);
						end if;
					end if;
					
					--if(rtx_byte_cnt = "000") then
					if(rtx_byte_cnt = 0) then
						spi_busy     <= '0';
						
						--rtx_byte_cnt <= "100";
						rtx_byte_cnt <= 4;
					else
						spi_busy     <= '1';
						
					end if;
				end if;
				spi_state0 <= spi_busy and spi_clk; -- start with next new clock pulse
				
            else -- transmission in progress
                if (spi_state1 = '0') then -- first half of transmission
                    spi_sclk_o <= spi_cpha;
                    spi_mosi_o <= spi_rtx_sreg(7); -- MSB first
                    if (spi_clk = '1') then
                        spi_state1   <= '1';
                        if (spi_cpha = '0') then
                            spi_rtx_sreg <= spi_rtx_sreg(6 downto 0) & spi_miso_buf(1); -- MSB first
                        end if;
                        spi_bitcnt <= std_ulogic_vector(unsigned(spi_bitcnt) - 1);
                    end if;
                else -- second half of transmission
                    spi_sclk_o <= not spi_cpha;
                    if (spi_clk = '1') then
                        spi_state1 <= '0';
                        if (spi_cpha = '1') then
                            spi_rtx_sreg <= spi_rtx_sreg(6 downto 0) & spi_miso_buf(1); -- MSB first
                        end if;
                        if (spi_bitcnt = "0000") then
                            spi_state0 		<= '0';
                            spi_busy   		<= '0';
                            spi_irq  		<= spi_ie;
                            --rtx_byte_cnt    <= std_ulogic_vector(unsigned(rtx_byte_cnt) - 1);
                            rtx_byte_cnt	<= rtx_byte_cnt - 1;
                            if (Big_Endian = 1) then  
								data_to_send 	<= data_to_send(DATA_WIDTH - 9 downto 0) & x"00";
							else
								data_to_send 	<= x"00"& data_to_send(DATA_WIDTH - 1 downto 8);
							end if;
							
                            --if(rtx_byte_cnt = "001") then
                            if(rtx_byte_cnt = 1) then
								spi_finish <= '1';
							end if;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process spi_rtx_unit;
      
    -- latch the receive data in the receive register
    --receive_buf_nxt <= receive_buf(23 downto 0) & spi_rtx_sreg when spi_irq = '1' else receive_buf;
    
    latch_process: process(receive_buf, spi_irq,spi_rtx_sreg)
    begin	
		receive_buf_nxt <= receive_buf;
		if (spi_irq = '1') then
			if(Big_Endian = 1) then
				receive_buf_nxt <= receive_buf(DATA_WIDTH - 9 downto 0) & spi_rtx_sreg;
			else
				receive_buf_nxt <= spi_rtx_sreg & receive_buf(DATA_WIDTH - 1 downto 8);
			end if;
		end if;
    end process latch_process;
    
    -- write data in fifo 
    push_nxt		<= '1' when (spi_irq = '1' and spi_finish = '1' and full = '0') else '0';
    data_out_nxt    <= receive_buf_nxt when (spi_irq = '1' and spi_finish = '1') else zero_data;
	spi_irq_o		<= push_nxt;
	register_prc : process(clock,reset_n)
    begin
        if(reset_n = '0') then
            data_reg    	<= (others => '0');
            control_reg 	<= (others => '0');
            receive_buf 	<= (others => '0');
            data_out    	<= (others => '0');
            data_ready  	<= '0';
            pop_enable		<= '1';
            push			<= '0';
        elsif(rising_edge(clock)) then
            data_reg    	<= data_reg_nxt;
            control_reg 	<= control_reg_nxt;
            data_ready  	<= data_ready_nxt;
            pop_enable		<= pop_enable_nxt;
            receive_buf	<= receive_buf_nxt;
            push        	<= push_nxt;
            data_out		<= data_out_nxt;
        end if;
    end process register_prc;
    
     -- direct user-defined CS --  
     -- coverage off
    spi_cs_o(0) <= '0' when (spi_cs_set = '1') and (control_reg(spi_cs_sel2_c downto spi_cs_sel0_c) = "000") else '1';
    spi_cs_o(1) <= '0' when (spi_cs_set = '1') and (control_reg(spi_cs_sel2_c downto spi_cs_sel0_c) = "001") else '1';
    spi_cs_o(2) <= '0' when (spi_cs_set = '1') and (control_reg(spi_cs_sel2_c downto spi_cs_sel0_c) = "010") else '1';
    spi_cs_o(3) <= '0' when (spi_cs_set = '1') and (control_reg(spi_cs_sel2_c downto spi_cs_sel0_c) = "011") else '1';
    spi_cs_o(4) <= '0' when (spi_cs_set = '1') and (control_reg(spi_cs_sel2_c downto spi_cs_sel0_c) = "100") else '1';
    spi_cs_o(5) <= '0' when (spi_cs_set = '1') and (control_reg(spi_cs_sel2_c downto spi_cs_sel0_c) = "101") else '1';
    spi_cs_o(6) <= '0' when (spi_cs_set = '1') and (control_reg(spi_cs_sel2_c downto spi_cs_sel0_c) = "110") else '1';
    spi_cs_o(7) <= '0' when (spi_cs_set = '1') and (control_reg(spi_cs_sel2_c downto spi_cs_sel0_c) = "111") else '1';
    -- coverage on
    
end neo430_spi_rtl;
