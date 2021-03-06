library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;
library std;
use std.textio.all;

entity tb_wb_dma is
	generic(
		-- file with data to be send to fpga
		FILE_NAME_COMMAND 	: string := "command_wb_dma_slave.txt";
		-- file for dump of data, received by pc
		FILE_NAME_DUMP 	: string := "dump_wb_dma_slave.txt"
	);
	
end entity tb_wb_dma;


architecture DUT of tb_wb_dma is
	
	constant PERIOD  : time := 20 ns; -- main clock period
	signal clock		: std_ulogic := '0';
	signal dma_clock	: std_ulogic := '0';
	signal reset_n		: std_ulogic;
	
	signal master_in	: wb_master_in;
	signal master_out	: wb_master_out;
	
	signal slave_in 	: wb_slave_in;
	signal slave_out	: wb_slave_out;

	signal m_empty		: std_ulogic;
	signal m_full		: std_ulogic;
	signal m_data_in	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal m_data_out 	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal m_addr_in 	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal m_push 		: std_ulogic;
	signal m_pop		: std_ulogic;
	signal m_wr_en		: std_ulogic;
	signal m_rd_en		: std_ulogic;
	
	signal mem_en		: std_ulogic;
 	signal mem_wr		: std_ulogic;
	signal mem_rd		: std_ulogic;
	signal mem_addr_o	: std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
	signal mem_dat_o	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal mem_dat_i	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	
	file file_command	: text open read_mode is FILE_NAME_COMMAND;
	file file_dump   	: text open write_mode is FILE_NAME_DUMP;
	
	type bytelist_t is array (0 to 515) of std_ulogic_vector(7 downto 0);
	type wordlist_t	is array (0 to 31) of std_ulogic_vector(31 downto 0);
	signal send_buf 	: wordlist_t;
	
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
	
	component wb_dma_slave is
	port(
		clock		: std_ulogic;
		dma_clock	: in std_ulogic;
		reset_n		: std_ulogic;
		
		---- bus interface
		wb_in		: in wb_slave_in;
		wb_out		: out wb_slave_out;
		
		-- memory interface
		mem_en		: out  std_ulogic;
		mem_wr		: out std_ulogic;
		mem_rd		: out std_ulogic;
		mem_addr_o	: out std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
		mem_dat_o	: out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
		mem_dat_i	: in  std_ulogic_vector(DATA_WIDTH - 1 downto 0)
	);
	end component wb_dma_slave;
	
	component ram 
	port(
		clock 		: in std_ulogic;
		reset_n 	: in std_ulogic;
		mem_en_i    : in std_ulogic;
        mem_wr_i    : in std_ulogic;
        mem_rd_i    : in std_ulogic;
        mem_addr_i  : in std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
        mem_dat_i   : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        mem_dat_o   : out  std_ulogic_vector(DATA_WIDTH - 1 downto 0)
	);
	end component ram;
	
	
begin
	inst_master : master_wrapper_with_burst
	port map(
			clock		=> clock,
			reset_n		=> reset_n,
			wb_in		=> master_in,
			wb_out		=> master_out,
			empty		=> m_empty,
			full		=> m_full,
			data_in		=> m_data_in,
			data_out 	=> m_data_out,
			addr_in     => m_addr_in,
			push 		=> m_push,
			pop			=> m_pop
	);
	
	inst_wb_dma : wb_dma_slave
	port map(
		clock		=> clock,
		dma_clock	=> dma_clock,
		reset_n		=> reset_n,
		
		---- bus interface
		wb_in		=> slave_in,
		wb_out		=> slave_out,
		
		-- memory interface
		mem_en		=> mem_en,
		mem_wr		=> mem_wr,
		mem_rd		=> mem_rd,
		mem_addr_o	=> mem_addr_o,
		mem_dat_o	=> mem_dat_o,
		mem_dat_i	=> mem_dat_i
	);
	
	
	isnt_ram : ram
	port map(
		clock 		=> dma_clock,
		reset_n 	=> reset_n,
		mem_en_i    => mem_en,
        mem_wr_i    => mem_wr,
        mem_rd_i    => mem_rd,
        mem_addr_i  => mem_addr_o,
        mem_dat_i   => mem_dat_o,
        mem_dat_o   => mem_dat_i
	);
	
	
	
	slave_in.cyc_i  <= master_out.cyc_o;
	slave_in.stb_i  <= master_out.stb_o;
	slave_in.we_i   <= master_out.we_o;
	slave_in.sel_i  <= master_out.sel_o;
	slave_in.adr_i  <= master_out.adr_o;
	slave_in.dat_i  <= master_out.dat_o;
	slave_in.bte_i  <= master_out.bte_o;
	slave_in.cti_i  <= master_out.cti_o;
	master_in.dat_i <= slave_out.dat_o;
	master_in.ack_i <= slave_out.ack_o;
	
	clock <= not clock after (PERIOD/2);
	dma_clock <= not dma_clock after (PERIOD/2);
	
	-- test master write slave
	test : process
		variable commandlist : bytelist_t:= (others => (others => '0'));
		variable active_line : line;
		variable neol : boolean := false;
		variable data_value : integer:= 0;
		variable cnt : natural := 0;
		variable dat_cnt : natural := 0;
		
		variable receivelist 	: bytelist_t;
		variable rcv_active_line : line;
		
	begin

		wait for(PERIOD);
		reset_n <= '0';
		m_pop <= '0';
		m_push <= '0';
		wait for(3*PERIOD);
		reset_n <= '1';
		wait for( PERIOD);
		
		-- preload list with undefined
		commandlist := (others => (others => 'U'));
		-- read preload file
		
		while not endfile(file_command) loop
			-- read line
			readline(file_command, active_line);
			-- loop until end of line
			loop
				read(active_line, data_value, neol);
				exit when not neol;
				-- write command to array
				commandlist(cnt) := std_ulogic_vector(to_unsigned(data_value, 8));
				-- increment counter
				cnt := cnt + 1;
			end loop;
		end loop;
		file_close(file_command);
		
		--test fifo signal
		assert(m_empty = '1') report "empty signal has falsh reset" severity error;
		assert(m_full =  '0') report "full signal has falsh reset"  severity error;
		wait for(PERIOD);
		wait for(PERIOD/2);
		
		--write data and address to fifo of master interface 
		for i in 0 to 127 loop
			if commandlist(i*8)(0) /= 'U' then 
				if(m_full =  '1') then
					wait until(m_full =  '0');
					wait for(PERIOD);
					m_push 		<= '1';
					m_addr_in 	<= commandlist(8*i)&commandlist(8*i+1)&commandlist(8*i+2)&commandlist(8*i+3);
					m_data_in	<= commandlist(8*i+4)&commandlist(8*i+5)&commandlist(8*i+6)&commandlist(8*i+7);
					-- store the data that is send to data register 
					if(unsigned(commandlist(8*i)) = 137 and unsigned(commandlist(8*i+3)) = 2) then
						send_buf(dat_cnt) <= commandlist(8*i+4)&commandlist(8*i+5)&commandlist(8*i+6)&commandlist(8*i+7);
						dat_cnt := dat_cnt + 1;
					end if;
					
					--~ wait for(PERIOD);
					--~ m_push 		<= '0';
					wait for(PERIOD);
				else
					m_push 		<= '1';
					m_addr_in 	<= commandlist(8*i)&commandlist(8*i+1)&commandlist(8*i+2)&commandlist(8*i+3);
					m_data_in	<= commandlist(8*i+4)&commandlist(8*i+5)&commandlist(8*i+6)&commandlist(8*i+7);
					-- store the data that is send to data register 
					if(unsigned(commandlist(8*i)) = 137 and unsigned(commandlist(8*i+3)) = 2) then
						send_buf(dat_cnt) <= commandlist(8*i+4)&commandlist(8*i+5)&commandlist(8*i+6)&commandlist(8*i+7);
						dat_cnt := dat_cnt + 1;
					end if;
					--~ wait for(PERIOD);
					--~ m_push 		<= '0';
					wait for(PERIOD);
				end if;
			else
				exit;
			end if;
		end loop;
		m_push 		<= '0';
		
		assert(false) report "******master write data to slave complete******" severity note;
		
		
		for i in 0 to 15 loop
			if(m_empty = '1')then
				wait until(m_empty = '0');
				m_pop <= '1';
				wait for 2 ns;
				receivelist(i*8)   := (others => '0');
				receivelist(i*8+1) := (others => '0');
				receivelist(i*8+2) := (others => '0');
				receivelist(i*8+3) := (others => '0');
				receivelist(i*8+4) := m_data_out(31 downto 24);
				receivelist(i*8+5) := m_data_out(23 downto 16);
				receivelist(i*8+6) := m_data_out(15 downto  8);
				receivelist(i*8+7) := m_data_out(7  downto  0);
				
				--assert(send_buf(i) = m_data_out) report "Master receive error data" severity error;
				assert(send_buf(i) = m_data_out) report "Master receive error data" severity error;
				wait for(PERIOD);
				m_pop <= '0';
				
				
				wait until(rising_edge(clock));
			else
				m_pop <= '1';
				wait for 2 ns;
				receivelist(i*8)   := (others => '0');
				receivelist(i*8+1) := (others => '0');
				receivelist(i*8+2) := (others => '0');
				receivelist(i*8+3) := (others => '0');
				
				receivelist(i*8+4) := m_data_out(31 downto 24);
				receivelist(i*8+5) := m_data_out(23 downto 16);
				receivelist(i*8+6) := m_data_out(15 downto  8);
				receivelist(i*8+7) := m_data_out(7  downto  0);
				
				assert(send_buf(i) = m_data_out) report "Master receive error data" severity error;
				wait for(PERIOD);
				m_pop <= '0';
				wait until(rising_edge(clock));
			end if;
		end loop;
		
		
		wait for PERIOD;
		m_push 		<= '0';
		
		-- loop over max number of bytes
		for i in 0 to 127 loop
			-- check if recieved byte is valid, else stop
			if receivelist(i)(0) /= 'U' then 
				-- add value to line (will result in one value per line)
				write(rcv_active_line, to_integer(unsigned(receivelist(i))));
				-- write line to file
				writeline(file_dump, rcv_active_line);
			end if;
		end loop;
		
		file_close(file_dump);
		assert(false) report "******master read data to slave complete******" severity note;
		assert(false) report "******complete******" severity note;
		
		wait;
	end process test;
	
	
end DUT;


--~ architecture DUT of tb_wb_dma is
	--~ constant t_clock_c   	: time := 20 ns; -- main clock period
	--~ signal clock			: std_ulogic := '0';
	--~ signal dma_clock		: std_ulogic := '0';
	--~ signal reset_n			: std_ulogic;
	
	--~ signal s_wb_in			: wb_slave_in;
	--~ signal s_wb_out			: wb_slave_out;
			
	--~ signal mem_en		: std_ulogic;
 	--~ signal mem_wr		: std_ulogic;
	--~ signal mem_rd		: std_ulogic;
	--~ signal mem_addr_o	: std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
	--~ signal mem_dat_o	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	--~ signal mem_dat_i	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	
	--~ ---- bus interface
	--~ signal m_wb_in		: wb_master_in;
	--~ signal m_wb_out		: wb_master_out;
			
			--~ ---- fifo interface
	--~ signal	m_empty		: std_ulogic;
	--~ signal	m_full		: std_ulogic;
			
	--~ signal	m_data_in	: std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
	--~ signal	m_addr_in 	: std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
	--~ signal	m_data_out 	: std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			
	
	--~ signal	m_push 		: std_ulogic;
	--~ signal	m_pop		: std_ulogic;
	
			--~ -- simulation
	--~ signal	m_wr_en		: std_ulogic;
	--~ signal	m_rd_en		: std_ulogic;
			
	--~ component master_wrapper_with_burst is
	--~ port(
			--~ clock		: in std_ulogic;
			
			--~ reset_n		: in std_ulogic;
			
			
			--~ ---- bus interface
			--~ wb_in		: in wb_master_in;
			--~ wb_out		: out wb_master_out;
			
			--~ ---- fifo interface
			--~ empty		: out std_ulogic;
			--~ full		: out std_ulogic;
			
			--~ data_in		: in std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			--~ addr_in 	: in std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			--~ data_out 	: out std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			
	
			--~ push 		: in std_ulogic;
			--~ pop			: in std_ulogic
			
		--~ );
	--~ end component master_wrapper_with_burst;
	
	--~ component wb_dma_slave is
	--~ port(
		--~ clock		: std_ulogic;
		--~ dma_clock	: in std_ulogic;
		--~ reset_n		: std_ulogic;
		
		--~ ---- bus interface
		--~ wb_in		: in wb_slave_in;
		--~ wb_out		: out wb_slave_out;
		
		--~ -- memory interface
		--~ mem_en		: out  std_ulogic;
		--~ mem_wr		: out std_ulogic;
		--~ mem_rd		: out std_ulogic;
		--~ mem_addr_o	: out std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
		--~ mem_dat_o	: out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
		--~ mem_dat_i	: in  std_ulogic_vector(DATA_WIDTH - 1 downto 0)
	--~ );
	--~ end component wb_dma_slave;
	
	--~ component ram 
	--~ port(
		--~ clock 		: in std_ulogic;
		--~ reset_n 	: in std_ulogic;
		--~ mem_en_i    : in std_ulogic;
        --~ mem_wr_i    : in std_ulogic;
        --~ mem_rd_i    : in std_ulogic;
        --~ mem_addr_i  : in std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
        --~ mem_dat_i   : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        --~ mem_dat_o   : out  std_ulogic_vector(DATA_WIDTH - 1 downto 0)
	--~ );
	--~ end component ram;

--~ begin
	--~ inst_master : master_wrapper_with_burst
	--~ port map(
		--~ clock		=> clock,
		--~ reset_n		=> reset_n,
		
		--~ ---- bus interface
		--~ wb_in		=> m_wb_in,
		--~ wb_out		=> m_wb_out,
		
		--~ ---- fifo interface
		--~ empty		=> m_empty,
		--~ full		=> m_full,
		
		--~ data_in		=> m_data_in,
		--~ addr_in 	=> m_addr_in,
		--~ data_out 	=> m_data_out,
		
	
		--~ push 		=> m_push,
		--~ pop			=> m_pop
		
	--~ );
	
	--~ m_wb_in.ack_i <= s_wb_out.ack_o;
	--~ m_wb_in.dat_i <= s_wb_out.dat_o;
	--~ s_wb_in.cyc_i <= m_wb_out.cyc_o;
	--~ s_wb_in.adr_i <= m_wb_out.adr_o;
	--~ s_wb_in.dat_i <= m_wb_out.dat_o;
	--~ s_wb_in.cti_i <= m_wb_out.cti_o;
	--~ s_wb_in.bte_i <= m_wb_out.bte_o;
	--~ s_wb_in.stb_i <= m_wb_out.stb_o;
	--~ s_wb_in.we_i  <= m_wb_out.we_o;
	--~ s_wb_in.sel_i <= m_wb_out.sel_o;
	
	
	--~ inst_wb_dma : wb_dma_slave
	--~ port map(
		--~ clock		=> clock,
		--~ dma_clock	=> dma_clock,
		--~ reset_n		=> reset_n,
		
		--~ ---- bus interface
		--~ wb_in		=> s_wb_in,
		--~ wb_out		=> s_wb_out,
		
		--~ -- memory interface
		--~ mem_en		=> mem_en,
		--~ mem_wr		=> mem_wr,
		--~ mem_rd		=> mem_rd,
		--~ mem_addr_o	=> mem_addr_o,
		--~ mem_dat_o	=> mem_dat_o,
		--~ mem_dat_i	=> mem_dat_i
	--~ );
	
	--~ isnt_ram : ram
	--~ port map(
		--~ clock 		=> dma_clock,
		--~ reset_n 	=> reset_n,
		--~ mem_en_i    => mem_en,
        --~ mem_wr_i    => mem_wr,
        --~ mem_rd_i    => mem_rd,
        --~ mem_addr_i  => mem_addr_o,
        --~ mem_dat_i   => mem_dat_o,
        --~ mem_dat_o   => mem_dat_i
	--~ );
	
	--~ clock <= not clock after (t_clock_c);
	--~ dma_clock <= not dma_clock after (t_clock_c/4);
	--~ reset_n <= '0', '1' after 40 ns;
	
	--~ sim : process
	--~ begin
		
		--~ wait for (50 ns);
		--~ wait until(rising_edge(clock));
		--~ m_pop 	<= '0';
		--~ m_push 	<= '0';
		--~ m_wr_en <= '0';
		--~ m_rd_en <= '0';
		--~ m_wr_en <= '1';
		--~ wait until(rising_edge(clock));
		--~ m_wr_en <= '1';
		--~ m_push <= '1';
		--~ m_data_in <= x"F8000301";
		--~ m_addr_in <= x"80002301";
		--~ wait until(rising_edge(clock));
		--~ m_push <= '1';
		--~ m_data_in <= x"F8000399";
		--~ m_addr_in <= x"89D02302";
		--~ wait until(rising_edge(clock));
		--~ m_push <= '1';
		--~ m_data_in <= x"F8000302";
		--~ m_addr_in <= x"89D02302";
		--~ wait until(rising_edge(clock));
		--~ m_push <= '1';
		--~ m_data_in <= x"A32D2363";
		--~ m_addr_in <= x"89D02302";
		--~ wait until(rising_edge(clock));
		--~ m_push <= '1';
		--~ m_data_in <= x"A32D2364";
		--~ m_addr_in <= x"89D02302";
		--~ wait until(rising_edge(clock));
		--~ m_push <= '1';
		--~ m_data_in <= x"A32D2365";
		--~ m_addr_in <= x"89D02302";
		--~ wait until(rising_edge(clock));
		--~ m_push <= '1';
		--~ m_data_in <= x"A32D2364";
		--~ m_addr_in <= x"89D02302";
		--~ wait until(rising_edge(clock));
		--~ m_push <= '1';
		--~ m_data_in <= x"A32D236c";
		--~ m_addr_in <= x"89D02302";
		--~ wait until(rising_edge(clock));
		--~ m_push <= '1';
		--~ m_data_in <= x"A32D2334";
		--~ m_addr_in <= x"89D02302";
		--~ wait until(rising_edge(clock));
		--~ m_push <= '1';
		--~ m_data_in <= x"A32D2323";
		--~ m_addr_in <= x"89D02302";
		--~ wait until(rising_edge(clock));
		--~ m_push <= '1';
		--~ m_data_in <= x"A32D2367";
		--~ m_addr_in <= x"89D02302";
		--~ wait until(rising_edge(clock));
		--~ m_push <= '1';
		--~ m_data_in <= x"A32D2368";
		--~ m_addr_in <= x"80D02302";
		
		--~ -- disable all signal of the memory interface
		--~ wait until(rising_edge(clock));
		--~ m_push <= '1';
		--~ m_data_in <= x"00000000";
		--~ m_addr_in <= x"80D02301";
		
		--~ -- begin to memory singel write  
		--~ wait until(rising_edge(clock));
		--~ m_push <= '1';
		--~ m_data_in <= x"C8000306";
		--~ m_addr_in <= x"80D02391";
		--~ wait until(rising_edge(clock));
		--~ m_push <= '1';
		--~ m_data_in <= x"43289749";
		--~ m_addr_in <= x"80D02392";
		
		--~ wait until(rising_edge(clock));
		--~ m_push <= '1';
		--~ m_data_in <= x"C8000307";
		--~ m_addr_in <= x"80D02391";
		--~ wait until(rising_edge(clock));
		--~ m_push <= '1';
		--~ m_data_in <= x"45478787";
		--~ m_addr_in <= x"80D02392";
		--~ wait until(rising_edge(clock));
		--~ m_push <= '0';
		--~ m_wr_en <= '0';	
	

		--~ wait for(500 ns);
		--~ wait until(rising_edge(clock));
		--~ m_push <= '1';
		--~ m_data_in <= x"C4000001";
		--~ m_addr_in <= x"80000001";
		--~ wait until(rising_edge(clock));
		--~ m_push <= '1';
		--~ m_data_in <= x"00000000";
		--~ m_addr_in <= x"80000001";
		--~ wait until(rising_edge(clock));
		--~ m_push <= '0';
		
		
		--~ wait;
	--~ end process sim;
		
	
	
	
	--~ end DUT;
