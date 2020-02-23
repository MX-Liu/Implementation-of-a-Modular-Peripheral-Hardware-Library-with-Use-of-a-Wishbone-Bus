library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_control is
	port(
		clock       : in  std_ulogic;       -- global clock
		reset_n     : in  std_ulogic;       -- global reset_n
		iobus_cs    : in  std_ulogic;       -- module select
		iobus_wr    : in  std_ulogic;       -- register write enable
		iobus_addr  : in  std_ulogic_vector(1 downto 0);  -- register address
		iobus_din   : in  std_ulogic_vector(7 downto 0);  -- register input data
		iobus_dout  : out std_ulogic_vector(7 downto 0);  -- register output data
		iobus_irq   : out std_ulogic;       -- interrupt request
		iobus_ack   : in  std_ulogic;       -- interrupt acknowledge
		--                                                    
		i2c_sda_in  : in  std_ulogic;       -- I2C data, input (registered in pin_mapper)
		i2c_en      : out std_ulogic;       -- enable sda, scl in pin_mapper
		i2c_sda_out : out std_ulogic;       -- I2C data, output (externally driven on 'sda_out = 0')
		i2c_scl_out : out std_ulogic        -- I2C clock, output (externally driven on 'scl_out = 0')
		);
end i2c_control;

architecture rtl of i2c_control is

	-- register addresses
    constant SLV_ADDR_I2C_CONTROL : std_ulogic_vector(1 downto 0) := b"00";
    constant SLV_ADDR_I2C_DATA    : std_ulogic_vector(1 downto 0) := b"01";
    constant SLV_ADDR_I2C_TIMER   : std_ulogic_vector(1 downto 0) := b"10";
    
    -- memory-mapped (i/o range) processor registers
    -- I2CCR: I2C control register
    signal i2c_control     : std_ulogic_vector(7 downto 0);  -- control register
    -- bit 7 (r/w): I2CIE  interrupt enable
    -- bit 6 (r/w): I2CE   enable sda and scl pins
    -- bit 5 (r/w): START  I2C start condition before next write access
    -- bit 4 (r/w): STOP   I2C stop condition after end of bus access
    -- bit 3 (r/w)         not used
    -- bit 2 (r/w): DONE   read, write or STOP done, interrupt flag
    -- bit 1 (r)  : BFREE  bus free (there was a STOP)
    -- bit 0 (r)  : ACK    Ack of last transfer
    signal i2c_control_nxt : std_ulogic_vector(7 downto 0);

    -- I2CDR: I2C data register
    signal i2c_data     : std_ulogic_vector(7 downto 0);  -- read / write data (r/w)
    signal i2c_data_nxt : std_ulogic_vector(7 downto 0);

    -- auxiliary signal for register shift
    signal shift_data : std_ulogic;

    -- I2CTR: I2C timer register
    signal i2c_timer     : std_ulogic_vector(7 downto 0);  -- clock divider reload value (r/w)
    signal i2c_timer_nxt : std_ulogic_vector(7 downto 0);

    -- I2C clock = a quarter of  system clock speed / (i2c_timer +1)

    -- names for i2c_control bits
    signal i2c_control_inten : std_ulogic;
    signal i2c_en_i          : std_ulogic;
    signal i2c_control_start : std_ulogic;
    signal i2c_control_stop  : std_ulogic;
    signal i2c_control_done  : std_ulogic;
    signal i2c_control_bfree : std_ulogic;
    signal i2c_control_ack   : std_ulogic;

    signal i2c_data_msb : std_ulogic;

    -- auxiliary signals for control register status bits
    signal clr_start          : std_ulogic;
    signal clr_stop_set_bfree : std_ulogic;
    signal clr_bfree          : std_ulogic;
    signal copy_ack           : std_ulogic;
    signal clr_done           : std_ulogic;
    signal set_done           : std_ulogic;

    signal start_read_access  : std_ulogic;
    signal start_write_access : std_ulogic;

    -- i2c statemachine
    type i2c_state is ( ST_IDLE,           -- idle state
                        ST_REP_START,      -- write repeated start condition
                        ST_START,          -- write start condition
                        ST_READ,           -- read 8 bits from bus
                        ST_WRITE,          -- write 8 bits to bus
                        ST_READ_ACK,       -- write int_ack for read transfer
                        ST_WRITE_ACK,      -- read int_ack of write transfer
                        ST_STOP);

    signal state     : i2c_state;         -- current state
    signal state_nxt : i2c_state;         -- next state

    signal sub_state     : std_ulogic_vector(4 downto 0);
    signal sub_state_nxt : std_ulogic_vector(4 downto 0);
    -- each non-idle state consists of 2 (REP_START) or
    -- 4 (others) sub-states, READ and WRITE for 8 bits

    signal wait_counter     : std_ulogic_vector(7 downto 0);
    signal wait_counter_nxt : std_ulogic_vector(7 downto 0);
    -- I2C clock divider
    -- create I2C_CLK*4 from system clock

    -- output registers for I2C signals
    signal sda_out     : std_ulogic;
    signal sda_out_nxt : std_ulogic;
    -- corresponding next value pseudo regs
    signal scl_out     : std_ulogic;
    signal scl_out_nxt : std_ulogic;

begin  -- rtl

	-- names for i2c_control bits
	i2c_control_inten <= i2c_control(7);
	i2c_en_i          <= i2c_control(6);  -- enable sda and scl in pin_mapper
	i2c_control_start <= i2c_control(5);
	i2c_control_stop  <= i2c_control(4);
	i2c_control_done  <= i2c_control(2);
	i2c_control_bfree <= i2c_control(1);
	--i2c_control_ack   <= i2c_control(0);
	
	i2c_data_msb <= i2c_data(7);
	
	reg_read : process(iobus_addr, iobus_cs, i2c_control, i2c_data, i2c_timer)
	begin  -- process REG_READ
		iobus_dout <= (others => '0');
		if (iobus_cs = '1') then
			case iobus_addr is
				when SLV_ADDR_I2C_CONTROL => iobus_dout <= i2c_control;
				when SLV_ADDR_I2C_DATA    => iobus_dout <= i2c_data;
				when SLV_ADDR_I2C_TIMER   => iobus_dout <= i2c_timer;
				when others               => iobus_dout <= (others => '0');
			end case;
		end if;
	end process reg_read;

	-- *** request interrupt if enabled ***
	iobus_irq <= i2c_control_done when i2c_control_inten = '1' else '0';
	
	-- auxiliary signals for control register status bits
	control_reg : process(iobus_addr, iobus_cs, iobus_din, iobus_wr, clr_bfree, clr_done, clr_start, clr_stop_set_bfree, copy_ack, iobus_ack, i2c_control, i2c_sda_in, set_done)
	begin
		i2c_control_nxt <= i2c_control;
		if ((iobus_cs = '1') and (iobus_wr = '1') and (iobus_addr = SLV_ADDR_I2C_CONTROL)) then
			i2c_control_nxt(7 downto 2) <= iobus_din(7 downto 2);
		end if;
		
		-- bit 5 (r/w): START  I2C start condition before next write access
		if (clr_start = '1') then i2c_control_nxt(5) <= '0'; 			end if;
		
		-- bit 4 (r/w): STOP   I2C stop condition after end of bus access
		if (clr_stop_set_bfree = '1') then i2c_control_nxt(4) <= '0'; 	end if;
		
		-- bit 2 (r/w): DONE   read, write or STOP done, interrupt flag
		if (iobus_ack = '1' or clr_done = '1') then i2c_control_nxt(2) <= '0'; end if;
		if (set_done = '1') then i2c_control_nxt(2) <= '1'; end if;
		
		-- bit 1 (r)  : BFREE  bus free (there was a STOP)
		if (clr_bfree = '1') then i2c_control_nxt(1) <= '0'; 			end if;
		if (clr_stop_set_bfree = '1') then i2c_control_nxt(1) <= '1';	end if;
		
		-- bit 0 (r)  : ACK    Ack of last transfer
		if (copy_ack = '1') then i2c_control_nxt(0) <= not i2c_sda_in;	end if;
		
	end process control_reg;

	-- *** generate new value for data register ***
	data_reg : process(iobus_addr, iobus_cs, iobus_din, iobus_wr, i2c_data, i2c_sda_in,
                     shift_data, state)
	begin 
		i2c_data_nxt <= i2c_data;
		if ((iobus_cs = '1') and (iobus_wr = '1') and (iobus_addr = SLV_ADDR_I2C_DATA) and ((state = ST_STOP) or (state = ST_IDLE))) then
			i2c_data_nxt <= iobus_din;
		end if;
		
		if (shift_data = '1') then
			i2c_data_nxt <= i2c_data(6 downto 0) & i2c_sda_in;
		end if;
	end process data_reg;

	time_reg : process(iobus_addr, iobus_cs, iobus_din, iobus_wr, i2c_timer)
	begin  
		i2c_timer_nxt <= i2c_timer;
		if ((iobus_cs = '1') and (iobus_wr = '1') and (iobus_addr = SLV_ADDR_I2C_TIMER)) then
			i2c_timer_nxt <= iobus_din;
		end if;
	end process time_reg;

	FF : process(clock)
	begin 
		if (rising_edge(clock)) then  				-- rising clock edge
			if reset_n = '0' then              		-- synchronous reset (active low)
				i2c_control <= "00000010";      	-- bus free
				i2c_data    <= (others => '0');
				i2c_timer   <= (others => '0');
			else
				i2c_control <= i2c_control_nxt;
				i2c_data    <= i2c_data_nxt;
				i2c_timer   <= i2c_timer_nxt;
			end if;
		end if;
	end process FF;


	start_read_access <= '1' when ((iobus_cs = '1') and (iobus_wr = '0') and (iobus_addr = SLV_ADDR_I2C_DATA) and (i2c_control_bfree = '0') and (i2c_en_i = '1')) else
                       '0';
	start_write_access <= '1' when ((iobus_cs = '1') and (iobus_wr = '1') and (iobus_addr = SLV_ADDR_I2C_DATA)) else
                        '0';

	STATEMACHINE : process(i2c_control_bfree, i2c_control_start, i2c_control_stop, i2c_data_msb, i2c_timer, scl_out, sda_out, start_read_access, start_write_access, state, sub_state, wait_counter)
	begin  -- process STATEMACHINE
		clr_start          	<= '0';          			-- no status change by default
		clr_stop_set_bfree 	<= '0';
		clr_bfree          	<= '0';
		copy_ack           	<= '0';
		clr_done           	<= '0';
		set_done           	<= '0';
		shift_data 			<= '0';                  	-- no data shift by default
		sda_out_nxt 		<= sda_out;             	-- hold outputs by default
		scl_out_nxt 		<= scl_out;
		state_nxt 			<= state;                 	-- hold state by default

		if (wait_counter /= std_ulogic_vector(to_unsigned(0, wait_counter'length))) then  	-- check wait counter
			-- wait state
			wait_counter_nxt <= std_ulogic_vector(unsigned(wait_counter) - 1);  			-- decrement wait counter
			sub_state_nxt    <= sub_state;    -- hold sub-state
		else
			wait_counter_nxt <= i2c_timer;    -- reset wait counter
			sub_state_nxt    <= std_ulogic_vector(unsigned(sub_state) + 1);  				-- increment sub-state by default
		end if;

		case state is
			when ST_IDLE =>
				sub_state_nxt    <= (others => '0');  -- no sub-states in IDLE mode
				wait_counter_nxt <= i2c_timer;        -- no waits in IDLE mode
				if (start_read_access = '1') then
					clr_done  <= '1';
					state_nxt <= ST_READ;
				end if;

				if (start_write_access = '1') then
					clr_done <= '1';
					if (i2c_control_start = '1') then
						if (i2c_control_bfree = '1') then
							state_nxt <= ST_START;
						else
							state_nxt <= ST_REP_START;
						end if;
					else
						state_nxt <= ST_WRITE;
					end if;
				end if;
		when ST_REP_START =>
			if (wait_counter = std_ulogic_vector(to_unsigned(0, wait_counter'length))) then
				if sub_state(0) = '0' then
					sda_out_nxt <= '1';
				else
					scl_out_nxt   <= '1';
					state_nxt     <= ST_START;
					sub_state_nxt <= (others => '0');
				end if;
			end if;
		when ST_START =>
			if (wait_counter = std_ulogic_vector(to_unsigned(0, wait_counter'length))) then
				case sub_state(1 downto 0) is
					when "00" =>
						clr_bfree <= '1';
					when "01" =>
						sda_out_nxt <= '0';
					when "10"   =>
					when others =>              
						clr_start     <= '1';
						scl_out_nxt   <= '0';
						state_nxt     <= ST_WRITE;
						sub_state_nxt <= (others => '0');
				end case;
			end if;
		when ST_WRITE =>
			if (wait_counter = std_ulogic_vector(to_unsigned(0, wait_counter'length))) then
				case sub_state(1 downto 0) is
					when "00" =>
						sda_out_nxt <= i2c_data_msb;
					when "01" =>
						scl_out_nxt <= '1';
					when "10"   =>
					when others =>              --"11" =>
						scl_out_nxt <= '0';
						shift_data  <= '1';
						if (sub_state(4 downto 2) = "111") then
							state_nxt <= ST_WRITE_ACK;
						end if;
					end case;
			end if;
			when ST_WRITE_ACK =>              -- read int_ack bit of write access
				if (wait_counter = std_ulogic_vector(to_unsigned(0, wait_counter'length))) then
					case sub_state(1 downto 0) is
						when "00" =>
							sda_out_nxt <= '1';
						when "01" =>
							scl_out_nxt <= '1';
						when "10"   =>
						when others =>              --"11" =>
							scl_out_nxt   <= '0';
							copy_ack      <= '1';
							sub_state_nxt <= (others => '0');
						if (i2c_control_stop = '1') then
							state_nxt <= ST_STOP;
						else
							set_done  <= '1';
							state_nxt <= ST_IDLE;
						end if;
					end case;
				end if;
		when ST_READ =>
			if (wait_counter = std_ulogic_vector(to_unsigned(0, wait_counter'length))) then
				case sub_state(1 downto 0) is
					when "00" =>
						sda_out_nxt <= '1';
					when "01" =>
						scl_out_nxt <= '1';
					when "10"   =>
					when others =>              --"11" =>  
						scl_out_nxt <= '0';
						shift_data  <= '1';
					if (sub_state(4 downto 2) = "111") then
						state_nxt <= ST_READ_ACK;
					end if;
				end case;
			end if;
		when ST_READ_ACK =>               -- write int_ack bit of read access
			if (wait_counter = std_ulogic_vector(to_unsigned(0, wait_counter'length))) then
				case sub_state(1 downto 0) is
					when "00" =>
						if (i2c_control_stop = '1') then
							sda_out_nxt <= '1';     -- no int_ack before stop
						else
							sda_out_nxt <= '0';
						end if;
					when "01" =>
						scl_out_nxt <= '1';
					when "10"   =>
					when others =>              --"11" =>
						scl_out_nxt   <= '0';
						copy_ack      <= '1';
						sub_state_nxt <= (others => '0');
					if (i2c_control_stop = '1') then
						state_nxt <= ST_STOP;
					else
						set_done  <= '1';
						state_nxt <= ST_IDLE;
					end if;
				end case;
			end if;
		when ST_STOP =>
			if (wait_counter = std_ulogic_vector(to_unsigned(0, wait_counter'length))) then
				case sub_state(1 downto 0) is
					when "00" =>
						sda_out_nxt <= '0';
					when "01" =>
						scl_out_nxt <= '1';
					when "10"   =>
					when others =>              --"11" =>
						sda_out_nxt        <= '1';
						set_done           <= '1';
						clr_stop_set_bfree <= '1';
						state_nxt          <= ST_IDLE;
						sub_state_nxt      <= (others => '0');
				end case;
			end if;
		when others => 
			state_nxt <= ST_IDLE;
		end case;
	end process STATEMACHINE;

	STATE_FF : process(clock)
	begin  -- process STATE_FF
		if clock'event and clock = '1' then  -- rising clock edge
			if reset_n = '0' then              -- synchronous reset (active low)
				state        <= ST_IDLE;
				sub_state    <= (others => '0');
				wait_counter <= (others => '0');
				sda_out      <= '1';
				scl_out      <= '1';
			else
				state        <= state_nxt;
				sub_state    <= sub_state_nxt;
				wait_counter <= wait_counter_nxt;
				sda_out      <= sda_out_nxt;
				scl_out      <= scl_out_nxt;
		
			end if;
		end if;
	end process STATE_FF;
	
	i2c_en      <= i2c_en_i;
	i2c_sda_out <= sda_out;
	i2c_scl_out <= scl_out;
	
end rtl;

