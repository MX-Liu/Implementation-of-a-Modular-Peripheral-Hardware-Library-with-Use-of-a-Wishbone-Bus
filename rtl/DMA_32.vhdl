library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity dma is
    port(
            clock       : in std_ulogic;
            reset_n     : in std_ulogic;
            
            -- fifo interface
            full        : in  std_ulogic;
            empty       : in  std_ulogic;
            push        : out std_ulogic;
            pop         : out std_ulogic;
            data_in     : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
            addr_in     : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
            data_out    : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
            
            -- memory interface
            --hold_req  : out std_ulogic;
            --hold_ack  : in  std_ulogic;
            mem_en      : out  std_ulogic;
            mem_wr    	: out std_ulogic;
            mem_rd      : out std_ulogic;
            mem_addr_o	: out std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
            mem_dat_o   : out std_ulogic_vector(MEM_DATA_WIDTH - 1 downto 0);
            mem_dat_i   : in  std_ulogic_vector(MEM_DATA_WIDTH - 1 downto 0)    
            
        );
    end dma;
    
architecture rtl of dma is 

    constant data_reg_c         : std_ulogic_vector := "010";
    constant control_reg_c      : std_ulogic_vector := "001";
    constant dma_ie_c           : integer := 31;
    constant dma_en_c           : integer := 30; 
    constant inc_src_c          : integer := 29; 
    constant inc_dst_c          : integer := 28; 
    constant wr_en_c            : integer := 27; 
    constant rd_en_c            : integer := 26; 
    constant src_addr_c         : integer := 15;
    constant dst_addr_c         : integer := 7;

    
    signal control_reg          : std_ulogic_vector(31 downto 0);
    -- bit 31   DMAIE = 1           DMA Interrupt enable            
    -- bit 30   DMAE  = 1           DMA enable
    -- bit 29   INC_SRC = 1         source address increment. i.A. burst mode
    -- bit 28   INC_DST = 1         destination address increment  i.A burst mode
    -- bit 27   WR_EN = 1           write enable 
    -- bit 26   RD_EN = 1           read enable
    -- bit 25 - 16 reserve 
    -- bit 15 - 8   SRC_ADDR        source address
    -- bit 7 - 0    DST_ADDR        destination address 
    signal control_reg_nxt      : std_ulogic_vector(31 downto 0);
    signal data_reg             : std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal data_reg_nxt         : std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    
    signal adr_reg              : std_ulogic_vector(7 downto 0); -- for the burst mode, to store the address which will be added at next phase
    signal adr_reg_nxt          : std_ulogic_vector(7 downto 0);
    signal inc_mode             : std_ulogic;                    -- increment mode begin
    signal inc_stop             : std_ulogic;                    -- increment mode pause
    
    signal dma_ie               : std_ulogic;
    signal dma_en               : std_ulogic;
    signal inc_src              : std_ulogic;
    signal inc_dst              : std_ulogic;
    signal wr_en                : std_ulogic;
    signal rd_en                : std_ulogic;
    signal src_addr             : std_ulogic_vector(7 downto 0);
    signal dst_addr             : std_ulogic_vector(7 downto 0); 
    
    signal fifo_read            : std_ulogic;                   -- the data from fifo has been poped.
    signal data_ready           : std_ulogic;                   -- the data from fifo is to be send
    signal data_ready_nxt       : std_ulogic;
	
	signal l_mem_en      		: std_ulogic;
	signal l_mem_wr    			: std_ulogic;
	signal l_mem_rd      		: std_ulogic;
	signal l_mem_addr_o			: std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
	signal l_mem_dat_o   		: std_ulogic_vector(MEM_DATA_WIDTH - 1 downto 0);
	signal l_mem_dat_i   		: std_ulogic_vector(MEM_DATA_WIDTH - 1 downto 0); 
	
	signal indix				: integer;
	signal indix_nxt			: integer;
    
    type dma_state_t is (IDLE, SIG_READ, BST_READ, SIG_WRITE, BST_WRITE, FINISH);
    signal dma_state            : dma_state_t;
    signal dma_state_nxt        : dma_state_t;
begin
    
    dma_ie  <= control_reg(dma_ie_c);
    dma_en  <= control_reg(dma_en_c);
    inc_src <= control_reg(inc_src_c);
    inc_dst <= control_reg(inc_dst_c);
    wr_en   <= control_reg(wr_en_c);
    rd_en   <= control_reg(rd_en_c);
    src_addr<= control_reg(src_addr_c downto src_addr_c - 7);
    dst_addr<= control_reg(dst_addr_c downto dst_addr_c - 7);
    
    load_data : process(empty)
    begin
            pop <= '0';
            fifo_read <= '0';
            if(empty = '0') then
                pop <= '1';
                fifo_read <= '1';
            end if;
        
    end process load_data;
    
    -- write the internal register of the DMA 
    write_register : process(fifo_read, data_in, addr_in, data_reg,control_reg,data_ready)
    begin
        data_reg_nxt    <= data_reg;
        control_reg_nxt <= control_reg;
        --data_ready_nxt  <= data_ready;
        data_ready_nxt  <= '0';
        if(fifo_read = '1') then
            case addr_in(2 downto 0) is
                when data_reg_c =>
                    data_reg_nxt    <= data_in;
                    data_ready_nxt  <= '1';
                when control_reg_c =>
                    control_reg_nxt <= data_in(31 downto 0);
                    data_ready_nxt  <= '0';
                when others =>
                    data_reg_nxt    <= data_reg;
                    control_reg_nxt <= control_reg;
                    data_ready_nxt  <= '0';
            end case;
        end if;
    end process write_register;
    
    -- dma state machine
    dma_state_machine : process(dma_state, dma_ie, dma_en, wr_en, inc_dst, rd_en,dst_addr,data_ready,full,l_mem_dat_i,data_reg,adr_reg)
    begin
        dma_state_nxt   <= dma_state;
		
        l_mem_en          <= '0';
        l_mem_wr          <= '0';
        l_mem_rd          <= '0';
        l_mem_addr_o      <= (others => '0');
        l_mem_dat_o       <= (others => '0');
        push            <= '0';
        data_out        <= (others => '0');
        inc_mode        <= '0';
        inc_stop        <= '0';
        case dma_state is 
            when IDLE => 
                if(dma_ie = '1' and dma_en = '1') then
                    if(wr_en = '1' and rd_en = '0' and data_ready = '1') then
                        if(inc_dst = '1' ) then
                            dma_state_nxt   <= BST_WRITE;
                            
                            l_mem_en          <= '1';
							l_mem_wr          <= '1';
							l_mem_addr_o      <= adr_reg(ADDR_WIDTH - 1 downto 0);
							l_mem_dat_o       <= data_reg;
							inc_mode        <= '1';
                        else
                            dma_state_nxt   <= SIG_WRITE;
                        end if;
                    end if; 
                    if(wr_en = '0' and rd_en = '1') then
                        if(inc_dst = '1') then
                            dma_state_nxt   <= BST_READ;
                        else
                            dma_state_nxt   <= SIG_READ;
                        end if;
                    end if;
                else
                    dma_state_nxt   <= IDLE;
                end if;
            when SIG_WRITE =>
                    l_mem_en          <= '1';
                    l_mem_wr          <= '1';
                    l_mem_addr_o      <= dst_addr(ADDR_WIDTH - 1 downto 0);
                    l_mem_dat_o       <= data_reg;
                    dma_state_nxt   <= IDLE;
            when BST_WRITE  =>
                if(inc_dst = '0' or wr_en = '0' or dma_ie = '0' or dma_en = '0') then
                    dma_state_nxt   <= IDLE;
                else
                    if(data_ready = '1') then
                        l_mem_en          <= '1';
                        l_mem_wr          <= '1';
                        l_mem_addr_o      <= adr_reg(ADDR_WIDTH - 1 downto 0);
                        l_mem_dat_o       <= data_reg;
                        inc_mode        <= '1';

                    else
                        dma_state_nxt   <= BST_WRITE;
                        inc_stop        <= '1';
                        inc_mode        <= '1';
                    end if;
                end if;
            when SIG_READ =>
                if(full = '0') then 
                    l_mem_en          <= '1';
                    l_mem_rd          <= '1';
                    l_mem_addr_o      <= dst_addr(ADDR_WIDTH - 1 downto 0);
                    push            <= '1';
                    data_out        <= l_mem_dat_i;
                    dma_state_nxt   <= IDLE;
                else
                    dma_state_nxt   <= SIG_READ;
                end if;
            when BST_READ =>
                if(inc_dst = '0' or rd_en = '0' or dma_ie = '0' or dma_en = '0') then
                    dma_state_nxt   <= IDLE;
                else
                    if(full = '0') then
                        l_mem_en          <= '1';
                        l_mem_rd          <= '1';
                        l_mem_addr_o      <= adr_reg(ADDR_WIDTH - 1 downto 0);
                        inc_mode        <= '1';
                        push            <= '1';
                        data_out        <= l_mem_dat_i;
						
                    else
                        dma_state_nxt   <= BST_READ;
                        inc_stop        <= '1';
                        inc_mode        <= '1';
                    end if;
					
					
                end if;
            when others =>
                dma_state_nxt   <= IDLE;
        end case;   
    end process dma_state_machine;
    
    adress_counter : process(dst_addr,inc_mode,adr_reg,inc_stop)
    begin

        if(inc_mode = '1') then
            if(inc_stop = '1') then
                adr_reg_nxt <= adr_reg;
            else
                adr_reg_nxt <= std_ulogic_vector(unsigned(adr_reg) + 1);
            end if;
        else
            adr_reg_nxt <= dst_addr;
        end if;

    end process adress_counter;
    
	
	out_process: process(indix,l_mem_en, l_mem_wr, l_mem_rd, l_mem_addr_o,l_mem_dat_o, mem_dat_i)
	begin
			mem_en    	<= l_mem_en;    
		    mem_wr      <= l_mem_wr;
			mem_rd      <= l_mem_rd; 
			case indix is
				when 0 =>
					mem_dat_o 	<= l_mem_dat_o(127 downto 96);
					mem_dat_o 	<= l_mem_dat_o;
					l_mem_dat_i(127 downto 96)<= mem_dat_i;
					indix_nxt <= indix + 1;
				when 1 => 
					mem_dat_o <= l_mem_dat_o(95 downto 64);
					mem_dat_o <= std_ulogic_vector(unsigned(l_mem_dat_o) + 1);
					l_mem_dat_i(95 downto 64)<= mem_dat_i;
					indix_nxt <= indix + 1;
				when 2 => 
					mem_dat_o <= l_mem_dat_o(63 downto 32);
					mem_dat_o <= std_ulogic_vector(unsigned(l_mem_dat_o) + 1);
					l_mem_dat_i(63 downto 32)<= mem_dat_i;
					indix_nxt <= indix + 1;
				when 3 => 
					mem_dat_o <= l_mem_dat_o(31 downto 0);
					mem_dat_o <= std_ulogic_vector(unsigned(l_mem_dat_o) + 1);
					l_mem_dat_i(31 downto 0)<= mem_dat_i;
					indix_nxt <= 0;
				when others =>
					indix_nxt <= 0;
			end case;
		end if;
		
	end process out_process;
    register_prc : process(clock,reset_n)
    begin
        if(reset_n = '0') then
            data_reg    <= (others => '0');
            control_reg <= (others => '0');
            dma_state   <= IDLE;
            data_ready  <= '0';
			indix		<= 0;
        elsif(rising_edge(clock)) then
            data_reg    <= data_reg_nxt;
            control_reg <= control_reg_nxt;
            dma_state   <= dma_state_nxt;
            data_ready  <= data_ready_nxt;
            adr_reg     <= adr_reg_nxt;
			indix		<= indix_nxt;
        end if;
    end process register_prc;
end rtl;
