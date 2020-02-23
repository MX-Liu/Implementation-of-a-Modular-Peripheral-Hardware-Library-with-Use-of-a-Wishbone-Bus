library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity tb_burst is
	
end entity tb_burst;

architecture DUT of tb_burst is
	constant t_clock_c   	: time := 20 ns; -- main clock period
	signal clock			: std_ulogic := '0';
	signal reset_n			: std_ulogic;
	
	signal s_wb_in			: wb_slave_in;
	signal s_wb_out			: wb_slave_out;
			
			---- fifo interface
	signal s_empty		: std_ulogic;
	signal s_full		: std_ulogic;
			
	signal s_data_in	: std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
	signal s_data_out 	: std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			--the fifo to store the intern register addr,the control and status signal is same as the master_to_uart_fifo.
	signal s_addr_out 	: std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			
	signal s_push 		: std_ulogic;
	signal s_pop		: std_ulogic;
	
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
			pop			: in std_ulogic;
	
			-- simulation
			wr_en		: in std_ulogic;
			rd_en		: in std_ulogic
		);
	end component master_wrapper_with_burst;
	
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
			addr_out 	: out std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			
			push 		: in std_ulogic;
			pop			: in std_ulogic	
		);
	end component slave_wrapper_with_burst;

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
		pop			=> m_pop,
	
		-- simulation
		wr_en		=> m_wr_en,
		rd_en		=> m_rd_en
		
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
	
	
	inst_slave : slave_wrapper_with_burst
	port map(
		clock		=> clock,
		reset_n		=> reset_n,
		
		---- bus interface
		wb_in		=> s_wb_in,
		wb_out		=> s_wb_out,
		
		---- fifo interface
		empty		=> s_empty,
		full		=> s_full,
		
		data_in		=> s_data_in,
		data_out 	=> s_data_out,
		--the fifo to store the intern register addr,the control and status signal is same as the master_to_uart_fifo.
		addr_out 	=> s_addr_out,
		
		push 		=> s_push,
		pop			=> s_pop
	);
	
	
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
		s_pop 	<= '0';
		s_push  <= '0';
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"A32D2361";
		m_addr_in <= x"00002392";
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"A32D2362";
		m_addr_in <= x"89D02393";
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"A32D2363";
		m_addr_in <= x"89D02394";
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"A32D2364";
		m_addr_in <= x"89D02395";
		-- wait until(rising_edge(clock));
		-- m_push <= '1';
		-- m_data_in <= x"A32D2365";
		-- m_addr_in <= x"89D02396";
		-- wait until(rising_edge(clock));
		-- m_push <= '1';
		-- m_data_in <= x"A32D2366";
		-- m_addr_in <= x"89D02397";
		-- wait until(rising_edge(clock));
		-- m_push <= '1';
		-- m_data_in <= x"A32D236a";
		-- m_addr_in <= x"89D02398";
		-- wait until(rising_edge(clock));
		-- m_push <= '1';
		-- m_data_in <= x"A32D236b";
		-- m_addr_in <= x"89D02398";
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"A32D236c";
		m_addr_in <= x"89D02398";
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"A32D2367";
		m_addr_in <= x"89D02399";
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"A32D2368";
		m_addr_in <= x"80D02399";
		
		wait until(rising_edge(clock));
		m_push <= '0';
		wait until(rising_edge(clock));
		m_wr_en <= '1';
		
		wait for(100 ns);
		m_wr_en <= '0';
		wait until(rising_edge(clock));
		s_push <= '1';
		s_data_in <= x"A32D2361";
		wait until(rising_edge(clock));
		s_push <= '1';
		s_data_in <= x"A32D2362";
		wait until(rising_edge(clock));
		s_push <= '1';
		s_data_in <= x"A32D2363";
		wait until(rising_edge(clock));
		s_push <= '1';
		s_data_in <= x"A32D2364";
		wait until(rising_edge(clock));
		s_push <= '1';
		s_data_in <= x"A32D2365";
		wait until(rising_edge(clock));
		s_push <= '1';
		s_data_in <= x"A32D2361";
		wait until(rising_edge(clock));
		s_push <= '0';
		
		wait until(rising_edge(clock));
		wait until(rising_edge(clock));
		wait until(rising_edge(clock));
		wait until(rising_edge(clock));
		
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"A32D2361";
		m_addr_in <= x"50002392";
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"A32D2362";
		m_addr_in <= x"50D02393";
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"A32D2363";
		m_addr_in <= x"50D02394";
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"A32D2368";
		m_addr_in <= x"50D02399";
		wait until(rising_edge(clock));
		m_push <= '1';
		m_data_in <= x"A32D2364";
		m_addr_in <= x"50D02395";
		
		
		wait until(rising_edge(clock));
		m_push <= '0';
		wait until(rising_edge(clock));
		m_wr_en <= '0';
		m_rd_en <= '1';
		wait for (100 ns);
		m_wr_en <= '0';
		m_rd_en <= '0';
		
		wait;
	end process sim;
		
	
	
	
	end DUT;
