library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_asyn_fifo is 

end entity tb_asyn_fifo;

architecture dut of tb_asyn_fifo is 
	
	signal w_period 		: time := 20 ns;
	signal r_period 		: time := 50 ns;
	signal wr_clk 			: std_ulogic := '0';
	signal rd_clk			: std_ulogic := '0';
	signal reset_n			: std_ulogic;
	signal wr_en			: std_ulogic;
	signal data_i			: std_ulogic_vector(31 downto 0);
	signal full 			: std_ulogic;
	
	signal rd_en			: std_ulogic;
	signal data_o			: std_ulogic_vector(31 downto 0);
	signal empty 			: std_ulogic;
	
	component asyn_fifo
	generic(
		FIFO_WIDTH 	: integer := 32;
		FIFO_DEPTH 	: integer := 8
	);
	port(
		reset_n		: in std_ulogic;
		
		wr_en		: in std_ulogic;
		wr_clk		: in std_ulogic;
		data_i		: in std_ulogic_vector(FIFO_WIDTH - 1 downto 0);
		full		: out std_ulogic;
		
		rd_en 		: in std_ulogic;
		rd_clk		: in std_ulogic;
		data_o 		: out std_ulogic_vector(FIFO_WIDTH - 1 downto 0);
		empty 		: out std_ulogic
	);
	end component asyn_fifo;
	
begin
	inst_asyn_fifo : asyn_fifo
	generic map(
		FIFO_WIDTH 	=> 32,
		FIFO_DEPTH 	=> 8
	)
	port map(
		reset_n		=> reset_n,
		
		wr_en		=> wr_en,
		wr_clk		=> wr_clk,
		data_i		=> data_i,
		full		=> full,
		
		rd_en 		=> rd_en,
		rd_clk		=> rd_clk,
		data_o 		=> data_o,
		empty 		=> empty
	);
	
	
	wr_clk <= not wr_clk after w_period/2;
	rd_clk <= not rd_clk after r_period/2;
	
	reset_prc : process
	begin
		reset_n <= '0';
		wait for 100 ns;
		reset_n <= '1';
		wait;
	end process reset_prc;
	
	wr_prc :  process
	begin
		wr_en <= '0';
		data_i <= (others=> '0');
		wait for 100 ns;
		wait until (rising_edge(wr_clk));
		wr_en <= '1';
		data_i <= x"dace6730";
		wait until (rising_edge(wr_clk));
		wr_en <= '0';
		wait until (rising_edge(wr_clk));
		wr_en <= '1';
		data_i <= x"e2cee231";
		wait until (rising_edge(wr_clk));
		wr_en <= '1';
		data_i <= x"78987232";
		wait until (rising_edge(wr_clk));
		wr_en <= '1';
		data_i <= x"79898123";
		wait until (rising_edge(wr_clk));
		wr_en <= '1';
		data_i <= x"d21ee234";
		wait until (rising_edge(wr_clk));
		wr_en <= '1';
		data_i <= x"d21ee235";
		wait until (rising_edge(wr_clk));
		wr_en <= '1';
		data_i <= x"d21ee236";
		wait until (rising_edge(wr_clk));
		wr_en <= '1';
		data_i <= x"d21ee237";
		
		wait until (rising_edge(wr_clk));
		wr_en <= '0';
		
		wait until(full = '0');
		wr_en <= '1';
		data_i <= x"d21ee238";
		wait until (rising_edge(wr_clk));
		wr_en <= '0';
		
		wait;
	end process wr_prc;

	rd_prc : process
	begin
		rd_en <= '0';
		wait for 150 ns;
		
		wait until (empty = '0');
		
		rd_en <= '1';
		wait for 2 ns;
		assert (data_o = x"dace6730") report "fifo read falsh data" severity error;
		wait until (rising_edge(rd_clk));
		rd_en <= '0';
		
		wait until (rising_edge(rd_clk));
		rd_en <= '1';
		wait for 2 ns;
		assert (data_o = x"e2cee231") report "fifo read falsh data" severity error;
		
		wait until (rising_edge(rd_clk));
		rd_en <= '1';
		wait for 2 ns;
		assert (data_o = x"78987232") report "fifo read falsh data" severity error;
		
		wait until (rising_edge(rd_clk));
		rd_en <= '1';
		wait for 2 ns;
		assert (data_o = x"79898123") report "fifo read falsh data" severity error;
		
		wait until (rising_edge(rd_clk));
		rd_en <= '1';
		wait for 2 ns;
		assert (data_o = x"d21ee234") report "fifo read falsh data" severity error;
		
		wait until (rising_edge(rd_clk));
		rd_en <= '1';
		wait for 2 ns;
		assert (data_o = x"d21ee235") report "fifo read falsh data" severity error;
		
		wait until (rising_edge(rd_clk));
		rd_en <= '1';
		wait for 2 ns;
		assert (data_o = x"d21ee236") report "fifo read falsh data" severity error;
		
		wait until (rising_edge(rd_clk));
		rd_en <= '1';
		wait for 2 ns;
		assert (data_o = x"d21ee237") report "fifo read falsh data" severity error;
				
		
		wait until (rising_edge(rd_clk));
		rd_en <= '0';
		
		wait;
		
	end process rd_prc;

end dut;
