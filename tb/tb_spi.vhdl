library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity tb_spi is

end entity tb_spi;

architecture DUT of tb_spi is 

    constant period     : time := 20 ns;
    signal clock        : std_ulogic := '0';
    signal reset_n      : std_ulogic;
    
    -- fifo interface
    signal full 		: std_ulogic;
	signal empty 		: std_ulogic;
	signal empty_addr 	: std_ulogic;
	signal empty_data 	: std_ulogic;
	signal push			: std_ulogic;
	signal pop			: std_ulogic;
	signal data_in		: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal addr_in 		: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal data_out		: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	
    -- spi interface 
    signal clkgen_en_o  : std_ulogic; -- enable clock generator
    signal clkgen_i     : std_ulogic_vector(07 downto 0);
    signal spi_sclk_o   : std_ulogic; -- SPI serial clock
    signal spi_mosi_o   : std_ulogic; -- SPI master out, slave in
    signal spi_miso_i   : std_ulogic; -- SPI master in, slave out
    signal spi_cs_o     : std_ulogic_vector(07 downto 0); -- SPI CS 0..5
    
    -- the signal of wishbone side
	signal wb_push		: std_ulogic;
	signal wb_full		: std_ulogic;
	signal wb_full_addr	: std_ulogic;
	signal wb_full_data	: std_ulogic;
	signal wb_addr_in	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal wb_data_in	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal wb_pop 		: std_ulogic;
	signal wb_empty		: std_ulogic;
	signal wb_data_out	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    
    component spi is
    port (
        -- host access --
        clock       : in  std_ulogic; -- global clock line
        reset_n     : in  std_ulogic;
        
        -- fifo interface
        full        : in  std_ulogic;
        empty       : in  std_ulogic;
        push        : out std_ulogic;
        pop         : out std_ulogic;
        data_in     : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        addr_in     : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        data_out    : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
            
        -- clock generator --
        clkgen_en_o : out std_ulogic; -- enable clock generator
        clkgen_i    : in  std_ulogic_vector(07 downto 0);
        -- com lines --
        spi_sclk_o  : out std_ulogic; -- SPI serial clock
        spi_mosi_o  : out std_ulogic; -- SPI master out, slave in
        spi_miso_i  : in  std_ulogic; -- SPI master in, slave out
        spi_cs_o    : out std_ulogic_vector(07 downto 0) -- SPI CS 0..5
    );
    end component spi;
    
    component fifo is
	generic(
		fifo_width : integer := 32;
		fifo_depth : integer := 8
		);
	port(
		clock		: in std_logic;
		reset_n		: in std_logic;
		data_in		: in  std_ulogic_vector(fifo_width - 1 downto 0);
		data_out	: out std_ulogic_vector(fifo_width - 1 downto 0);

		empty		: out std_logic;
		full		: out std_logic;

		pop			: in std_logic;
		push		: in std_logic
	);
    end component fifo;
    
begin

	inst_data_fifo : fifo
	generic map(
		fifo_width => 32,
		fifo_depth => 8
		)
	port map(
		clock		=> clock,
		reset_n		=> reset_n,
		data_in		=> wb_data_in,
		data_out	=> data_in,

		empty		=> empty_data,
		full		=> wb_full_data,

		pop			=> pop,
		push		=> wb_push
	);
	
	inst_addr_fifo : fifo
	generic map(
		fifo_width => 32,
		fifo_depth => 8
		)
	port map(
		clock		=> clock,
		reset_n		=> reset_n,
		data_in		=> wb_addr_in,
		data_out	=> addr_in,

		empty		=> empty_addr,
		full		=> wb_full_addr,

		pop			=> pop,
		push		=> wb_push
	);
	
	empty <= empty_addr or empty_data;
	wb_full	<= wb_full_addr or wb_full_data;
	
	inst_data_read_fifo : fifo
	generic map(
		fifo_width => 32,
		fifo_depth => 8
		)
	port map(
		clock		=> clock,
		reset_n		=> reset_n,
		data_in		=> data_out,
		data_out	=> wb_data_out,

		empty		=> wb_empty,
		full		=> full,

		pop			=> wb_pop,
		push		=> push
	);
	
    inst_spi : spi 
    port map(
        
        -- host access --
        clock       => clock,
        reset_n     => reset_n,
        
        -- fifo interface
        full        => full,
        empty       => empty,
        push        => push,
        pop         => pop,
        data_in     => data_in,
        addr_in     => addr_in,
        data_out    => data_out,
        
        clkgen_en_o => clkgen_en_o,
        clkgen_i    => clkgen_i,
        
        spi_sclk_o  => spi_sclk_o,
        spi_mosi_o  => spi_mosi_o,
        spi_miso_i  => spi_miso_i,
        spi_cs_o    => spi_cs_o
       
    );
    
    spi_miso_i <= spi_mosi_o;
    inst_clock_generator : clock_generator
    port map(
        clock       => clock,
        reset_n     => reset_n,
        
        clkgen_en   => clkgen_en_o,
        clkgen_o    => clkgen_i
    );
    
    clock <= not clock after period/2 ;
    
    sim_send : process
    begin
        reset_n     <= '0';
        
        wait for 3 * period;
        reset_n     <= '1';
        
        -- write to control register 
        wait until(rising_edge(clock));
		wb_push <= '1';
		wb_addr_in	<= x"00000001";
		wb_data_in	<= x"F800020F";
		
		-- write data register 
		wait for period;
		wb_push <= '1';
		wb_addr_in	<= x"00000002";
		wb_data_in	<= x"348980a2";
		
		-- write data register 
		wait for period;
		wb_push <= '1';
		wb_addr_in	<= x"00000002";
		wb_data_in	<= x"37287911";
		
		-- stop write data register 
		wait for period;
		wb_push <= '0';
		wait for 12000 ns;
		
		-- restart to write data register
		wait until(rising_edge(clock));
		wb_push <= '1';
		wb_addr_in	<= x"00000002";
		wb_data_in	<= x"89080871";
		wait for period;
		wb_push <= '0';

		
		wait for period;
		-- write control register and disable spi
		wait for period;
		wb_push <= '1';
		wb_addr_in	<= x"00000001";
		wb_data_in	<= x"00000000";				
		wait for period;
		wb_push <= '0';
		
		wait for 10*period;
		wait until(rising_edge(clock));
		wb_push <= '1';
		wb_addr_in	<= x"00000001";
		wb_data_in	<= x"F800020F";
		wait until(rising_edge(clock));
		wb_push <= '1';
		wb_addr_in	<= x"00000002";
		wb_data_in	<= x"46789324";
		wait for period;
		wb_push <= '0';
		
       
		
		wait;

    end process sim_send;
    
    sim_receive : process
    begin
		wb_pop		<= '0';
		
		wait until (wb_empty = '0');
		wb_pop		<= '1'; 
		wait for 3 ns;
		assert (wb_data_out = x"348980a2") report "spi receive wrong data" severity error;
		wait until(rising_edge(clock));
		wb_pop		<= '0';
		
		wait until (wb_empty = '0');
		wb_pop		<= '1'; 
		wait for 3 ns;
		assert (wb_data_out = x"37287911") report "spi receive wrong data" severity error;
		wait until(rising_edge(clock));
		wb_pop		<= '0';
		
		wait until (wb_empty = '0');
		wb_pop		<= '1'; 
		wait for 3 ns;
		assert (wb_data_out = x"89080871") report "spi receive wrong data" severity error;
		wait until(rising_edge(clock));
		wb_pop		<= '0';
		
		wait until (wb_empty = '0');
		wb_pop		<= '1'; 
		wait for 3 ns;
		assert (wb_data_out = x"46789324") report "spi receive wrong data" severity error;
		wait until(rising_edge(clock));
		wb_pop		<= '0';
		
		assert (false) report "*******complete simmulation********" severity note;
		wait;
	end process sim_receive;
    
    

end DUT;
