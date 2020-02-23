library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity i2c_master_module is
	port (
		-- host access --
		clock       : in  std_ulogic; -- global clock line
		reset_n		: in  std_ulogic;
    
		-- fifo interface
        full        : in  std_ulogic;
        empty       : in  std_ulogic;
        push        : out std_ulogic;
        pop         : out std_ulogic;
        data_in     : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        addr_in     : in  std_ulogic_vector(31 downto 0);
        data_out    : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        
		-- clock generator --
		clkgen_en_o : out std_ulogic; -- enable clock generator
		clkgen_i    : in  std_ulogic_vector(07 downto 0);
		-- com lines --
		i2c_sda_io  : inout std_logic; -- serial data line
		i2c_scl_io  : inout std_logic; -- serial clock line
		-- interrupt --
		i2c_irq_o   : out std_ulogic -- transfer done IRQ
	);
end i2c_master_module;

architecture rtl of i2c_master_module is

	constant data_reg_c         : std_ulogic_vector := "000";
	constant addr_reg_c         : std_ulogic_vector := "001";
    constant ctrl_reg_c      	: std_ulogic_vector := "010";
    
	-- control reg bits --
	constant ctrl_en_c     		: natural := 0; -- r/w: TWI enable
	constant ctrl_start_c  		: natural := 1; -- -/w: Generate START condition
	constant ctrl_stop_c   		: natural := 2; -- -/w: Generate STOP condition
	constant ctrl_busy_c   		: natural := 3; -- r/-: Set if TWI is busy
	constant ctrl_prsc0_c  		: natural := 4; -- r/w: CLK prsc bit 0
	constant ctrl_prsc1_c  		: natural := 5; -- r/w: CLK prsc bit 1
	constant ctrl_prsc2_c  		: natural := 6; -- r/w: CLK prsc bit 2
	constant ctrl_irq_en_c 		: natural := 7; -- r/w: transmission done interrupt
	
	-- data register flags --
	constant data_ack_c   		: natural := 15; -- r/-: Set if ACK received
	
	-- twi clocking --
	signal twi_clk        		: std_ulogic;
	signal twi_phase_gen  		: std_ulogic_vector(3 downto 0);
	signal twi_clk_phase  		: std_ulogic_vector(3 downto 0);
	
	-- i2c internal register 
	signal ctrl_reg      		: std_ulogic_vector(7 downto 0); -- unit's control register
	signal ctrl_nxt_reg      	: std_ulogic_vector(7 downto 0);
	
	signal data_reg      		: std_ulogic_vector(DATA_WIDTH - 1 downto 0); -- unit's control register
	signal data_nxt_reg      	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	
	signal addr_reg      		: std_ulogic_vector(7 downto 0); -- unit's control register
	signal addr_nxt_reg      	: std_ulogic_vector(7 downto 0);
	
	-- fifo read control signal
	signal fifo_read			: std_ulogic;
	signal pop_cnt				: std_ulogic_vector(1 downto 0) := "00";
	 
	-- i2c control signal 
	signal data_ready			: std_ulogic;			
	signal data_nxt_ready       : std_ulogic;
	signal addr_ready           : std_ulogic;
	signal addr_nxt_ready       : std_ulogic;
	signal ctrl_ready           : std_ulogic;
	signal ctrl_nxt_ready       : std_ulogic;
	--signal byte_cnt				: std_ulogic_vector(1 downto 0); -- 32 bits data will send or read 4 times by byte
	signal byte_cnt					: integer;
	--signal read_cnt				: std_ulogic_vector(2 downto 0) := "000"; -- 32 bits data will send or read 4 times by byte
	signal read_finish			: std_ulogic;
	signal read_start			: std_ulogic;
	signal send_buf				: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal i2c_busy				: std_ulogic;
	-- twi transceiver core --
	signal arbiter      		: std_ulogic_vector(2 downto 0);
	signal twi_bitcnt   		: std_ulogic_vector(3 downto 0);
	signal twi_rtx_sreg 		: std_ulogic_vector(8 downto 0); -- main rx/tx shift reg
	
	-- tri-state I/O --
	signal i2c_sda_i_ff0, i2c_sda_i_ff1 : std_ulogic; -- sda input sync
	--signal i2c_scl_i_ff0, i2c_scl_i_ff1 : std_ulogic; -- sda input sync
	signal i2c_sda_i,     i2c_sda_o     : std_ulogic;
	signal i2c_scl_i,     i2c_scl_o     : std_ulogic;

begin
	
	-- Fetch data from FIFO
	accessee_fifo : process(clock)
	begin
		if (rising_edge(clock)) then 
			pop <= '0';
			fifo_read <= '0';
			pop_cnt   <= std_ulogic_vector(unsigned(pop_cnt) - 1);
			if (empty = '0' and i2c_busy = '0' and pop_cnt = "00") then 
				pop <= '1';
				fifo_read <= '1';
			end if;
		end if; 
	end process accessee_fifo;
	
	-- write the internal register of the spi 
    write_register : process(fifo_read, data_in, addr_in, data_reg, ctrl_reg, addr_reg, data_ready, addr_ready)
    begin
        data_nxt_reg    <= data_reg;
        ctrl_nxt_reg 	<= ctrl_reg;
        addr_nxt_reg 	<= addr_reg;

        data_nxt_ready  <= '0';
        addr_nxt_ready  <= '0';
        ctrl_nxt_ready  <= '0';
        if(fifo_read = '1') then
            case addr_in(2 downto 0) is
                when data_reg_c =>
                    data_nxt_reg    <= data_in;
                    data_nxt_ready  <= '1';
                    
                 when addr_reg_c =>
                    addr_nxt_reg    <= data_in(7 downto 0);
                    addr_nxt_ready  <= '1';
                    
                when ctrl_reg_c =>
                    ctrl_nxt_reg 	<= data_in(7 downto 0);
                    ctrl_nxt_ready  <= '1';
                    
                when others =>
                    data_nxt_reg    <= data_reg;
                    ctrl_nxt_reg 	<= ctrl_reg;
                    addr_nxt_reg 	<= addr_reg;
                    data_nxt_ready  <= '0';
                    addr_nxt_ready	<= '0';
                    ctrl_nxt_ready  <= '0';
            end case;
        end if;
    end process write_register;
    
	-- Clock Generation ---------------------------------------------------------
	-- -----------------------------------------------------------------------------
	-- clock generator enable --
	clkgen_en_o <= ctrl_reg(ctrl_en_c);
	
	-- main twi clock select --
	twi_clk <= clkgen_i(to_integer(unsigned(ctrl_reg(ctrl_prsc2_c downto ctrl_prsc0_c))));
	
	-- generate four non-overlapping clock ticks at twi_clk/4 each --
	clock_phase_gen: process(clock)
	begin
		if rising_edge(clock) then
			if (arbiter(2) = '0') or (arbiter = "100") then -- offline or idle
				twi_phase_gen <= "0001"; -- make sure to start with a new phase 0,1,2,3 stepping
			else
				if (twi_clk = '1') then
					twi_phase_gen <= twi_phase_gen(2 downto 0) & twi_phase_gen(3); -- shift left
				end if;
			end if;
		end if;
	end process clock_phase_gen;
	
	twi_clk_phase(0) <= twi_phase_gen(0) and twi_clk;
	twi_clk_phase(1) <= twi_phase_gen(1) and twi_clk;
	twi_clk_phase(2) <= twi_phase_gen(2) and twi_clk;
	twi_clk_phase(3) <= twi_phase_gen(3) and twi_clk;


	-- TWI transceiver ----------------------------------------------------------
	-- -----------------------------------------------------------------------------
	i2c_rtx_unit: process(clock,reset_n)
	begin
		if (reset_n = '0') then
			i2c_irq_o 	<= '0';
			i2c_busy 	<= '0';
			push 		<= '0';
		elsif (rising_edge(clock)) then
			-- input synchronizer --
			i2c_sda_i_ff0 <= i2c_sda_i;
			i2c_sda_i_ff1 <= i2c_sda_i_ff0;
			--i2c_scl_i_ff0 <= i2c_scl_i;
			--i2c_scl_i_ff1 <= i2c_scl_i_ff0;
		
			-- defaults --
			i2c_irq_o 	<= '0';
			i2c_busy 	<= '0';
			push 		<= '0';
			data_out	<= (others => '0');
			
			-- arbiter FSM --
			case arbiter is
				
				when "100" => -- IDLE: waiting for requests, bus is still claimed by the master if no STOP condition was generated
					arbiter(2) <= ctrl_reg(ctrl_en_c); -- still activated?
					twi_bitcnt <= (others => '0');
					
					read_finish<= '0';
					read_start <= '0';
					if (ctrl_ready = '1') then 
						if (ctrl_reg(ctrl_start_c) = '1') then
							arbiter(1 downto 0) <= "01";
						elsif (ctrl_reg(ctrl_stop_c) = '1') then
							arbiter(1 downto 0) <= "10";
						end if;
					elsif (addr_ready = '1') then
						arbiter(1 downto 0) <= "11";
						--byte_cnt				<= "00";
						byte_cnt				<= 0;
						twi_rtx_sreg			<= addr_reg & '1';
					elsif (data_ready = '1') then
						arbiter(1 downto 0) <= "11";
						--byte_cnt			<= "11";
						byte_cnt				<= i2c_tx_byte_cnt_c;
						if (Big_Endian = 1) then 
							twi_rtx_sreg		<= data_reg(DATA_WIDTH - 1 downto DATA_WIDTH - 8) & '1';
							send_buf			<= data_reg(DATA_WIDTH - 9 downto 0) & x"FF";
						else
							twi_rtx_sreg		<= data_reg(DATA_WIDTH - 1 downto DATA_WIDTH - 8) & '1';
							send_buf			<= data_reg(DATA_WIDTH - 9 downto 0) & x"FF";
						end if;
					
					else
						arbiter(1 downto 0) <= "00";
						--byte_cnt			<= "00";
						byte_cnt				<= 0;
					end if;
					
					
				when "101" => -- START: generate START condition
					arbiter(2) <= ctrl_reg(ctrl_en_c); -- still activated?
					i2c_busy <= '1';
					
					if (twi_clk_phase(0) = '1') then
						i2c_sda_o <= '1';
					elsif (twi_clk_phase(1) = '1') then
						i2c_sda_o <= '0';
					end if;
			
					if (twi_clk_phase(0) = '1') then
						i2c_scl_o <= '1';
					elsif (twi_clk_phase(3) = '1') then
						i2c_scl_o <= '0';
						arbiter(1 downto 0) <= "00"; -- go back to IDLE
					end if;
		
				when "110" => -- STOP: generate STOP condition
					arbiter(2) <= ctrl_reg(ctrl_en_c); -- still activated?
					i2c_busy <= '1';
					if (twi_clk_phase(0) = '1') then
						i2c_sda_o <= '0';
					elsif (twi_clk_phase(3) = '1') then
						i2c_sda_o <= '1';
						arbiter(1 downto 0) <= "00"; -- go back to IDLE
					end if;
					
					if (twi_clk_phase(0) = '1') then
						i2c_scl_o <= '0';
					elsif (twi_clk_phase(1) = '1') then
						i2c_scl_o <= '1';
					end if;
		
				when "111" => -- TRANSMISSION: transmission in progress
					arbiter(2) <= ctrl_reg(ctrl_en_c); -- still activated?
					i2c_busy <= '1';
					
					if (twi_clk_phase(0) = '1') then
						twi_bitcnt   <= std_ulogic_vector(unsigned(twi_bitcnt) + 1);
						i2c_scl_o    <= '0';
						
						if (addr_reg(0) = '1' and twi_bitcnt = "1000") then
							i2c_sda_o <= '0'; -- send acknowledge signal when reading slave
						elsif (read_start = '1') then
							i2c_sda_o <= '1'; -- read process, keep i2c_sda_o high resistance
						else
							i2c_sda_o    <= twi_rtx_sreg(8); -- MSB first
						end if;
						
					elsif (twi_clk_phase(1) = '1') then -- first half + second half of valid data strobe
						i2c_scl_o <= '1';
					elsif (twi_clk_phase(3) = '1') then
						twi_rtx_sreg <= twi_rtx_sreg(7 downto 0) & i2c_sda_i_ff1; -- sample and shift left
						i2c_scl_o    <= '0';
					end if;
			
					if (twi_bitcnt = "1010") then -- 8 data bits + 1 bit for ACK + 1 tick delay  
						--if (byte_cnt = "00") then
						if (byte_cnt = 0) then
							i2c_irq_o <= ctrl_reg(ctrl_irq_en_c); -- fire IRQ if enabled
							if (addr_reg(0) = '1' and read_finish = '0') then
								arbiter 	<= "011";  --start with a new phase 0,1,2,3 stepping
								--byte_cnt	<= "11";
								byte_cnt	<= i2c_tx_byte_cnt_c;
								read_start  <= '1';
								twi_bitcnt 	<= (others => '0');
							else
								arbiter(1 downto 0) <= "00"; -- go back to IDLE
								if (Big_Endian = 1) then 
									send_buf			<= send_buf(DATA_WIDTH - 9 downto 0) & twi_rtx_sreg(8 downto 1);
								else
									send_buf			<=  twi_rtx_sreg(8 downto 1) & send_buf(DATA_WIDTH - 1 downto 8);
								end if;
								
								if (addr_reg(0) = '1' and read_finish = '1') then
									push 	<= '1';
									if (Big_Endian = 1) then 
										data_out<= 	send_buf(DATA_WIDTH - 9 downto 0) & twi_rtx_sreg(8 downto 1);
									else
										data_out<= 	twi_rtx_sreg(8 downto 1) &send_buf(DATA_WIDTH - 1 downto 8);
									end if;
								end if;
							end if;
						else
							arbiter 			<= "011";  --start with a new phase 0,1,2,3 stepping
							twi_bitcnt 			<= (others => '0');
							--byte_cnt			<= std_ulogic_vector(unsigned(byte_cnt) - 1);
							byte_cnt			<= byte_cnt - 1;
							
							if (Big_Endian = 1) then
								twi_rtx_sreg		<= send_buf(DATA_WIDTH - 1 downto DATA_WIDTH - 8) & '1';
								send_buf			<= send_buf(DATA_WIDTH - 9 downto 0) & twi_rtx_sreg(8 downto 1);
							else
								twi_rtx_sreg		<= send_buf(7 downto 0) & '1';
								send_buf			<= twi_rtx_sreg(8 downto 1) & send_buf(DATA_WIDTH - 1 downto 8);
							end if;
							
							--if (byte_cnt = "01") then
							if (byte_cnt = 1) then
								read_finish <= '1';
							end if;
						end if;  
					end if; 
				when "011" => 
					arbiter <= "111"; 
				when others => -- "0--" OFFLINE: deactivated
					i2c_sda_o <= '1';
					i2c_scl_o <= '1';
					arbiter   <= ctrl_reg(ctrl_en_c) & "00"; -- stay here, go to idle when activated
					if (ctrl_ready = '1') then 
						if (ctrl_reg(ctrl_start_c) = '1') then
							arbiter(1 downto 0) <= "01";
						elsif (ctrl_reg(ctrl_stop_c) = '1') then
							arbiter(1 downto 0) <= "10";
						end if;
					end if;
			end case;
		end if;
	end process i2c_rtx_unit;
	
	
	register_prc : process(clock,reset_n)
    begin
        if(reset_n = '0') then
			data_reg    <= (others => '0');
            ctrl_reg 	<= (others => '0');
            addr_reg	<= (others => '0');
			data_ready	<= '0';	
			addr_ready	<= '0';
           
        elsif(rising_edge(clock)) then
            data_reg    <= data_nxt_reg;
            ctrl_reg 	<= ctrl_nxt_reg;
            addr_reg	<= addr_nxt_reg;	
            data_ready	<= data_nxt_ready;
            addr_ready	<= addr_nxt_ready;
            ctrl_ready	<= ctrl_nxt_ready;
        end if;
    end process register_prc;
    
	-- Tri-State Driver ---------------------------------------------------------
	-- -----------------------------------------------------------------------------
	-- SDA and SCL need to be of type std_logic to be correctly resolved in simulation
	i2c_sda_io <= '0' when (i2c_sda_o = '0') else 'H';
	i2c_scl_io <= '0' when (i2c_scl_o = '0') else 'H';
	
	-- read-back --
	i2c_sda_i <= std_ulogic(i2c_sda_io);
	i2c_scl_i <= std_ulogic(i2c_scl_io);


end rtl;
