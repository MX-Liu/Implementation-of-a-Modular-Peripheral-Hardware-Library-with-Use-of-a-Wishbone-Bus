library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

library neo430;
use neo430.neo430_package.all;


entity wb_top is
	generic(
		arbiter_choose	: natural := 1 -- default 1: priority_arbiter, 2: round_robin_arbiter
	);
    port (
        clock		: in std_ulogic;
        reset_n		: in std_ulogic;
		
		-- the external pins for the two uart module pair with wishbone bus
		m_rx		: in std_ulogic_vector(MODULE_COUNT - 3 downto 0);
		s_tx		: out std_ulogic_vector(MODULE_COUNT - 3 downto 0);
		
		-- the external pins for the I2C master moule with wishbone bus
		slave_scl	: inout std_logic ;
		slave_sda	: inout std_logic ;
		
		-- the external pins for the I2C slave moule with wishbone bus
		control_scl	: inout std_logic ;
		control_sda	: inout std_logic ;
		
		-- the external pins for the spi slave module with wishbone bus
		spi_irq_o	: out std_ulogic;
		wb_spi_sclk_o  : out std_ulogic; -- SPI serial clock
        wb_spi_mosi_o  : out std_ulogic; -- SPI master out, slave in
        wb_spi_miso_i  : in  std_ulogic; -- SPI master in, slave out
        wb_spi_cs_o    : out std_ulogic_vector(07 downto 0);
        
        -- the external pins for the pwm slave module with wishbine bus 
        pwm_o       : out std_ulogic_vector(pwm_channel_count_c - 1 downto 0);
        
        -- the external pins for the timer 
        irq_o 		: out std_ulogic;
        
        --~ mem_en		: out  std_ulogic;
		--~ mem_wr		: out std_ulogic;
		--~ mem_rd		: out std_ulogic;
		--~ mem_addr_o	: out std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
		--~ mem_dat_o	: out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
		--~ mem_dat_i	: in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        
		-- the external pins for I2C interface with neo430
		twi_sda_io 	: inout std_logic ; -- twi serial data line
		twi_scl_io 	: inout std_logic ; -- twi serial clock line
		
		-- the external pins for uart interface with neo430
		uart_txd_o 	: out std_ulogic; -- UART send data
		uart_rxd_i 	: in  std_ulogic; -- UART receive data
		
		-- parallel io --
		gpio_o      : out std_ulogic_vector(03 downto 0) -- parallel output
        );

end entity wb_top;


----------------------------------------------------------------------
-- Architecture definition.
----------------------------------------------------------------------

architecture rtl of wb_top is
	
	------------------------------------------------------------------
    -- Define internal signals.
    ------------------------------------------------------------------
	constant usr_zero	: std_ulogic_vector(SLAVE_MODULE_COUNT - 1 downto 0) := (others => '0');
	constant usr_zero_m	: std_ulogic_vector(MASTER_MODULE_COUNT - 1 downto 0) := (others => '0');
	--type t_acmp	is array (0 to MODULE_COUNT - 1) of std_ulogic;
    signal ACK			: std_ulogic;
    --signal ACMP			: t_acmp;
    
    signal ADR			: std_ulogic_vector( ADDR_WIDTH - 1 downto 0 ):= (others => '0');
    
    signal CYC			: std_ulogic;
    signal DRD			: std_ulogic_vector( DATA_WIDTH - 1 downto 0 );
    signal DWR			: std_ulogic_vector( DATA_WIDTH - 1 downto 0 );
    signal GNT			: std_ulogic_vector(  1 downto 0 );
   
    signal gnt_o		: std_ulogic_vector(MASTER_MODULE_COUNT - 1 downto 0);
	signal en_gnt_o		: std_ulogic_vector(index_size(MASTER_MODULE_COUNT) - 1 downto 0):= (others => '0');	
    signal STB			: std_ulogic;
    signal WE			: std_ulogic;
    signal CTI			: std_ulogic_vector(2 downto 0);
    signal BTE			: std_ulogic_vector(1 downto 0);
    signal SEL			: std_ulogic_vector(3 downto 0);
    
	
	-- define master and slave array type
	type t_master_in_array 		is array(0 to MASTER_MODULE_COUNT - 1) of wb_master_in;
	type t_master_out_array 	is array(0 to MASTER_MODULE_COUNT - 1) of wb_master_out;
	type t_slave_in_array 		is array(0 to SLAVE_MODULE_COUNT - 1) of wb_slave_in;
	type t_slave_out_arry		is array(0 to SLAVE_MODULE_COUNT - 1) of wb_slave_out;
	
	signal master_in_array 		: t_master_in_array;
	signal master_out_array 	: t_master_out_array;
	
	signal slave_in_array		: t_slave_in_array;
	signal slave_out_array		: t_slave_out_arry;
	
	-- because the output signal can not be read in this vhdl version, define the auxiliary local signal 
	type t_adr_o is array(0 to MODULE_COUNT - 1) of std_ulogic_vector(ADDR_WIDTH - 1 downto 0 );
	type t_dat_o is array(0 to MODULE_COUNT - 1) of std_ulogic_vector(DATA_WIDTH - 1 downto 0 );
	type t_cti_o is array(0 to MODULE_COUNT - 1) of std_ulogic_vector(2 downto 0 );
	type t_bte_o is array(0 to MODULE_COUNT - 1) of std_ulogic_vector(1 downto 0 );
	type t_sel_o is array(0 to MODULE_COUNT - 1) of std_ulogic_vector(3 downto 0 );
	
	signal l_adr_o				: t_adr_o;
	signal l_dat_o				: t_dat_o;
	signal l_cti_o				: t_cti_o;
	signal l_bte_o				: t_bte_o;
	signal l_sel_o				: t_sel_o;
	
	signal l_cyc_o				: std_ulogic_vector(MODULE_COUNT - 1 downto 0);
	signal l_ack_o				: std_ulogic_vector(SLAVE_MODULE_COUNT - 1 downto 0);
	signal l_we_o				: std_ulogic_vector(MODULE_COUNT - 1 downto 0);
	signal l_stb_o				: std_ulogic_vector(MODULE_COUNT - 1 downto 0);
	
	
	
	-- neo430 wishbone interface --
	--signal wb_sel_o 			: std_ulogic_vector(03 downto 0); -- byte enable
	signal wb_adr_o 			: std_ulogic_vector(31 downto 0); 
	signal wb_adr_ali 			: std_ulogic_vector(31 downto 0); 
	signal gpio_out				: std_ulogic_vector(15 downto 0);
	signal mem_en				: std_ulogic;
	signal mem_wr				: std_ulogic;
	signal mem_rd				: std_ulogic;
	signal mem_addr_o			: std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
	signal mem_dat_o			: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal mem_dat_i			: std_ulogic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
	
	
	
	
	component neo430_top 
	generic (
		-- general configuration --
		CLOCK_SPEED : natural := 100000000; -- main clock in Hz
		IMEM_SIZE   : natural := 4*1024; -- internal IMEM size in bytes, max 48kB (default=4kB)
		DMEM_SIZE   : natural := 2*1024; -- internal DMEM size in bytes, max 12kB (default=2kB)
		-- additional configuration --
		USER_CODE   : std_ulogic_vector(15 downto 0) := x"0000"; -- custom user code
		-- module configuration --
		DADD_USE    : boolean := false;  -- implement DADD instruction? (default=true)
		MULDIV_USE  : boolean := false;  -- implement multiplier/divider unit? (default=true)
		WB32_USE    : boolean := false;  -- implement WB32 unit? (default=true)
		WDT_USE     : boolean := false;  -- implement WDT? (default=true)
		GPIO_USE    : boolean := true;  -- implement GPIO unit? (default=true)
		TIMER_USE   : boolean := false;  -- implement timer? (default=true)
		UART_USE    : boolean := false;  -- implement UART? (default=true)
		CRC_USE     : boolean := false;  -- implement CRC unit? (default=true)
		CFU_USE     : boolean := false; -- implement custom functions unit? (default=false)
		PWM_USE     : boolean := false;  -- implement PWM controller? (default=true)
		TWI_USE     : boolean := false;  -- implement two wire serial interface? (default=true)
		SPI_USE     : boolean := false;  -- implement SPI? (default=true)
		-- boot configuration --
		BOOTLD_USE  : boolean := false;  -- implement and use bootloader? (default=true)
		IMEM_AS_ROM : boolean := false  -- implement IMEM as read-only memory? (default=false)
  );
  port (
		-- global control --
		clk_i      : in  std_ulogic; -- global clock, rising edge
		rst_i      : in  std_ulogic; -- global reset, async, LOW-active
		-- parallel io --
		gpio_o     : out std_ulogic_vector(15 downto 0); -- parallel output
		gpio_i     : in  std_ulogic_vector(15 downto 0); -- parallel input
		-- pwm channels --
		pwm_o      : out std_ulogic_vector(02 downto 0); -- pwm channels
		-- serial com --
		uart_txd_o : out std_ulogic; -- UART send data
		uart_rxd_i : in  std_ulogic; -- UART receive data
		spi_sclk_o : out std_ulogic; -- serial clock line
		spi_mosi_o : out std_ulogic; -- serial data line out
		spi_miso_i : in  std_ulogic; -- serial data line in
		spi_cs_o   : out std_ulogic_vector(07 downto 0); -- SPI CS 0..7
		twi_sda_io : inout std_logic; -- twi serial data line
		twi_scl_io : inout std_logic; -- twi serial clock line
		-- 32-bit wishbone interface --
		wb_adr_o   : out std_ulogic_vector(31 downto 0); -- address
		wb_dat_i   : in  std_ulogic_vector(31 downto 0); -- read data
		wb_dat_o   : out std_ulogic_vector(31 downto 0); -- write data
		wb_we_o    : out std_ulogic; -- read/write
		wb_sel_o   : out std_ulogic_vector(03 downto 0); -- byte enable
		wb_stb_o   : out std_ulogic; -- strobe
		wb_cyc_o   : out std_ulogic; -- valid cycle
		wb_ack_i   : in  std_ulogic; -- transfer acknowledge
		-- external interrupt --
		irq_i      : in  std_ulogic; -- external interrupt request line
		irq_ack_o  : out std_ulogic  -- external interrupt request acknowledge
  );
end component neo430_top;

	
begin
	neo430_inst :
	if(NEO430_MASTER_USE = true) generate 
	neo430_top_test_inst: neo430_top
	  generic map (
		-- general configuration --
		CLOCK_SPEED => 50000000,         -- main clock in Hz
		IMEM_SIZE   => 4*1024,            -- internal IMEM size in bytes, max 48kB (default=4kB)
		DMEM_SIZE   => 2*1024,            -- internal DMEM size in bytes, max 12kB (default=2kB)
		-- additional configuration --
		USER_CODE   => x"4788",           -- custom user code
		-- module configuration --
		DADD_USE    => true,              -- implement DADD instruction? (default=true)
		MULDIV_USE  => true,              -- implement multiplier/divider unit? (default=true)
		WB32_USE    => true,              -- implement WB32 unit? (default=true)
		WDT_USE     => true,              -- implement WDT? (default=true)
		GPIO_USE    => true,              -- implement GPIO unit? (default=true)
		TIMER_USE   => true,              -- implement timer? (default=true)
		UART_USE    => true,              -- implement UART? (default=true)
		CRC_USE     => true,              -- implement CRC unit? (default=true)
		CFU_USE     => false,             -- implement custom functions unit? (default=false)
		PWM_USE     => true,              -- implement PWM controller? (default=true)
		TWI_USE     => true,              -- implement two wire serial interface? (default=true)
		SPI_USE     => true,              -- implement SPI? (default=true)
		-- boot configuration --
		BOOTLD_USE  => false,              -- implement and use bootloader? (default=true)
		IMEM_AS_ROM => false              -- implement IMEM as read-only memory? (default=false)
	)
	port map (
		-- global control --
		clk_i      => clock,						-- global clock, rising edge
		rst_i      => reset_n,            			-- global reset, async, low-active
		-- gpio --
		gpio_o      => gpio_out,              			-- parallel output
		gpio_i      => x"0000",           			-- parallel input
		-- pwm channels --
		pwm_o       => open,              			-- pwm channels
		-- serial com --
		uart_txd_o => uart_txd_o,         			-- UART send data
		uart_rxd_i => uart_rxd_i,         			-- UART receive data
		spi_sclk_o => open,               			-- serial clock line
		spi_mosi_o => open,           				-- serial data line out
		spi_miso_i => '0',           				-- serial data line in
		spi_cs_o   => open,               			-- SPI CS 0..5
		twi_sda_io => twi_sda_io,            		-- twi serial data line
		twi_scl_io => twi_scl_io,            		-- twi serial clock line
		-- 32-bit wishbone interface --
		wb_adr_o   => wb_adr_o, 	-- address
		wb_dat_i   => master_in_array(neo_master_id_base).dat_i(31 downto 0),   	-- read data
		wb_dat_o   => master_out_array(neo_master_id_base).dat_o(31 downto 0),  	-- write data
		wb_we_o    => master_out_array(neo_master_id_base).we_o,     -- read/write
		wb_sel_o   => open,    -- byte enable
		wb_stb_o   => master_out_array(neo_master_id_base).stb_o,    -- strobe
		wb_cyc_o   => master_out_array(neo_master_id_base).cyc_o,    -- valid cycle
		wb_ack_i   => master_in_array(neo_master_id_base).ack_i,     -- transfer acknowledge
		-- external interrupt --
		irq_i      => '0',                -- external interrupt request line
		irq_ack_o  => open                -- external interrupt request acknowledge
	);
  
	wb_adr_ali <= b"000" & wb_adr_o(31 downto 3);
	master_out_array(2).adr_o <= wb_adr_ali(ADDR_WIDTH - 1 downto 0);
	gpio_o <= gpio_out(3 downto 0);	
	master_out_array(2).cti_o <= (others => '0');
	master_out_array(2).bte_o <= (others => '0');
	master_out_array(2).sel_o <= (others => '1');
	
	
	end generate neo430_inst;
	
	-------------------------------------------------------------------
	-- module instance loop there two uart master and slave 
	-------------------------------------------------------------------
	uart_pair_inst : 
	if(UART_USE = true) generate
		uart_module_gen: for i in 0 to uart_master_count - 1 generate
			MS_inst:
			wb_uart port map(
				clock		=> clock,
				reset_n		=> reset_n,

				m_wb_out	=> master_out_array(uart_master_id_base + i),
				m_wb_in		=> master_in_array(uart_master_id_base + i),
			
				s_wb_out 	=> slave_out_array(uart_slave_id_base + i),
				s_wb_in		=> slave_in_array(uart_slave_id_base + i),
			
				uart_tx_o	=> s_tx(uart_slave_id_base + i),
				uart_rx_i	=> m_rx(uart_master_id_base + i)
			);
			end generate uart_module_gen;
	end generate uart_pair_inst;
		
	
	-------------------------------------------------------------------
	-- register slave module 
	-------------------------------------------------------------------
	register_slave_inst : 
	if(REGISTER_SLAVE_USE = true) generate
		register_module_gen: for i in 0 to reg_slave_count - 1 generate
			register_slave_inst : 
			wb_register port map(
					clock   	=> clock,
					reset_n 	=> reset_n,

					wb_in		=> slave_in_array(reg_slave_id_base + i),
					wb_out		=> slave_out_array(reg_slave_id_base + i)	
			);
			end generate register_module_gen;
	end generate register_slave_inst;
	-------------------------------------------------------------------
	-- i2c slave module with master wishbone bus interface 
	-------------------------------------------------------------------
	i2c_master_inst :
	if(I2C_MASTER_USE = true) generate
		i2c_master_gen: for i in 0 to i2c_master_count - 1 generate
			i2c_master_inst : 
			wb_i2c_master port map(
					clock		=> clock,
					reset_n		=> reset_n,
					
					master_in 	=> master_in_array(i2c_master_id_base + i),
					master_out 	=> master_out_array(i2c_master_id_base + i),
					
					sda 		=> slave_sda, 
					scl 		=> slave_scl
					);
		end generate i2c_master_gen;
	end generate i2c_master_inst;
	-------------------------------------------------------------------
	-- i2c control module with slave wishbone bus interface
	-------------------------------------------------------------------
	i2c_slave_inst:
	if(I2C_SLAVE_USE = true) generate 
		i2c_slave_gen: for i in 0 to i2c_slave_count - 1 generate
			i2c_slave_inst :
			wb_i2c_slave port map(
					clock		=> clock,
					reset_n		=> reset_n,
					
					slave_in 	=> slave_in_array(i2c_slave_id_base + i),
					slave_out 	=> slave_out_array(i2c_slave_id_base + i),
					
					sda 		=> control_sda,
					scl 		=> control_scl,
					i2c_irq_o	=> open
				);
		end generate i2c_slave_gen;
	end generate i2c_slave_inst;
	-------------------------------------------------------------------
	-- dma slave module 
	-------------------------------------------------------------------
	dma_slave_inst : 
	if(DMA_SLAVE_USE = true) generate
		dma_module_gen: for i in 0 to dma_slave_count - 1 generate
			dma_slave_inst : 
			wb_dma_slave port map(
					clock   	=> clock,
					reset_n 	=> reset_n,
					dma_clock	=> clock,

					wb_in		=> slave_in_array(dma_slave_id_base + i),
					wb_out		=> slave_out_array(dma_slave_id_base + i),
					-- memory interface
					mem_en		=> mem_en		,
					mem_wr		=> mem_wr		,
					mem_rd		=> mem_rd		,
					mem_addr_o	=> mem_addr_o	,
					mem_dat_o	=> mem_dat_o	,
					mem_dat_i	=> mem_dat_i	
			);
			end generate dma_module_gen;
	end generate dma_slave_inst;
	
	-------------------------------------------------------------------
	-- dma ram module
	-------------------------------------------------------------------
	dma_ram_inst : 
	if(DMA_RAM_USE = true) generate
		
		dma_ram_inst : 
		ram port map(
				clock   	=> clock,
				reset_n 	=> reset_n,
				-- memory interface
				mem_en_i    => mem_en		,
				mem_wr_i    => mem_wr		,
				mem_rd_i    => mem_rd		,
				mem_addr_i  => mem_addr_o	,
				mem_dat_i   => mem_dat_o	,
				mem_dat_o   => mem_dat_i	
		);
			
	end generate dma_ram_inst;
	
	-------------------------------------------------------------------
	-- spi slave module 
	-------------------------------------------------------------------
	spi_slave_inst : 
	if(SPI_SLAVE_USE = true) generate
		spi_module_gen: for i in 0 to spi_slave_count - 1 generate
			spi_slave_inst : 
			wb_spi_slave port map(
					clock   	=> clock,
					reset_n 	=> reset_n,
					

					wb_in		=> slave_in_array(spi_slave_id_base + i),
					wb_out		=> slave_out_array(spi_slave_id_base + i),
					spi_irq_o	=> spi_irq_o,
					spi_sclk_o  => wb_spi_sclk_o,
					spi_mosi_o  => wb_spi_mosi_o,
					spi_miso_i  => wb_spi_miso_i,
					spi_cs_o    => wb_spi_cs_o
			);
			end generate spi_module_gen;
	end generate spi_slave_inst;
	
	-------------------------------------------------------------------
	-- pwm slave module 
	-------------------------------------------------------------------
	pwm_slave_inst : 
	if(PWM_SLAVE_USE = true) generate
		pwm_module_gen: for i in 0 to pwm_slave_count - 1 generate
			pwm_slave_inst : 
			wb_pwm port map(
					clock   	=> clock,
					reset_n 	=> reset_n,
					

					wb_in		=> slave_in_array(pwm_slave_id_base + i),
					wb_out		=> slave_out_array(pwm_slave_id_base + i),
					
					-- clock generator --
					--~ clkgen_en_o => open,
					--~ clkgen_i    => (others => '0'),
					-- pwm output channels --
					pwm_o       => pwm_o
		
			);
			end generate pwm_module_gen;
	end generate pwm_slave_inst;
	
	-------------------------------------------------------------------
	-- timer slave module 
	-------------------------------------------------------------------
	timer_slave_inst : 
	if(TIMER_SLAVE_USE = true) generate
		timer_module_gen: for i in 0 to timer_slave_count - 1 generate
			timer_slave_inst : 
			wb_timer port map(
					clock   	=> clock,
					reset_n 	=> reset_n,
					

					wb_in		=> slave_in_array(timer_slave_id_base + i),
					wb_out		=> slave_out_array(timer_slave_id_base + i),
					
					-- clock generator --
					--~ clkgen_en_o => open,
					--~ clkgen_i    => (others => '0'),
					-- pwm output channels --
					irq_o       => irq_o  -- interrupt request
		
			);
			end generate timer_module_gen;
	end generate timer_slave_inst;
	
	
	
	
	-------------------------------------------------------------------
	-- round robin arbiter 
	-------------------------------------------------------------------	
	arbiter_inst1:
	if(PRIORITY_ARBITER_USE = true) generate 
		priority_arbiter_inst: priority_arbiter 
		port map(
				clock		=> clock,
				reset_n 	=> reset_n,
				comcyc		=> CYC,
				cyc_i		=> l_cyc_o,
				en_gnt_o    => en_gnt_o,
				gnt_o		=> gnt_o
				);
	end generate arbiter_inst1;
	
	arbiter_inst2:
	if(ROUND_ROBIN_ARBITER_USE = true) generate
		round_robin_arbiter_Inst: round_robin_arbiter 
		port map(
				clock		=> clock,
				reset_n 	=> reset_n,
				comcyc		=> CYC,
				cyc_i		=> l_cyc_o,
				en_gnt_o    => en_gnt_o,
				gnt_o		=> gnt_o
				);
	end generate arbiter_inst2;
	
	-------------------------------------------------------------------
	-- local signal assignment 
	-------------------------------------------------------------------
    m_local_signal_gen : for i in 0 to MASTER_MODULE_COUNT - 1 generate
		l_cyc_o(i) <= master_out_array(i).cyc_o;
		l_adr_o(i) <= master_out_array(i).adr_o;
		l_stb_o(i) <= master_out_array(i).stb_o;
		l_we_o(i)  <= master_out_array(i).we_o;
		l_dat_o(i) <= master_out_array(i).dat_o;
		
		-- this signal is for burst mode 
		l_cti_o(i) <= master_out_array(i).cti_o;
		l_bte_o(i) <= master_out_array(i).bte_o;
		l_sel_o(i) <= master_out_array(i).sel_o;
		
 		
	end generate m_local_signal_gen;
	
	s_local_signal_gen : for i in 0 to SLAVE_MODULE_COUNT - 1 generate
	
 		l_ack_o(i) <= slave_out_array(i).ack_o;
 		
	end generate s_local_signal_gen;
	
	
	-------------------------------------------------------------------
	-- address decoder
	-------------------------------------------------------------------
    ADR_DEC: process(CYC, STB, ADR, DWR, WE, SEL, CTI, BTE)
    begin
			
		for i in 0 to SLAVE_MODULE_COUNT - 1 loop
			slave_in_array(i).stb_i <= '0';
			
			-- here because the slave_in_array can only be assigned at one process
			slave_in_array(i).dat_i 	<= DWR;
			slave_in_array(i).we_i		<= WE;
			slave_in_array(i).cyc_i		<= CYC;
			slave_in_array(i).adr_i		<= ADR;
			slave_in_array(i).sel_i		<= SEL;
			slave_in_array(i).cti_i		<= CTI;
			slave_in_array(i).bte_i		<= BTE;
	
		end loop;
		
		if(CYC = '1' and STB = '1') then
			  slave_in_array(to_integer(unsigned(ADR(ADR'left downto ADR'left - ADDR_MODULES + 1)))).stb_i	<= '1';
		end if; 
    
    end process ADR_DEC;


    ------------------------------------------------------------------
    -- Generate the ACK signals.
    ------------------------------------------------------------------
    ACK_GEN: process(l_ack_o)
    begin
    
		ACK <= '0';
		if(l_ack_o /= usr_zero) then
			ACK <= '1';
		end if;
		
    end process ACK_GEN;

    -------------------------------------------------------------------
    -- Acknowdledge receive 
    -------------------------------------------------------------------
    ACK_RCV: process( ACK, gnt_o, en_gnt_o, DRD)
    begin
		for i in 0 to MODULE_COUNT - 1 loop
			master_in_array(i).ack_i <= '0';
			
			-- here because the master_in_array(i) can only be assigned at one process
			master_in_array(i).dat_i <= DRD;
		end loop;
		
		if(ACK = '1' and (gnt_o /= usr_zero_m)) then 
			master_in_array(to_integer(unsigned(en_gnt_o))).ack_i <= '1';	
		end if;
		
    end process ACK_RCV;


    ------------------------------------------------------------------
    -- Create the signal multiplexors.
    ------------------------------------------------------------------

    ADR_MUX: process(l_adr_o, en_gnt_o)
    begin
	
		--ADR <= master_out_array(to_integer(unsigned(en_gnt_o))).adr_o;
		ADR <= l_adr_o(to_integer(unsigned(en_gnt_o)));
		
    end process ADR_MUX;
    
    DWR_MUX: process(l_dat_o, en_gnt_o)
    begin
    
		--DWR <= master_out_array(to_integer(unsigned(en_gnt_o))).dat_o;
		DWR <= l_dat_o(to_integer(unsigned(en_gnt_o)));
		
    end process DWR_MUX;
    
    STB_MUX: process(l_stb_o, en_gnt_o, CYC,gnt_o)
    begin
    
		-- because only when the cyc signal is assert, then the stb signal works, so there is "and" logic;
		-- As the en_gnt_o signal is stored the ID of the last master that has accessed the slave, if there are many stb_o
		-- signal is assert, then the STB will at first comes from the last master, then from the current master that we
		-- want. so this logic is false, because at this time the gnt_o is zero, means there is no request. 
		
		--STB <= master_out_array(to_integer(unsigned(en_gnt_o))).stb_o and CYC and gnt_o(to_integer(unsigned(en_gnt_o)));
		
		
		--STB <= l_stb_o(to_integer(unsigned(en_gnt_o))) and CYC and gnt_o(to_integer(unsigned(en_gnt_o)));
		STB <= l_stb_o(to_integer(unsigned(en_gnt_o)));
		
    end process STB_MUX;
    
    WE_MUX: process(l_we_o, en_gnt_o)
    begin
    
		--WE  <= master_out_array(to_integer(unsigned(en_gnt_o))).we_o; 
		WE  <= l_we_o(to_integer(unsigned(en_gnt_o))); 
		
    end process WE_MUX;
    
    CTI_MUX: process(l_cti_o, en_gnt_o)
    begin
    
		CTI  <= l_cti_o(to_integer(unsigned(en_gnt_o))); 
		
    end process CTI_MUX;
    
    BTE_MUX: process(l_bte_o, en_gnt_o)
    begin
    
		BTE  <= l_bte_o(to_integer(unsigned(en_gnt_o))); 
		
    end process BTE_MUX;
    
    SEL_MUX: process(l_sel_o, en_gnt_o)
    begin
    
		SEL  <= l_sel_o(to_integer(unsigned(en_gnt_o))); 
		
    end process SEL_MUX;
    
    
    DRD_MUX: process(slave_out_array, ADR )
    begin 
                                        
		DRD <= slave_out_array(to_integer(unsigned(ADR(ADR'left downto ADR'left - ADDR_MODULES + 1)))).dat_o;
 
    end process DRD_MUX;

    ------------------------------------------------------------------
    -- Generate selected internal signals visible for simulation.
    ------------------------------------------------------------------

    --MAKE_VISIBLE: process( ACK, ADR, CYC, DRD, DWR, en_gnt_o, STB, WE )
    --begin

    --    e_ack    <=  ACK;
    --    e_adr    <=  ADR;
    --    e_cyc    <=  CYC;
    --    e_drd    <=  DRD;
    --    e_dwr    <=  DWR;
    --    e_gnt    <=  en_gnt_o;
    --    e_stb    <=  STB;
    --    e_we     <=  WE;

    --end process MAKE_VISIBLE;

end architecture rtl;


