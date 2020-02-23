library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity asyn_fifo is
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
end entity asyn_fifo;

architecture rtl of asyn_fifo is
	
	signal w_ptr		: std_ulogic_vector(index_size(fifo_depth) downto 0);
	signal w_ptr_nxt	: std_ulogic_vector(index_size(fifo_depth) downto 0);
	signal w_ptr_shift	: std_ulogic_vector(index_size(fifo_depth) downto 0);
	signal gray_w_ptr	: std_ulogic_vector(index_size(fifo_depth) downto 0);
	signal gray_w_nxt	: std_ulogic_vector(index_size(fifo_depth) downto 0);
	signal gray_w_2nxt	: std_ulogic_vector(index_size(fifo_depth) downto 0);
	signal gray_w_3nxt	: std_ulogic_vector(index_size(fifo_depth) downto 0);
	
	signal full_nxt		: std_ulogic; 
	
	
	signal r_ptr		: std_ulogic_vector(index_size(fifo_depth) downto 0);
	signal r_ptr_nxt	: std_ulogic_vector(index_size(fifo_depth) downto 0);
	signal r_ptr_shift	: std_ulogic_vector(index_size(fifo_depth) downto 0);
	signal gray_r_ptr	: std_ulogic_vector(index_size(fifo_depth) downto 0);
	signal gray_r_nxt	: std_ulogic_vector(index_size(fifo_depth) downto 0);
	signal gray_r_2nxt	: std_ulogic_vector(index_size(fifo_depth) downto 0);
	signal gray_r_3nxt	: std_ulogic_vector(index_size(fifo_depth) downto 0);
	signal empty_nxt 	: std_ulogic;
	
	signal l_full     : std_ulogic;
	signal l_empty    : std_ulogic;
	type t_ram is array(0 to FIFO_DEPTH - 1) of std_ulogic_vector(FIFO_WIDTH - 1 downto 0);
	signal ram			: t_ram;
	signal ram_nxt		: t_ram;
begin
	
	--------------------------------------------------------------------
	-- fifo write process-----------------------------------------------
	--------------------------------------------------------------------
	full <= l_full;
	
	-- write pointer counter 
	w_ptr_nxt 	<= std_ulogic_vector(unsigned(w_ptr) + 1) when wr_en = '1' and l_full = '0' else w_ptr;
	
	-- right shift one bit
	w_ptr_shift	<= '0'&w_ptr_nxt(index_size(fifo_depth) downto 1);
	
	-- bin to gray code 
	gray_w_3nxt <=  w_ptr_shift xor w_ptr_nxt;
	
	-- judge full logic
	full_nxt <= '1' when (gray_w_3nxt(index_size(fifo_depth) downto index_size(fifo_depth)-1) = not(gray_r_ptr(index_size(fifo_depth) downto index_size(fifo_depth)-1))) and (gray_w_3nxt(index_size(fifo_depth) - 2 downto 0) = gray_r_ptr(index_size(fifo_depth) - 2 downto 0)) else '0';
	
	-- write into ram
	write_prc : process(w_ptr, data_i,wr_en,l_full,ram)
	begin
		ram_nxt <= ram;
		if(wr_en = '1' and l_full = '0') then
			ram_nxt(to_integer(unsigned(w_ptr(index_size(fifo_depth)-1 downto 0)))) <= data_i;
		end if;
	end process write_prc;
	--ram_nxt(to_integer(unsigned(w_ptr(2 downto 0)))) <= data_i when wr_en = '1' and l_full = '0' else ram(to_integer(unsigned(w_ptr(2 downto 0))));
	
	w_sync_prc: process(wr_clk,reset_n)
	begin
		if(reset_n = '0') then
			w_ptr 		<= (others => '0');
			
			gray_r_ptr 	<= (others => '0');
			gray_r_nxt	<= (others => '0');
			
			gray_w_2nxt	<= (others => '0');
			l_full		<= '0';
			ram			<= (others => (others=> '0'));
		elsif(rising_edge(wr_clk)) then
			w_ptr		<= w_ptr_nxt;
			gray_w_2nxt <= gray_w_3nxt;
			
			-- cross clock domain
			gray_r_ptr 	<= gray_r_nxt;
			gray_r_nxt  <= gray_r_2nxt;
			
			l_full		<= full_nxt;
			ram			<= ram_nxt;
		end if;
	end process w_sync_prc;	
	
	
	--------------------------------------------------------------------
	-- fifo read process -----------------------------------------------
	--------------------------------------------------------------------
	empty <= l_empty;
	
	-- read pointer counter
	r_ptr_nxt 	<= std_ulogic_vector(unsigned(r_ptr) + 1) when rd_en = '1' and l_empty = '0' else r_ptr;
	-- right shift one bit
	r_ptr_shift	<= '0'&r_ptr_nxt(index_size(fifo_depth) downto 1);
	-- bin to gray code
	gray_r_3nxt <=  r_ptr_shift xor r_ptr_nxt;
	
	-- judge empty logic 
	empty_nxt <= '1' when (gray_w_ptr(index_size(fifo_depth) downto 0) = gray_r_3nxt(index_size(fifo_depth) downto 0)) else '0';
	-- read from fifo
	data_o	<= ram(to_integer(unsigned(r_ptr(index_size(fifo_depth)-1 downto 0))));
	
	r_sync_prc: process(rd_clk,reset_n)
	begin
		if(reset_n = '0') then
			r_ptr 		<= (others => '0');
			gray_r_2nxt <= (others => '0');
			
			gray_w_ptr 	<= (others => '0');
			gray_w_nxt	<= (others => '0');
			
			l_empty 		<= '1';
		elsif(rising_edge(rd_clk)) then
			r_ptr		<= r_ptr_nxt;
			gray_r_2nxt	<= gray_r_3nxt;
			
			-- cross clock domain
			gray_w_ptr 	<= gray_w_nxt;
			gray_w_nxt  <= gray_w_2nxt;
			l_empty		<= empty_nxt;
		end if;
	end process r_sync_prc;
	
end rtl;
