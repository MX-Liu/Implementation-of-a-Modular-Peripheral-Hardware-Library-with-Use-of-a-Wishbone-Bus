library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity wb_uart is
	port(
		clock		: in  std_ulogic;
		reset_n		: in  std_ulogic;
		
		m_wb_out	: out wb_master_out;
		m_wb_in		: in  wb_master_in;
		
		s_wb_out 	: out wb_slave_out;
		s_wb_in		: in  wb_slave_in;
		
		uart_tx_o	: out std_ulogic;
		uart_rx_i	: in  std_ulogic
	);
end entity wb_uart;

architecture rtl of wb_uart is 

	signal rx_clkgen_en	: std_ulogic;
	signal rx_clkgen_i	: std_ulogic_vector(07 downto 0);
	signal rx_data_out	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal rx_addr_out	: std_ulogic_vector(31 downto 0);
	signal rx_push 		: std_ulogic;
	signal rx_full		: std_ulogic;
	signal a_rx_full		: std_ulogic;
	signal d_rx_full		: std_ulogic;

	signal tx_clkgen_en	: std_ulogic;
	signal tx_clkgen_i	: std_ulogic_vector(07 downto 0);
	signal tx_data_in	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal tx_pop 		: std_ulogic;
	signal tx_empty		: std_ulogic;

	signal m_empty		: std_ulogic;
	signal a_m_empty		: std_ulogic;
	signal d_m_empty		: std_ulogic;
	
	signal m_full		: std_ulogic;
	signal m_data_in	: std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
	signal m_addr_in	: std_ulogic_vector(31 downto 0);
	signal m_data_out	: std_ulogic_vector(DATA_WIDTH    - 1 downto 0);
	signal m_push		: std_ulogic;
	signal m_pop		: std_ulogic;
	
	signal busy_o		: std_ulogic;
	
	signal s_full		: std_ulogic;
	signal s_data_out	: std_ulogic_vector(DATA_WIDTH    - 1 downto 0);
	signal s_push		: std_ulogic;
	
	signal full			: std_ulogic;
	signal push			: std_ulogic;
	signal data_out		: std_ulogic_vector(DATA_WIDTH    - 1 downto 0);
	
	component uart_rx is
		port (

			clk_i       : in std_ulogic; -- global clock line
			reset_n		: in std_ulogic;
			-- clock generator --
			clkgen_en_o : out std_ulogic; -- enable clock generator
			clkgen_i    : in  std_ulogic_vector(07 downto 0);
			-- com lines --├─neo
			uart_rxd_i  : in  std_ulogic;
			
			-- fifo interface
			data_out 	: out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
			addr_out 	: out std_ulogic_vector(31  downto 0);
			push		: out std_ulogic;
			full 		: in  std_ulogic
		);
	end component uart_rx;
	
	component uart_tx is
		port (
			-- host access --
			clk_i       : in  std_ulogic; -- global clock line
			reset_n		: in std_ulogic;

			-- clock generator --
			clkgen_en_o : out std_ulogic; -- enable clock generator
			clkgen_i    : in  std_ulogic_vector(07 downto 0);
			
			-- fifo interface 
			pop			: out std_ulogic;
			empty 		: in std_ulogic;
			data_in 	: in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
			-- com lines --
			uart_txd_o  : out std_ulogic
	   
		);
	end component uart_tx;
	
	
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
	

	component clock_generator is 
	port(
		clock	: in std_ulogic;
		reset_n	: in std_ulogic;
		
		clkgen_en	: in std_ulogic;
		clkgen_o    : out  std_ulogic_vector(07 downto 0)
	);
	end component clock_generator;

	component uart_master_wrapper is
	port(
			clock		: in std_ulogic;
			reset_n		: in std_ulogic;
			
			---- bus interface
			wb_in		: in wb_master_in;
			wb_out		: out wb_master_out;
			
			---- fifo interface
			empty		: in std_ulogic;
			full		: in std_ulogic;
			
			data_in		: in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
			addr_in 	: in std_ulogic_vector(31  downto 0);
			data_out 	: out std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			
			push 		: out std_ulogic;
			pop			: out std_ulogic;
			
			busy_o		: out std_ulogic
	
		);
	end component uart_master_wrapper;
	
	component uart_slave_wrapper is
	port(
			clock		: in std_ulogic;
			reset_n		: in std_ulogic;
			
			---- bus interface
			wb_in		: in wb_slave_in;
			wb_out		: out wb_slave_out;
			
			---- fifo interface
			full		: in std_ulogic;
			data_out	: out std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			push 		: out std_ulogic;
			fifo_busy	: in std_ulogic
		);
	end component uart_slave_wrapper;

begin
	inst_uart_rx : uart_rx
	port map(

		clk_i       => clock,
		reset_n		=> reset_n,
		-- clock generator --
		clkgen_en_o => rx_clkgen_en,
		clkgen_i   	=> rx_clkgen_i,
		-- com lines --
		uart_rxd_i  => uart_rx_i,
		
		-- fifo interface
		data_out 	=> rx_data_out,
		addr_out    => rx_addr_out,
		push		=> rx_push,
		full 		=> rx_full
	);
	
	inst_master_wrapper : uart_master_wrapper
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
		addr_in		=> m_addr_in,
		
		data_out 	=> m_data_out,
			
		push 		=> m_push,
		pop			=> m_pop,
			
		busy_o		=> busy_o
	);
	
	inst_write_data_fifo : fifo 
	generic map(
		fifo_width => DATA_WIDTH,
		fifo_depth => FIFO_DEPTH
		)
	port map(
		clock		=> clock,
		reset_n		=> reset_n,
		data_in		=> rx_data_out,
		data_out	=> m_data_in,

		empty		=> d_m_empty,
		full		=> d_rx_full,

		pop			=> m_pop,
		push		=> rx_push
	);
	
	inst_address_fifo : fifo 
	generic map(
		fifo_width => 32,
		fifo_depth => FIFO_DEPTH
		)
	port map(
		clock		=> clock,
		reset_n		=> reset_n,
		data_in		=> rx_addr_out,
		data_out	=> m_addr_in,

		empty		=> a_m_empty,
		full		=> a_rx_full,

		pop			=> m_pop,
		push		=> rx_push
	);
	
	m_empty <= a_m_empty or d_m_empty;
	rx_full <= a_rx_full or d_rx_full;

	inst_clock_gen_rx : clock_generator
	port map(
		clock		=> clock,
		reset_n		=> reset_n,
		
		clkgen_en	=> rx_clkgen_en,
		clkgen_o    => rx_clkgen_i
	);

	inst_uart_tx : uart_tx
	port map(
			clk_i       => clock,
			reset_n		=> reset_n,
			clkgen_en_o => tx_clkgen_en,
			clkgen_i    => tx_clkgen_i,
			pop			=> tx_pop,
			empty 		=> tx_empty,
			data_in 	=> tx_data_in,
			-- com lines --
			uart_txd_o  => uart_tx_o
	);
	
	inst_slave_wrapper : uart_slave_wrapper
	port map(
			clock		=> clock,
			reset_n		=> reset_n,
			wb_in		=> s_wb_in,
			wb_out		=> s_wb_out,
			full		=> s_full,
			data_out	=> s_data_out,
			push 		=> s_push,
			fifo_busy	=> busy_o
		);

	inst_read_data_fifo : fifo
	generic map(
		fifo_width => DATA_WIDTH,
		fifo_depth => FIFO_DEPTH
		)
	port map(
		clock		=> clock,
		reset_n		=> reset_n,
		data_in		=> data_out,
		data_out	=> tx_data_in,

		empty		=> tx_empty,
		full		=> full,

		pop			=> tx_pop,
		push		=> push
	);
	

	data_out <= s_data_out when busy_o = '0' else m_data_out;
	push	 <= s_push	   when busy_o = '0' else m_push;
	s_full 	 <= full when busy_o = '0' else '1';
	m_full	 <= full when busy_o = '1' else '1';
	
	inst_clock_gen_tx : clock_generator
	port map(
		clock		=> clock,
		reset_n		=> reset_n,
		
		clkgen_en	=> tx_clkgen_en,
		clkgen_o    => tx_clkgen_i
	);
	
end rtl;
