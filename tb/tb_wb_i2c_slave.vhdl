library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;
library std;
use std.textio.all;

----------------------------------------------------------------------
-- Entity declaration.

entity tb_wb_i2c_slave is
	generic(
		-- file with data to be send to fpga
		FILE_NAME_COMMAND 	: string := "command_master2i2c_slave.txt";
		-- file for dump of data, received by pc
		FILE_NAME_DUMP 	: string := "dump_i2c_slave2master.txt"
	);
end tb_wb_i2c_slave;

architecture DUT of tb_wb_i2c_slave is
	
	signal clock  		: std_ulogic;
	signal reset_n		: std_ulogic;
	constant PERIOD		: time := 100 ns;
	
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
	
	signal sda			: std_logic;
	signal scl 			: std_logic;
	signal i2c_irq_o	: std_logic;
	
	file file_command	: text open read_mode is FILE_NAME_COMMAND;
	file file_dump   	: text open write_mode is FILE_NAME_DUMP;
	
	type bytelist_t is array (0 to 515) of std_ulogic_vector(7 downto 0);
	type wordlist_t	is array (0 to 31) of std_ulogic_vector(31 downto 0);
	signal send_buf 	: wordlist_t;
	
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
			
			data_in		: in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
			addr_in 	: in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
			data_out 	: out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
			
			push 		: in std_ulogic;
			pop			: in std_ulogic
		);
	end component master_wrapper;
	
	component wb_i2c_slave 
	port(
		clock		: in std_ulogic;
		reset_n		: in std_ulogic;
		
		slave_in 	: in wb_slave_in;
		slave_out 	: out wb_slave_out;
		
		sda 		: inout std_logic := 'Z';
		scl 		: inout std_logic := 'Z';
		
		i2c_irq_o	: out std_ulogic
	);
	end component wb_i2c_slave;
	
	component i2c_slave 
	generic (
		SLAVE_ADDR : std_ulogic_vector(6 downto 0) := "1010011");
	port (
		sda : inout std_logic := 'Z';
		scl : inout std_logic := 'Z'
		);
	end component i2c_slave;
	
begin
	inst_master : master_wrapper
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
	
	inst_i2c_slave : i2c_slave
	generic map(
		SLAVE_ADDR => "1010011")
	port map(
		sda	=> sda,
		scl => scl
		);
	
	
	inst_wb_i2c_slave : wb_i2c_slave 
	port map(
		clock		=> clock,
		reset_n		=> reset_n,
		slave_in 	=> slave_in,
		slave_out 	=> slave_out,
		sda 		=> sda,
		scl 		=> scl,
		i2c_irq_o	=> i2c_irq_o
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
					m_push 		<= '1';
					m_addr_in 	<= commandlist(8*i)&commandlist(8*i+1)&commandlist(8*i+2)&commandlist(8*i+3);
					m_data_in	<= commandlist(8*i+4)&commandlist(8*i+5)&commandlist(8*i+6)&commandlist(8*i+7);
					-- store the data that is send to data register 
					if(commandlist(8*i) = x"80" and commandlist(8*i+3) = x"00") then
						send_buf(dat_cnt) <= commandlist(8*i+4)&commandlist(8*i+5)&commandlist(8*i+6)&commandlist(8*i+7);
						dat_cnt := dat_cnt + 1;
					end if;
					
					wait for(PERIOD);
					m_push 		<= '0';
					wait for(PERIOD);
				else
					m_push 		<= '1';
					m_addr_in 	<= commandlist(8*i)&commandlist(8*i+1)&commandlist(8*i+2)&commandlist(8*i+3);
					m_data_in	<= commandlist(8*i+4)&commandlist(8*i+5)&commandlist(8*i+6)&commandlist(8*i+7);
					-- store the data that is send to data register 
					if(commandlist(8*i) = x"80" and commandlist(8*i+3) = x"00") then
						send_buf(dat_cnt) <= commandlist(8*i+4)&commandlist(8*i+5)&commandlist(8*i+6)&commandlist(8*i+7);
						dat_cnt := dat_cnt + 1;
					end if;
					wait for(PERIOD);
					m_push 		<= '0';
					wait for(PERIOD);
				end if;
			else
				exit;
			end if;
		end loop;
		
		assert(false) report "******master write data to slave complete******" severity note;
		
		-- read data from slave 
		for i in 0 to 3 loop
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
				assert(unsigned(send_buf(i)) = unsigned(m_data_out)) report "Master receive error data" severity error;
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
				
				assert(unsigned(send_buf(i)) = unsigned(m_data_out)) report "Master receive error data" severity error;
				wait for(PERIOD);
				m_pop <= '0';
				wait until(rising_edge(clock));
			end if;
		end loop;
		
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
	
	
	clock_generation : process
    begin
        clock <= '0';
        wait for PERIOD / 2;
        clock <= '1';
        wait for PERIOD / 2;
    end process clock_generation;
	
end DUT;
	
