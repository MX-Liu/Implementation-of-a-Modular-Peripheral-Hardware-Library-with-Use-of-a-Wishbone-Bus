library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity tb_wb_timer is

end entity tb_wb_timer;

architecture dut of tb_wb_timer is

	constant period   	: time := 20 ns; -- main clock period
	signal clock			: std_ulogic := '0';
	signal reset_n			: std_ulogic;
	signal s_wb_in			: wb_slave_in;
	signal s_wb_out			: wb_slave_out;
	signal irq_o			: std_ulogic;
	
	signal clkgen_en_o 		:std_ulogic;
	signal clkgen_i         :std_ulogic_vector(07 downto 0);
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
	
	component wb_timer 
	port (
		clock		: in std_ulogic;
		reset_n		: in std_ulogic;
		
		-- wishbone interface 
		wb_in		: in wb_slave_in;
		wb_out		: out wb_slave_out;

		-- clock generator --
		--~ clkgen_en_o : out std_ulogic; -- enable clock generator
		--~ clkgen_i    : in  std_ulogic_vector(07 downto 0);
		-- interrupt --
		irq_o       : out std_ulogic  -- interrupt request
	);
	end component wb_timer;
	
	component master_wrapper 
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
	end component master_wrapper;
	
begin
	inst_wb_timer : wb_timer
	port map(
		clock		=> clock,
		reset_n		=> reset_n,
		-- wishbone interface 
		wb_in		=> s_wb_in,
		wb_out		=> s_wb_out,
		-- clock generator --
		--~ clkgen_en_o => clkgen_en_o,
		--~ clkgen_i   	=> clkgen_i, 
		-- interrupt --
		irq_o       => irq_o
	);
	
	inst_clock_gen : clock_generator
    port map(
        clock   	=> clock,
        reset_n 	=> reset_n,
        
        clkgen_en   => clkgen_en_o,
        clkgen_o    => clkgen_i
    );
    
	inst_master : master_wrapper
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
	s_wb_in.sel_i <= m_wb_out.sel_o;

	clock <= not clock after period/2;
	
	sim : process
	begin
		reset_n 	<= '0';
		m_push		<= '0';
		m_data_in 	<= (others => '0');
		m_addr_in	<= (others => '0');
		m_wr_en		<= '0';
		m_rd_en		<= '0';
		wait for 3 * period;
		reset_n 	<= '1';
		
		-- write count register
		wait until (rising_edge(clock));
		assert (m_full = '0') report "the status of the fifo has something wrong" severity error;
		m_wr_en <= '1';
		m_push <= '1';
		m_data_in <= x"00000064";
		m_addr_in <= x"80000002";
		-- write threshold value register
		wait until (rising_edge(clock));
		m_data_in <= x"000000C8";
		m_addr_in <= x"80000003";
		-- write countrol register
		wait until (rising_edge(clock));
		m_data_in <= x"00000007";
		m_addr_in <= x"80000001";
		wait until (rising_edge(clock));
		m_push <= '0';
		wait until (irq_o = '1');
		assert false report "the interrupt signal successfully asset" severity note;
		-- write count register again 
		m_wr_en <= '1';
		m_push <= '1';
		m_data_in <= x"000000BC";
		m_addr_in <= x"80000002";
		wait until (rising_edge(clock));
		m_push <= '0';
		wait until (irq_o = '1');
		assert false report "the interrupt signal successfully asset" severity note;
		m_wr_en <= '0';
		
		wait for(10*period);
		-- read register 1
		wait until (rising_edge(clock));
		m_rd_en <= '1';
		m_push 	<= '1';
		m_data_in <= x"00000000";
		m_addr_in <= x"40000001";
		
		-- read register 2
		wait until (rising_edge(clock));
		m_rd_en <= '1';
		m_push 	<= '1';
		m_data_in <= x"00000000";
		m_addr_in <= x"40000002";
		
		-- read register 3
		wait until (rising_edge(clock));
		m_rd_en <= '1';
		m_push 	<= '1';
		m_data_in <= x"00000000";
		m_addr_in <= x"40000003";
		wait until (rising_edge(clock));
		m_push 	<= '0';
		wait for 10*period;
		m_rd_en <= '0';
		
		-- write control register to stop timer
		wait until (rising_edge(clock));
		m_wr_en <= '1';
		m_push <= '1';
		m_data_in <= x"00000000";
		m_addr_in <= x"80000001";
		wait until (rising_edge(clock));
		m_push <= '0';
		wait;
	end process sim;
	
	read_sim : process
	begin
		m_pop <= '0';
		wait until (rising_edge(clock));
		wait until(m_empty = '0');
		m_pop <= '1';
		wait for 3 ns;
		assert (m_data_out = x"00000007") report "read countrol register false" severity error;
		
		wait until (rising_edge(clock));
		wait until(m_empty = '0');
		m_pop <= '1';
		wait for 3 ns;
		assert false report "The value of counter register is " & integer'image(to_integer(unsigned(m_data_out))) severity note;
		
		wait until (rising_edge(clock));
		wait until(m_empty = '0');
		m_pop <= '1';
		wait for 3 ns;
		assert (m_data_out = x"000000C8") report "read threshold register false" severity error;
		m_pop <= '0';
		
		wait until (rising_edge(clock));
		assert false report "********complete the simulation******" severity note;
		wait;
	end process read_sim;

end dut;
