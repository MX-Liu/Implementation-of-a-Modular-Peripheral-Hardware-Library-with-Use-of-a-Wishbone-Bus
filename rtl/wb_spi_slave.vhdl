library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity wb_spi_slave is
	port(
		clock		: std_ulogic;
		reset_n		: std_ulogic;
		
		---- bus interface
		wb_in		: in wb_slave_in;
		wb_out		: out wb_slave_out;
		
		-- spi interface
		spi_irq_o	: out std_ulogic;
		spi_sclk_o  : out std_ulogic; -- SPI serial clock
        spi_mosi_o  : out std_ulogic; -- SPI master out, slave in
        spi_miso_i  : in  std_ulogic; -- SPI master in, slave out
        spi_cs_o    : out std_ulogic_vector(07 downto 0)
	);
end entity wb_spi_slave;

architecture rtl of wb_spi_slave is
	
	signal L_full		: std_ulogic;
	signal L_data_in	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal L_push 		: std_ulogic;
	signal L_empty		: std_ulogic;
	signal L_data_out	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal L_addr_out	: std_ulogic_vector(31 downto 0);
	signal L_pop 		: std_ulogic;
	
	signal clkgen_en_o 	: std_ulogic; -- enable clock generator
    signal clkgen_i    	: std_ulogic_vector(07 downto 0);
	

	component spi is
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
	end component spi;
	
	component slave_wrapper_with_burst is
	port(
			clock		: in std_ulogic;
			reset_n		: in std_ulogic;
			
			---- bus interface
			wb_in		: in wb_slave_in;
			wb_out		: out wb_slave_out;
			
			---- fifo interface
			empty		: out std_ulogic;
			full		: out std_ulogic;
			
			data_in		: in std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			data_out 	: out std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			--the fifo to store the intern register addr,the control and status signal is same as the master_to_uart_fifo.
			addr_out 	: out std_ulogic_vector(31 downto 0);
			
			push 		: in std_ulogic;
			pop			: in std_ulogic	
		);
	end component slave_wrapper_with_burst;

begin
	inst_spi : spi 
	port map(
		clock		=> clock,
		reset_n		=> reset_n,
			
		-- fifo interface
		full 		=> L_full,
		empty 		=> L_empty,
		push		=> L_push,
		pop			=> L_pop,
		data_in		=> L_data_out,
		addr_in 	=> L_addr_out,
		data_out	=> L_data_in,
		
		clkgen_en_o => clkgen_en_o,
		clkgen_i    => clkgen_i,	
		-- com lines --
		spi_irq_o	=> spi_irq_o,
        spi_sclk_o  => spi_sclk_o,
        spi_mosi_o  => spi_mosi_o,
        spi_miso_i  => spi_miso_i,
        spi_cs_o    => spi_cs_o
		);
		
	inst_slave_wrapper : slave_wrapper_with_burst
	port map(
			clock		=> clock,
			reset_n		=> reset_n,
			
			---- bus interface
			wb_in		=> wb_in,
			wb_out		=> wb_out,
			
			---- fifo interface
			empty		=> L_empty,
			full		=> L_full,
			
			data_in		=> L_data_in,
			data_out 	=> L_data_out,
			--the fifo to store the intern register addr,the control and status signal is same as the master_to_uart_fifo.
			addr_out 	=> L_addr_out,
			
			push 		=> L_push,
			pop			=> L_pop
		);
	inst_clock_generator : clock_generator
    port map(
        clock       => clock,
        reset_n     => reset_n,
        
        clkgen_en   => clkgen_en_o,
        clkgen_o    => clkgen_i
    );

end rtl;

