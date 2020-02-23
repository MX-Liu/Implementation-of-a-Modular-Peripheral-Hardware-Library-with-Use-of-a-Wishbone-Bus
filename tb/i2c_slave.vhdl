library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.txt_util.all;

entity i2c_slave is
	generic (
		SLAVE_ADDR : std_ulogic_vector(6 downto 0) := "1010011");
	port (
		sda : inout std_logic := 'Z';
		scl : inout std_logic := 'Z'
		);
end i2c_slave;


architecture func of i2c_slave is

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

	type register_t is array (0 to 7) of std_ulogic_vector(7 downto 0);
	signal data_receive	  	: register_t;
	
	signal data_to_read		: std_ulogic_vector(31 downto 0);
	signal data_to_read_buf	: std_ulogic_vector(31 downto 0);
	signal test_reg			: std_ulogic_vector(31 downto 0);
	signal data_to_write	: std_ulogic_vector(31 downto 0);
	
	signal state      		: i2c_slave_state := ST_IDLE;      -- internal state
	signal bitcounter 		: integer range 0 to 8;            -- counter for bits

	signal address    		: std_ulogic_vector(6 downto 0);      -- received I2C address
	signal shift_data 		: std_ulogic_vector(7 downto 0) := (others=> '0');      -- shifter for received / sent data
	
    -- attention: reads and writes can be aborted (start or stop condition),
    -- so we will not shift by 8 bits in all cases
	signal data       		: std_ulogic_vector(7 downto 0);      -- stored data (1 byte memory)

	signal sda_strong 		: std_logic;
	signal sda_out 			: std_logic := '1';
	constant DEBUG 			: boolean := false; 		-- true: display debug messages
	signal count_receive 	: integer := 0;
	signal count_send		: integer := 0;
	signal save_to_fifo_flag: std_ulogic := '0';
	signal read_to_fifo_flag: std_ulogic := '0';
	
	
begin  
	sda_strong <= To_UX01(sda); --cvt_to_ux01(sda);
	process (sda, scl)
	begin
		-- start and stop condition
		if sda'event and scl /= '0' then   
			if sda = '0' then         
				-- start condition
				state      <= ST_COMMAND;
				bitcounter <= 0;
				assert not DEBUG report "i2c_slave " & str(SLAVE_ADDR) & ": start condition received" severity note;
			else       
				-- stop condition
				state <= ST_IDLE;
				assert not DEBUG report "i2c_slave " & str(SLAVE_ADDR) & ": stop condition received" severity note;
			end if;
		end if;


		-- read data and update internal state
		if scl'event and scl /= '0' then  
			case state is
				when ST_IDLE =>
					null;
           
				when ST_COMMAND =>
					if bitcounter /= 7 then
						address <= address(5 downto 0) & sda_strong;
					else
						if (address /= SLAVE_ADDR) then
							state <= ST_IDLE;
							--assert false report slv_to_string(address) severity warning;
							assert not DEBUG report "i2c_slave " & str(SLAVE_ADDR) & ": command received, wrong address " & str(address) severity note;
						else
							if sda /= '0' then
								state <= ST_COMMAND_ACK_READ;
								read_to_fifo_flag <= '1';
								assert not DEBUG report "i2c_slave " & str(SLAVE_ADDR) & ": command (read) received" severity note;
							else
								state <= ST_COMMAND_ACK_WRITE;
								assert not DEBUG report "i2c_slave " & str(SLAVE_ADDR) & ": command (write) received" severity note;
							end if;
						end if;
					end if;
					bitcounter <= (bitcounter + 1) mod 8;
           
				 when ST_COMMAND_ACK_WRITE =>
					state <= ST_WRITE;

				 when ST_WRITE =>
					if bitcounter = 7 then
						 state <= ST_WRITE_ACK;
						 shift_data <= shift_data(6 downto 0) & sda_strong;
						 bitcounter <= (bitcounter + 1) mod 8;
					else
						shift_data <= shift_data(6 downto 0) & sda_strong;
						bitcounter <= (bitcounter + 1) mod 8;
						state <= ST_WRITE;
					end if;
					
				when ST_WRITE_ACK =>
					assert not DEBUG report "i2c_slave " & str(SLAVE_ADDR) & ": data byte " & str(shift_data) & " received" severity note;
					data  <= shift_data;
					state <= ST_WRITE;
					--data_to_write <= shift_data & data_to_write(31 downto 8);
					data_to_write <= data_to_write(23 downto 0) & shift_data;
					
					--~ data_receive(count_receive) <= shift_data;
					count_receive <= (count_receive + 1) mod 4;
					if(count_receive = 3) then
						save_to_fifo_flag <= '1';
					else
						save_to_fifo_flag <= '0';
					end if;
				 when ST_COMMAND_ACK_READ =>
					read_to_fifo_flag <= '0';
					state      <= ST_READ;
					--shift_data <= data;
					
					--~ shift_data <= data_to_read(7 downto 0);
					--~ data_to_read_buf <= x"00" & data_to_read(31 downto 8);
					
					shift_data <= data_to_read(31 downto 24);
					data	   <= data_to_read(31 downto 24);
					data_to_read_buf <= data_to_read(23 downto 0) & x"FF";
					
				 when ST_READ =>
					if bitcounter = 7 then
						state <= ST_READ_ACK;
						assert not DEBUG report "i2c_slave " & str(SLAVE_ADDR) & ": data byte " & str(data) & " sent" severity note;
					end if;
					   bitcounter <= (bitcounter + 1) mod 8;
					   shift_data <= shift_data(6 downto 0) & '1';
					  	 
				 when ST_READ_ACK =>
					if sda /= '0' then
						--~ count_send <= (count_send + 1) mod 8;
						state <= ST_IDLE;
						assert not DEBUG report "i2c_slave " & str(SLAVE_ADDR) & ": no int_ack for read access" severity note;
					else
						state      <= ST_READ;
						shift_data <= data_to_read_buf(31 downto 24);
						data	   <= data_to_read_buf(31 downto 24);
						data_to_read_buf <= data_to_read_buf(23 downto 0) & X"FF";
						assert not DEBUG report "i2c_slave " & str(SLAVE_ADDR) & ": int_ack for read access received" severity note;
					end if;
			end case;
		end if;
   end process;
   
   save_data_prc : process(save_to_fifo_flag)
   begin
		if(rising_edge(save_to_fifo_flag)) then
			test_reg <= data_to_write;
		end if;
   end process save_data_prc;
	
	pop_data_prc : process(read_to_fifo_flag)
	begin
		if(rising_edge(read_to_fifo_flag)) then
			data_to_read <= test_reg;
		end if;
   end process pop_data_prc;
   
  -- generate sda output
  process (scl)
    constant td : time := 800 ns;
  begin
    if scl'event and scl = '0' then
      case state is
        when ST_COMMAND_ACK_WRITE =>
          sda_out <= '0' after td;
        when ST_COMMAND_ACK_READ =>
          sda_out <= '0' after td;
        when ST_WRITE_ACK =>
          sda_out <= '0' after td;
        when ST_READ =>
          sda_out <= shift_data(7) after td;
          --sda_out <= data_receive(count_send)(7) after td;
        when others =>
          sda_out <= 'Z' after td;
      end case;
    end if;
  end process;

  scl <= 'Z';
  sda <= '0' when sda_out = '0' else 'Z';
     
end func;

--   specify
--
--      -- timingchecks for I2C bus protocol
--
--      specparam
--         std_scl_period = 10000, -- timing in I2C standard mode
--         std_scl_low    =  4700,
--         std_scl_high   =  4000,
--         std_tsu_sta    =  4700,
--         std_thd_sta    =  4000,
--         std_tsu_sto    =  4000,
--         std_sta_sto    =  4700,
--         std_tsu_dat    =   250,
--         std_thd_dat    =   300,
--
--         fast_scl_period = 2500, -- timing in I2C fast mode
--         fast_scl_low    = 1300,
--         fast_scl_high   =  600,
--         fast_tsu_sta    = 1300,
--         fast_thd_sta    =  600,
--         fast_tsu_sto    =  600,
--         fast_sta_sto    = 1300,
--         fast_tsu_dat    =  100,
--         fast_thd_dat    =  300;
--
--      $period(posedge scl, std_scl_period);                  -- scl period
--      $period(negedge scl, std_scl_period);                  -- scl period
--      $width(negedge scl, std_scl_low);                      -- scl high time
--      $width(posedge scl, std_scl_high);                     -- scl low time
--
--      $setup(posedge scl, negedge sda &&& scl, std_tsu_sta); -- rep. start condition setup time
--      $hold(negedge sda &&& scl, negedge scl, std_thd_sta);  -- start condition hold time
--
--      $setup(posedge scl, posedge sda &&& scl, std_tsu_sto); -- stop condition setup time
--
--      $setup(posedge sda &&& scl, negedge sda, std_sta_sto); -- bus free time
--
--      $setup(sda, posedge scl, std_tsu_dat);                 -- data setup time
--      $hold(negedge scl, sda, std_thd_dat);                  -- data hold time
--
--
--      -- delay of sda output
--      specparam
--         std_slave_sda_delay  = std_scl_low - std_tsu_dat,   -- slowest possible slave
--         fast_slave_sda_delay = fast_scl_low - fast_tsu_dat;
--
--      (scl *> sda) = std_slave_sda_delay;
--
--   endspecify
               
