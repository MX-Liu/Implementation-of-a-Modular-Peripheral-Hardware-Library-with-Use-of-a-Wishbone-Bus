library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;
use work.txt_util.all;

entity tb_wb_spi_slave is
	
end entity tb_wb_spi_slave;

architecture DUT of tb_wb_spi_slave is
	constant t_clock_c   	: time := 20 ns; -- main clock period
	signal clock			: std_ulogic := '0';
	signal reset_n			: std_ulogic;
	
	signal s_wb_in			: wb_slave_in;
	signal s_wb_out			: wb_slave_out;
			
	-- spi interface
	signal spi_irq_o	: std_ulogic;
	signal spi_sclk_o  	: std_ulogic; -- SPI serial clock
    signal spi_mosi_o  	: std_ulogic; -- SPI master out, slave in
    signal spi_miso_i  	: std_ulogic; -- SPI master in, slave out
    signal spi_cs_o    	: std_ulogic_vector(07 downto 0);
	
	---- bus interface
	signal m_wb_in		: wb_master_in;
	signal m_wb_out		: wb_master_out;
			
			---- fifo interface
	signal	m_empty		: std_ulogic;
	signal	m_full		: std_ulogic;
			
	signal	m_data_in	: std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
	signal	m_addr_in 	: std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
	signal	m_data_out 	: std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			
	
	signal	m_push 		: std_ulogic;
	signal	m_pop		: std_ulogic;
	
			-- simulation
	signal	m_wr_en		: std_ulogic;
	signal	m_rd_en		: std_ulogic;
			
	component master_wrapper_with_burst is
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
	end component master_wrapper_with_burst;
	
	component wb_spi_slave is
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
	end component wb_spi_slave;

begin
	inst_master : master_wrapper_with_burst
	port map(
		clock		=> clock,
		reset_n		=> reset_n,
		
		---- bus interface
		wb_in		=> m_wb_in,
		wb_out		=> m_wb_out,
		
		---- fifo interface
		empty		=> m_empty,
		full		=> m_full,
		
		data_in		=> m_data_in,
		addr_in 	=> m_addr_in,
		data_out 	=> m_data_out,
		
	
		push 		=> m_push,
		pop			=> m_pop
		
	);
	
	m_wb_in.ack_i <= s_wb_out.ack_o;
	m_wb_in.dat_i <= s_wb_out.dat_o;
	s_wb_in.cyc_i <= m_wb_out.cyc_o;
	s_wb_in.adr_i <= m_wb_out.adr_o;
	s_wb_in.dat_i <= m_wb_out.dat_o;
	s_wb_in.cti_i <= m_wb_out.cti_o;
	s_wb_in.bte_i <= m_wb_out.bte_o;
	s_wb_in.stb_i <= m_wb_out.stb_o;
	s_wb_in.we_i  <= m_wb_out.we_o;
	
	
	inst_wb_spi : wb_spi_slave
	port map(
		clock		=> clock,
		reset_n		=> reset_n,
		
		---- bus interface
		wb_in		=> s_wb_in,
		wb_out		=> s_wb_out,
		
		-- spi interface
		spi_irq_o	=> spi_irq_o,
		
		spi_sclk_o  => spi_sclk_o,
        spi_mosi_o  => spi_mosi_o,
        spi_miso_i  => spi_miso_i,
        spi_cs_o    => spi_cs_o
	);
	
	spi_miso_i <= spi_mosi_o;
	clock <= not clock after (t_clock_c/2);
	reset_n <= '0', '1' after 40 ns;
	
	sim : process
	begin
		
		wait for (50 ns);
		wait until(rising_edge(clock));
		m_pop 	<= '0';
		m_push 	<= '0';
		m_wr_en <= '0';
		m_rd_en <= '0';
		m_wr_en <= '1';
		wait until(rising_edge(clock));
		m_wr_en <= '1';
		m_push <= '1';
		m_data_in <= x"0000024F";
		m_addr_in <= x"80000001";
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"F8000301";
		m_addr_in <= x"80D02392";
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"A32D2363";
		m_addr_in <= x"80D02302";
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"A32D2364";
		m_addr_in <= x"89D02302";
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"A32D2365";
		m_addr_in <= x"89D02302";
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"A32D2364";
		m_addr_in <= x"89D02392";
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"A32D236c";
		m_addr_in <= x"89D02392";
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"A32D2334";
		m_addr_in <= x"89D02392";
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"A32D2323";
		m_addr_in <= x"89D02392";
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"A32D2367";
		m_addr_in <= x"89D02392";
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"A32D2368";
		m_addr_in <= x"80D02392";
		
		
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"C8000307";
		m_addr_in <= x"80D02392";
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"45478787";
		m_addr_in <= x"80D02392";
		wait until(rising_edge(clock));
		m_push <= '0';
		
		assert(false) report "complete write" severity note;
		
		-- read data
		wait until(spi_irq_o = '1');
		assert(false) report "interrupt signal is active 0" severity note;
		wait for 50 ns;
		wait until(rising_edge(clock));
		
		m_push <= '1';
		m_data_in <= x"00000000";
		m_addr_in <= x"40000001";
		wait until(rising_edge(clock));
		m_push <= '0';
		wait until(m_empty = '0');
		m_pop <= '1';
		wait for (2 ns);
		assert(m_data_out = x"F8000301") report "read wrong data ***" severity error;
		wait until(rising_edge(clock));
		m_pop <= '0';
		
		
		
		wait until(spi_irq_o = '1');
		assert(false) report "interrupt signal is active 1" severity note;
		wait until(rising_edge(clock));
		
		m_push <= '1';
		m_data_in <= x"00000000";
		m_addr_in <= x"40000001";
		wait until(rising_edge(clock));
		m_push <= '0';
		wait until(m_empty = '0');
		m_pop <= '1';
		wait for (2 ns);
		assert(m_data_out = x"A32D2363") report "read wrong data" severity error;
		wait until(rising_edge(clock));
		m_pop <= '0';
		
		
		wait until(spi_irq_o = '1');
		assert(false) report "interrupt signal is active 2" severity note;
		wait until(rising_edge(clock));
		
		m_push <= '1';
		m_data_in <= x"00000000";
		m_addr_in <= x"40000001";
		wait until(rising_edge(clock));
		m_push <= '0';
		wait until(m_empty = '0');
		m_pop <= '1';
		wait for (2 ns);
		assert(m_data_out = x"A32D2364") report "read wrong data" severity error;
		wait until(rising_edge(clock));
		m_pop <= '0';
		
		wait until(rising_edge(clock));
		
		wait until(spi_irq_o = '1');
		assert(false) report "interrupt signal is active 3" severity note;
		wait until(rising_edge(clock));
		
		m_push <= '1';
		m_data_in <= x"00000000";
		m_addr_in <= x"40000001";
		wait until(rising_edge(clock));
		m_push <= '0';
		wait until(m_empty = '0');
		m_pop <= '1';
		wait for (2 ns);
		assert(m_data_out = x"A32D2365") report "read wrong data" severity error;
		wait until(rising_edge(clock));
		m_pop <= '0';
		
		wait until(spi_irq_o = '1');
		assert(false) report "interrupt signal is active 4" severity note;
		wait until(rising_edge(clock));
		
		m_push <= '1';
		m_data_in <= x"00000000";
		m_addr_in <= x"40000001";
		wait until(rising_edge(clock));
		m_push <= '0';
		wait until(m_empty = '0');
		m_pop <= '1';
		wait for (2 ns);
		assert(m_data_out = x"A32D2364") report "read wrong data" severity error;
		wait until(rising_edge(clock));
		m_pop <= '0';
		
		wait until(spi_irq_o = '1');
		assert(false) report "interrupt signal is active 5" severity note;
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"00000000";
		m_addr_in <= x"40000001";
		wait until(rising_edge(clock));
		m_push <= '0';
		wait until(m_empty = '0');
		m_pop <= '1';
		wait for (2 ns);
		assert(m_data_out = x"A32D236c") report "read wrong data" severity error;
		wait until(rising_edge(clock));
		m_pop <= '0';
		
		
		wait until(spi_irq_o = '1');
		assert(false) report "interrupt signal is active 6" severity note;
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"00000000";
		m_addr_in <= x"40000001";
		wait until(rising_edge(clock));
		m_push <= '0';
		wait until(m_empty = '0');
		m_pop <= '1';
		wait for (2 ns);
		assert(m_data_out = x"A32D2334") report "read wrong data" severity error;
		wait until(rising_edge(clock));
		m_pop <= '0';
		
		wait until(spi_irq_o = '1');
		assert(false) report "interrupt signal is active 7" severity note;
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"00000000";
		m_addr_in <= x"40000001";
		wait until(rising_edge(clock));
		m_push <= '0';
		wait until(m_empty = '0');
		m_pop <= '1';
		wait for (2 ns);
		assert(m_data_out = x"A32D2323") report "read wrong data" severity error;
		wait until(rising_edge(clock));
		m_pop <= '0';
		
		wait until(spi_irq_o = '1');
		assert(false) report "interrupt signal is active 8" severity note;
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"00000000";
		m_addr_in <= x"40000001";
		wait until(rising_edge(clock));
		m_push <= '0';
		wait until(m_empty = '0');
		m_pop <= '1';
		wait for (2 ns);
		assert(m_data_out = x"A32D2367") report "read wrong data" severity error;
		wait until(rising_edge(clock));
		m_pop <= '0';
		
		--~ wait until(spi_irq_o = '1');
		--~ assert(false) report "interrupt signal is active 8" severity note;
		--~ wait until(rising_edge(clock));
		--~ m_push <= '1';
		--~ m_data_in <= x"00000000";
		--~ m_addr_in <= x"40000001";
		--~ wait until(rising_edge(clock));
		--~ m_push <= '0';
		--~ wait until(m_empty = '0');
		--~ m_pop <= '1';
		--~ wait for (2 ns);
		--~ assert(m_data_out = x"A32D2368") report "read wrong data" severity error;
		--~ wait until(rising_edge(clock));
		--~ m_pop <= '0';
		
		
		
		assert(false) report "*****complete simualation******" severity note;
		
		wait;
	end process sim;
		
	
	
	
	end DUT;
