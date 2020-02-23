------------------------------------------------------------------------
-- name : tb_wb_top.vhdl;
-- description: this bus top level included the neo430 core as a master 
-- of wishbone bus, besides, it has 2 uart master, 2 uart slave, 1 i2c
-- slave and i2c master, 1 register
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

library neo430;
use neo430.neo430_package.all;

entity tb_wb_top is 

end entity tb_wb_top;

architecture dut of tb_wb_top is 

	-- User Configuration ---------------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
	constant t_clock_c   : time := 20 ns; -- main clock period
	constant f_clock_c   : real := 50000000.0; -- main clock in Hz
	constant baud_rate_c : real := 19200.0; -- standard UART baudrate
	
	-- internal configuration --
	constant baud_val_c : real    := f_clock_c / baud_rate_c;
	constant f_clk_c    : natural := natural(f_clock_c);
	
	
	signal clock		: std_ulogic := '0';
	signal reset_n		: std_ulogic;
	
	signal m_rx		: std_ulogic_vector(MODULE_COUNT - 3 downto 0);
	signal s_tx		: std_ulogic_vector(MODULE_COUNT - 3 downto 0);
			
	-- the external pins for the I2C moule pair
	signal slave_scl	: std_logic := 'Z';
	signal slave_sda	: std_logic := 'Z';
	
	signal control_scl	: std_logic := 'Z';
	signal control_sda	: std_logic := 'Z';
				
	-- the external pins of the Neo430 internal interface
	signal twi_sda_io 	: std_logic := 'Z'; -- twi serial data line
	signal twi_scl_io 	: std_logic := 'Z'; -- twi serial clock line
	
	signal uart_txd_o 	: std_ulogic; -- UART send data
	signal uart_rxd_i 	: std_ulogic; -- UART receive data
	
	signal irq_i     	: std_ulogic;	-- external interrupt request line
	signal irq_ack_o    : std_ulogic;  	-- external interrupt request acknowledge
	
	signal gpio_o		: std_ulogic_vector(03 downto 0);
	
	
	signal wb_spi_sclk_o  	: std_ulogic; -- SPI serial clock
    signal wb_spi_mosi_o  	: std_ulogic; -- SPI master out, slave in
    signal wb_spi_miso_i  	: std_ulogic; -- SPI master in, slave out
    signal wb_spi_cs_o    	: std_ulogic_vector(07 downto 0);
    signal pwm_o       		: std_ulogic_vector(pwm_channel_count_c - 1 downto 0);
    signal irq_o 			: std_ulogic;
		
	component wb_top is
	generic(
		arbiter_choose	: natural := 1 -- default 1: priority_arbiter, 2: round_robin_arbiter
	);
    port (
        clock		: in std_ulogic;
        reset_n		: in std_ulogic;
		
		-- the external pins for the two uart module pair with wishbone bus
		m_rx		: in std_ulogic_vector(MODULE_COUNT - 3 downto 0);
		s_tx		: out std_ulogic_vector(MODULE_COUNT - 3 downto 0);
		
		-- the external pins for the I2C moule pair with wishbone bus
		slave_scl	: inout std_logic;
		slave_sda	: inout std_logic;
		
		control_scl	: inout std_logic;
		control_sda	: inout std_logic;
		
		-- the external pins for the spi slave module with wishbone bus
		wb_spi_sclk_o  : out std_ulogic; -- SPI serial clock
        wb_spi_mosi_o  : out std_ulogic; -- SPI master out, slave in
        wb_spi_miso_i  : in  std_ulogic; -- SPI master in, slave out
        wb_spi_cs_o    : out std_ulogic_vector(07 downto 0);
        
        -- the external pins for the pwm slave module with wishbine bus 
        pwm_o       : out std_ulogic_vector(pwm_channel_count_c - 1 downto 0);
        
        -- the external pins for the timer 
        irq_o 		: out std_ulogic;
        
		
		-- the external pins for I2C interface with neo430
		twi_sda_io 	: inout std_logic; -- twi serial data line
		twi_scl_io 	: inout std_logic; -- twi serial clock line
		
		-- the external pins for uart interface with neo430
		uart_txd_o 	: out std_ulogic; -- UART send data
		uart_rxd_i 	: in  std_ulogic; -- UART receive data
		
		-- parallel io of neo430--
		gpio_o      : out std_ulogic_vector(03 downto 0) -- parallel output
        );

	end component wb_top;
	
	--~ component i2c_slave
			--~ generic (
			--~ SLAVE_ADDR : std_ulogic_vector(6 downto 0) := "1010011");
			--~ port (
			--~ sda : inout std_logic := 'Z';
			--~ scl : inout std_logic := 'Z'
			--~ );
	--~ end component i2c_slave;
	
	
	component i2c_slave_module is
	generic (
		SLAVE_ADDR : std_ulogic_vector(6 downto 0) := "1010011");
	port (
			clock		: in std_ulogic;
			reset_n		: in std_ulogic;
			---- external fifo control interface
			empty		: in std_ulogic;
			full		: in std_ulogic;
			
			data_in		: in std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			data_out 	: out std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			addr_out 	: out std_ulogic_vector(31 downto 0);
	
			push 		: out std_ulogic;
			pop			: out std_ulogic;
--			wr_en		: out std_ulogic;
--			rd_en		: out std_ulogic;
			
			-- I2C interface 
			sda 		: inout std_logic := 'Z';
			scl 		: inout std_logic := 'Z'
		);
	end component i2c_slave_module;
	
begin
	inst_wb_top : wb_top
	generic map(
		arbiter_choose	=> 1 -- default 1: priority_arbiter, 2: round_robin_arbiter
	)
    port map(
            clock		=> clock,
            reset_n		=> reset_n,
			
			-- the external pins for the two uart module pair with wishbone bus
			m_rx		=> m_rx,
			s_tx		=> s_tx,
			
			-- the external pins for the I2C moule pair with wishbone bus
			slave_scl	=> slave_scl,
			slave_sda	=> slave_sda,
			
			control_scl	=> control_scl,
			control_sda	=> control_sda,
			
			
			-- the external pins for the spi slave module with wishbone bus
			wb_spi_sclk_o  => wb_spi_sclk_o,
			wb_spi_mosi_o  => wb_spi_mosi_o,
			wb_spi_miso_i  => wb_spi_miso_i,
			wb_spi_cs_o    => wb_spi_cs_o  ,
        
			-- the external pins for the pwm slave module with wishbine bus 
			pwm_o       	=> pwm_o,
        
			-- the external pins for the timer 
			irq_o 			=> irq_o,
        
			-- the external pins for I2C interface with neo430
			twi_sda_io 	=> twi_sda_io,
			twi_scl_io 	=> twi_scl_io,
			
			-- the external pins for uart interface with neo430
			uart_txd_o 	=> uart_txd_o,
			uart_rxd_i 	=> uart_rxd_i,
			
			-- parallel io --
			gpio_o      => gpio_o
     
        );
		
		
		--~ inst_i2c_slave: i2c_slave
			--~ generic map(
				--~ SLAVE_ADDR => b"1010011")
			--~ port map(
				--~ sda => control_sda,
				--~ scl => control_scl
			--~ );
			
		inst_i2c_slave : i2c_slave_module
		generic map(
			SLAVE_ADDR => "1010011")
		port map(
			clock		=> clock,
			reset_n	    => reset_n,
			empty	    => '0',
			full	    => '0',
			data_in	    => (others => '0'),
			data_out    => open,
			addr_out    => open,
			push 	    => open,
			pop		    => open,
			sda 	    => control_sda,
			scl 	    => control_scl
		);
	
	
		--~ control_scl <= 'H';
		--~ control_sda <= 'H';
		slave_scl	<= twi_scl_io;
		slave_sda	<= twi_sda_io;
		
		uart_rxd_i  <= s_tx(0);
		m_rx(0)		<= '1' when uart_txd_o /= '0' else '0';
		m_rx(1)     <= s_tx(1);
		-- Clock/Reset Generator ----------------------------------------------------
		-- -----------------------------------------------------------------------------
		clock <= not clock after (t_clock_c/2);
		reset_n <= '0', '1' after 60*(t_clock_c/2);
		
		-- Interrupt Generator ------------------------------------------------------
	-- -----------------------------------------------------------------------------
	interrupt_gen: process
	begin
		irq_i <= '0';
		wait for 20 ms;
		wait until rising_edge(clock);
		irq_i <= '1';
		wait for t_clock_c;
		wait until rising_edge(irq_ack_o);
		irq_i<= '0';
		wait;
	end process interrupt_gen;
	
	
end dut;
