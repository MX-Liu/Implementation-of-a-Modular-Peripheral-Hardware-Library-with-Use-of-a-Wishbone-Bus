library ieee;
use ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
use work.wb_type.all;

entity fifo is
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
end entity fifo;

architecture rtl of fifo is
	
	signal w_ptr		: std_ulogic_vector(index_size(fifo_depth) downto 0);
	signal w_ptr_nxt	: std_ulogic_vector(index_size(fifo_depth) downto 0);
	signal full_nxt		: std_ulogic; 
	
	signal r_ptr		: std_ulogic_vector(index_size(fifo_depth) downto 0);
	signal r_ptr_nxt	: std_ulogic_vector(index_size(fifo_depth) downto 0);
	signal empty_nxt 	: std_ulogic;
	
	signal l_full     	: std_ulogic;
	signal l_empty    	: std_ulogic;
	type t_ram is array(0 to FIFO_DEPTH - 1) of std_ulogic_vector(FIFO_WIDTH - 1 downto 0);
	signal ram			: t_ram;
	signal ram_nxt		: t_ram;
	
begin
	
	--------------------------------------------------------------------
	-- fifo write process-----------------------------------------------
	--------------------------------------------------------------------
	full <= l_full;
	
	-- write pointer counter 
	w_ptr_nxt 	<= std_ulogic_vector(unsigned(w_ptr) + 1) when push = '1' and l_full = '0' else w_ptr;
	
	full_nxt <= '1' when (w_ptr_nxt(index_size(fifo_depth)) = not(r_ptr(index_size(fifo_depth))) and w_ptr_nxt(index_size(fifo_depth) - 1 downto 0) = r_ptr(index_size(fifo_depth) - 1 downto 0)) else '0';
	
	-- write into ram
	write_prc : process(w_ptr, data_in,push,l_full,ram)
	begin
		ram_nxt <= ram;
		if(push = '1' and l_full = '0') then
			ram_nxt(to_integer(unsigned(w_ptr(index_size(fifo_depth) - 1 downto 0)))) <= data_in;
		end if;
	end process write_prc;
	
	w_sync_prc: process(clock,reset_n)
	begin
		if(reset_n = '0') then
			w_ptr 		<= (others => '0');
			l_full		<= '0';
			ram			<= (others => (others=> '0'));
		elsif(rising_edge(clock)) then
			w_ptr		<= w_ptr_nxt;
			l_full		<= full_nxt;
			ram			<= ram_nxt;
		end if;
	end process w_sync_prc;	
	
	
	--------------------------------------------------------------------
	-- fifo read process -----------------------------------------------
	--------------------------------------------------------------------
	empty <= l_empty;
	
	-- read pointer counter
	r_ptr_nxt 	<= std_ulogic_vector(unsigned(r_ptr) + 1) when pop = '1' and l_empty = '0' else r_ptr;
	
	-- judge empty logic 
	empty_nxt <= '1' when (r_ptr_nxt(index_size(fifo_depth) downto 0) = w_ptr(index_size(fifo_depth) downto 0)) else '0';
	
	-- read from fifo
	data_out	<= ram(to_integer(unsigned(r_ptr(index_size(fifo_depth) - 1 downto 0))));
	
	r_sync_prc: process(clock,reset_n)
	begin
		if(reset_n = '0') then
			r_ptr 		<= (others => '0');
			l_empty 		<= '1';
		elsif(rising_edge(clock)) then
			r_ptr		<= r_ptr_nxt;
			l_empty		<= empty_nxt;
		end if;
	end process r_sync_prc;
	
end rtl;

--~ architecture rtl of fifo is
	
	--~ type t_ram			is array (0 to 7) of std_ulogic_vector(fifo_width - 1 downto 0);

	--~ signal ram 			: t_ram;
	--~ signal ram_nxt 		: t_ram;
	--~ signal wpter		: integer range 0 to 7 := 0;
	--~ signal rpter 		: integer range 0 to 7 := 0;
	--~ signal wpter_v		: std_ulogic_vector(2 downto 0) := (others => '0');
	--~ signal rpter_v 		: std_ulogic_vector(2 downto 0) := (others => '0');
	
	--~ signal wpter_v_nxt	: std_ulogic_vector(2 downto 0) := (others => '0');
	--~ signal rpter_v_nxt 	: std_ulogic_vector(2 downto 0) := (others => '0');
	
	--~ signal lastop		: std_logic;
	--~ signal lastop_nxt		: std_logic;
	--~ signal L_empty		: std_ulogic;
	--~ signal L_full		: std_ulogic;
	--~ signal l_data_out	: std_ulogic_vector(fifo_width - 1 downto 0);
	--~ signal l_data_nxt	: std_ulogic_vector(fifo_width - 1 downto 0);
	
	--~ --- RAM attribute to inhibit bypass-logic - Altera only! ---
	--~ attribute ramstyle : string;
	--~ attribute ramstyle of ram : signal is "no_rw_check";
	--~ attribute ramstyle of ram_nxt : signal is "no_rw_check";
	
--~ begin

	
	--~ sysc_process : process(clock)
	--~ begin
		--~ if(rising_edge(clock)) then
			--~ if(reset_n = '0') then
				--~ lastop <= '0';
				--~ wpter_v <= (others => '0');
				--~ rpter_v <= (others => '0');
				--~ l_data_out <= (others => '0');
			--~ else
				--~ ram <= ram_nxt;
				--~ wpter_v <= wpter_v_nxt;
				--~ rpter_v <= rpter_v_nxt;
				--~ l_data_out <= l_data_nxt;
				--~ lastop	<= lastop_nxt;
			--~ end if;
		--~ end if;
	--~ end process sysc_process;
	
	
	--~ pnt_prc: process(pop,push,L_empty,L_full,wpter_v,rpter_v,lastop)
	--~ begin
		 
		--~ wpter_v_nxt <= wpter_v;
		--~ rpter_v_nxt <= rpter_v;
		--~ lastop_nxt  <= lastop;
		--~ -- coverage off	
		--~ if(push = '1' and pop = '1') then 
			
			--~ if(L_empty = '0') then
				--~ wpter_v_nxt <= std_ulogic_vector(unsigned (wpter_v) + 1);
				--~ rpter_v_nxt <= std_ulogic_vector(unsigned (rpter_v) + 1);
				--~ lastop_nxt  <= '1';
			
			--~ else
				--~ wpter_v_nxt <= std_ulogic_vector(unsigned (wpter_v) + 1);
				--~ lastop_nxt  <= '1';
			--~ end if;
		--~ -- coverage on
		--~ else 
			--~ if(push = '1' and L_full = '0') then
				--~ wpter_v_nxt <= std_ulogic_vector(unsigned (wpter_v) + 1);
				--~ lastop_nxt  <= '1';
			--~ end if;
			--~ if(pop = '1' and L_empty = '0') then
				--~ rpter_v_nxt <= std_ulogic_vector(unsigned (rpter_v) + 1);
				--~ lastop_nxt  <= '0';
			--~ end if;	
		--~ end if;	
	--~ end process pnt_prc;

	--~ comb_process_state : process(wpter_v, rpter_v, lastop)
	--~ begin
		--~ wpter <= to_integer(unsigned (wpter_v));
		--~ rpter <= to_integer(unsigned (rpter_v));
		
		--~ if(wpter_v = rpter_v) then
			--~ if(lastop = '1') then
				--~ L_full <= '1';
				--~ L_empty <= '0';
			--~ else
				--~ L_full <= '0';
				--~ L_empty <= '1';
			--~ end if;
		--~ else
			--~ L_full <= '0';
			--~ L_empty <= '0';
		--~ end if;	

	--~ end process comb_process_state;
	
	--~ empty	<= L_empty;
	--~ full	<= L_full;
	
	
	--~ comb_process_out : process(wpter, rpter, pop, push,L_empty,L_full,ram,data_in,l_data_out)
	--~ begin
		
		--~ ram_nxt <= ram;
		--~ l_data_nxt <= l_data_out;
			--~ if(pop = '0' and push = '0') then
				--~ ram_nxt <= ram;
			--~ elsif(pop = '1' and push = '0') then
				--~ if(L_empty = '0') then
					--~ l_data_nxt <= ram(rpter);
				--~ --else  
				--~ --	l_data_nxt <= (others => '0');
				--~ end if;
			--~ elsif(pop = '0' and push = '1') then
				--~ -- coverage off
				--~ if(L_full = '0') then
					--~ ram_nxt(wpter) <= data_in;
				--~ end if;
				
			--~ -- coverage off	
			--~ elsif(pop = '1' and push = '1') then
				--~ if(L_empty = '0') then
					--~ l_data_nxt <= ram(rpter);
					--~ ram_nxt(wpter) <= data_in;
				--~ --else
				--~ --	l_data_nxt <= (others => '0');
				--~ end if;
				--~ -- when the fifo is L_empty, fifo can only be written. 
				--~ if(L_empty = '1') then
					--~ ram_nxt(wpter) <= data_in;
				--~ end if;
			--~ end if;	
			--~ -- coverage on
		
			
	--~ end process comb_process_out;
	
	--~ data_out <= l_data_nxt;

--~ end architecture rtl;
