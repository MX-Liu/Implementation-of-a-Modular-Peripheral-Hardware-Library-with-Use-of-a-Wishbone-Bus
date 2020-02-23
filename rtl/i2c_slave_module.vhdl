library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.txt_util.all;
use work.wb_type.all;

entity i2c_slave_module is
	generic (
		SLAVE_ADDR : std_ulogic_vector(6 downto 0) := "1010011");
	port (
			clock		: in std_ulogic;
			reset_n		: in std_ulogic;
			---- external fifo control interface
			empty		: in std_ulogic;
			full		: in std_ulogic;
			
			data_in		: in std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			data_out 	: out std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			addr_out 	: out std_ulogic_vector(31 downto 0);
	
			push 		: out std_ulogic;
			pop			: out std_ulogic;
--			wr_en		: out std_ulogic;
--			rd_en		: out std_ulogic;
			
			-- I2C interface 
			sda 		: inout std_logic := 'Z';
			scl 		: inout std_logic := 'Z'
		);
end i2c_slave_module;


architecture rtl of i2c_slave_module is

	-- state vector assignments
	type i2c_slave_state is (
							ST_IDLE,
							ST_COMMAND,
							ST_COMMAND_ACK_READ,
							ST_COMMAND_ACK_WRITE,
							ST_WRITE,
							ST_READ,
							ST_WRITE_ACK,
							ST_READ_ACK
							);

	type pop_state_t is(
						IDLE,
						BEG_POP,
						POP_READ
						);
	
	--flag signal, every phase consists four times read or write
	signal save_to_fifo_flag: std_ulogic := '0';
	signal read_to_fifo_flag: std_ulogic := '0';
	signal save_to_fifo_sync : std_ulogic_vector(1 downto 0);
	signal read_to_fifo_sync : std_ulogic_vector(1 downto 0);
	signal write_enable		: std_ulogic := '0';
	
	signal data_to_read		: std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
	signal data_to_read_buf	: std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
	signal test_reg			: std_ulogic_vector(31 downto 0);
	signal data_to_write	: std_ulogic_vector(DATA_WIDTH  + 31 downto 0);
	
	signal push_nxt			: std_ulogic;
	signal L_push			: std_ulogic;
	signal pop_nxt			: std_ulogic;
	signal L_pop			: std_ulogic;
	
	signal pop_state		: pop_state_t;
	signal pop_state_nxt	: pop_state_t;
	
	signal l_data_out 	: std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
	signal l_addr_out 	: std_ulogic_vector(31 downto 0);
	
	signal data_out_nxt : std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
	signal addr_out_nxt : std_ulogic_vector(31 downto 0);
	
	-- I2C SLAVE model signal 
	signal state      		: i2c_slave_state := ST_IDLE;      -- internal state
	signal bitcounter 		: integer range 0 to 7;            -- counter for bits

	signal address    		: std_ulogic_vector(6 downto 0);      -- received I2C address
	signal shift_data 		: std_ulogic_vector(7 downto 0) := (others=> '0');      -- shifter for received / sent data
	
    -- attention: reads and writes can be aborted (start or stop condition),
    -- so we will not shift by 8 bits in all cases
	signal data       		: std_ulogic_vector(7 downto 0);      -- stored data (1 byte memory)

	signal sda_strong 		: std_logic;
	signal scl_strong 		: std_logic;
	signal sda_out 			: std_logic := '1';
	
	constant DEBUG 			: boolean := true; 		-- true: display debug messages
	signal count_receive 	: integer := 0;
	signal count_send		: integer := 0;
	
	
	
	signal sda_sync			: std_ulogic_vector(3 downto 0);
	signal scl_sync			: std_ulogic_vector(3 downto 0);
	
begin  
	sda_strong <= To_UX01(sda); --cvt_to_ux01(sda);
	scl_strong <= To_UX01(scl);
	sample_prc : process(clock,reset_n)
	begin
		if(reset_n <= '0') then
			sda_sync 			<= (others => '0');
			scl_sync 			<= (others => '0');
			save_to_fifo_sync	<= (others => '0');
			read_to_fifo_sync	<= (others => '0');
			
		elsif(rising_edge(clock)) then
			sda_sync 			<= sda_strong & sda_sync(3 downto 1);
			scl_sync			<= scl_strong & scl_sync(3 downto 1);
			save_to_fifo_sync	<= save_to_fifo_flag & save_to_fifo_sync(1);
			read_to_fifo_sync   <= read_to_fifo_flag & read_to_fifo_sync(1);
		end if;
	end process sample_prc;
	process (clock)
	begin
		if(rising_edge(clock)) then
			-- start and stop condition
			--if sda'event and scl /= '0' then 
			if(sda_sync(3 downto 2) = b"01" or sda_sync(3 downto 2) = b"10") then 
				if(scl /= '0') then 
					if sda = '0' then         
						-- start condition
						state      <= ST_COMMAND;
						bitcounter <= 0;
						--assert not DEBUG report "i2c_slave " & str(SLAVE_ADDR) & ": start condition received" severity note;
					else       
						-- stop condition
						state <= ST_IDLE;
						--assert not DEBUG report "i2c_slave " & str(SLAVE_ADDR) & ": stop condition received" severity note;
					end if;
				end if;
			end if;

			if(scl_sync(3 downto 2) = b"01" or scl_sync(3 downto 2) = b"10") then 
				if(scl /= '0') then
					case state is
						when ST_IDLE =>
							null;
				   
						when ST_COMMAND =>
							if bitcounter /= 7 then
								address <= address(5 downto 0) & sda_strong;
							else
								if (address /= SLAVE_ADDR) then
									state <= ST_IDLE;
									----assert false report slv_to_string(address) severity warning;
									--assert not DEBUG report "i2c_slave " & str(SLAVE_ADDR) & ": command received, wrong address " & str(address) severity note;
								else
									if sda /= '0' then
										state <= ST_COMMAND_ACK_READ;
										read_to_fifo_flag <= '1';
										--assert not DEBUG report "i2c_slave " & str(SLAVE_ADDR) & ": command (read) received" severity note;
									else
										state <= ST_COMMAND_ACK_WRITE;
										--assert not DEBUG report "i2c_slave " & str(SLAVE_ADDR) & ": command (write) received" severity note;
									end if;
								end if;
							end if;
							bitcounter <= (bitcounter + 1) mod 8;
				   
						 when ST_COMMAND_ACK_WRITE =>
							state <= ST_WRITE;

						 when ST_WRITE =>
							if bitcounter = 7 then
								 state <= ST_WRITE_ACK;
								 
							end if;

							shift_data <= shift_data(6 downto 0) & sda_strong;
							bitcounter <= (bitcounter + 1) mod 8;
							
						when ST_WRITE_ACK =>
							
							state <= ST_WRITE;
							
							if (Big_Endian = 1) then
								data_to_write <= data_to_write(DATA_WIDTH + 23 downto 0)&shift_data;
							else
								data_to_write <= shift_data &data_to_write(DATA_WIDTH + 31  downto 8) ;
							end if;
							
							--count_receive <= (count_receive + 1) mod 8;
							count_receive <= count_receive + 1;
							if(count_receive = i2c_rx_byte_cnt_c) then
								save_to_fifo_flag <= '1';
							--------------------------------
								count_receive	  <= 0;
							else
								save_to_fifo_flag <= '0';
							end if;
						 when ST_COMMAND_ACK_READ =>
							read_to_fifo_flag <= '0';
							state      <= ST_READ;
							if (Big_Endian = 1) then
								shift_data <= data_to_read(DATA_WIDTH - 1 downto DATA_WIDTH - 8);
								data_to_read_buf <= data_to_read(DATA_WIDTH - 9 downto 0) & x"FF";
							else
								shift_data <= data_to_read(7 downto 0);
								data_to_read_buf <= x"FF" & data_to_read(DATA_WIDTH - 1 downto DATA_WIDTH - 8);
							end if;
							
							
							
						 when ST_READ =>
							if bitcounter = 7 then
								state <= ST_READ_ACK;
								--assert not DEBUG report "i2c_slave " & str(SLAVE_ADDR) & ": data byte " & str(data) & " sent" severity note;
							end if;
							   bitcounter <= (bitcounter + 1) mod 8;
							   shift_data <= shift_data(6 downto 0) & '0';
								 
						 when ST_READ_ACK =>
							if sda /= '0' then
								state <= ST_IDLE;
								--assert not DEBUG report "i2c_slave " & str(SLAVE_ADDR) & ": no int_ack for read access" severity note;
							else
								state      <= ST_READ;
								if (Big_Endian = 1) then
									shift_data <= data_to_read_buf(DATA_WIDTH - 1 downto DATA_WIDTH - 8);
									data_to_read_buf <= data_to_read(DATA_WIDTH - 9 downto 0) & x"FF";
								else
									shift_data <= data_to_read(7 downto 0);
									data_to_read_buf <= x"FF" & data_to_read(DATA_WIDTH - 1 downto DATA_WIDTH - 8);
								end if;
				
							end if;
					end case;
				end if;
			end if;
		end if;
	end process;
   
	store_data_prc : process(save_to_fifo_sync,L_push,data_to_write,full,l_addr_out,l_data_out)
	begin
		
		push_nxt <= '0';
		addr_out_nxt 	<= l_addr_out;
		data_out_nxt 	<= l_data_out;
		if(save_to_fifo_sync = b"10") then
			if(full = '0') then 
				push_nxt 	<= '1';
				addr_out_nxt 	<= data_to_write(DATA_WIDTH + 31 downto DATA_WIDTH);
				data_out_nxt 	<= data_to_write(DATA_WIDTH - 1  downto 0);

			else
				push_nxt <= '0';
				addr_out_nxt 	<= (others => '0');
				data_out_nxt 	<= (others => '0');
			end if;
		else
			push_nxt <= '0';
			addr_out_nxt 	<= (others => '0');
			data_out_nxt 	<= (others => '0');
		end if;
	end process store_data_prc;
	
	load_data_prc : process(read_to_fifo_sync, pop_state,data_in)
	begin
		pop_state_nxt	<= pop_state;
		pop_nxt			<= '0';
		data_to_read <= (others => '0');
		case pop_state is
			when IDLE =>
				pop_nxt <= '0';
				if(read_to_fifo_sync = b"10") then
					pop_state_nxt <= beg_pop;
				else
					pop_state_nxt <= idle;
				end if;
			when BEG_POP =>
				pop_nxt <= '1';
				pop_state_nxt <= pop_read;
			when POP_READ =>
				pop_nxt <= '0';
				data_to_read <= data_in;
				pop_state_nxt <= idle;
			when others =>
				pop_nxt <= '0';
				pop_state_nxt <= idle;
		end case;
		
	end process load_data_prc;
   
	reg_prc : process(clock, reset_n)
	begin
		if(reset_n = '0') then
			L_pop 		<= '0';
			L_push		<= '0';
			pop_state	<= idle;
			
			l_addr_out	<= (others => '0');
			l_data_out 	<= (others => '0');
		
		elsif(rising_edge(clock)) then
			L_pop 		<= pop_nxt;
			L_push		<= push_nxt;
			pop_state	<= pop_state_nxt;
			
			l_addr_out	<= addr_out_nxt;
			l_data_out 	<= data_out_nxt;
			
		end if;
	end process reg_prc;
	
	pop 	<= L_pop;
	push	<= L_push;

	data_out <= l_data_out;
	addr_out <= l_addr_out;
	
	-- generate sda output
	process (scl_sync,state,shift_data)
		
	begin
		sda_out <= 'Z';
		if(scl_sync(3 downto 2) = "01") then
			case state is
				when ST_COMMAND_ACK_WRITE =>
					sda_out <= '0';
				when ST_COMMAND_ACK_READ =>
					sda_out <= '0';
				when ST_WRITE_ACK =>
					sda_out <= '0';
				when ST_READ =>
					sda_out <= shift_data(7);
				when others =>
					
					sda_out <= 'Z';
			end case;
		end if;
	end process;

	scl <= 'Z';
	sda <= '0' when sda_out = '0' else 'Z';
     
end rtl;


               

               

