
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;
entity uart_rx is
	port (

		clk_i       : in std_ulogic; -- global clock line
		reset_n		: in std_ulogic;
		-- clock generator --
		clkgen_en_o : out std_ulogic; -- enable clock generator
		clkgen_i    : in  std_ulogic_vector(07 downto 0);
		-- com lines --
		uart_rxd_i  : in  std_ulogic;
		
		-- fifo interface
		data_out 	: out std_ulogic_vector(DATA_WIDTH - 1  downto 0);
		addr_out 	: out std_ulogic_vector(31  downto 0);
		push		: out std_ulogic;
		full 		: in  std_ulogic
	);
end uart_rx;

architecture uart_rx_rtl of uart_rx is

	-- clock generator --
	signal uart_clk : std_ulogic;
	-- uart rx unit --
	signal uart_rx_sync     : std_ulogic_vector(04 downto 0);
	signal uart_rx_avail    : std_ulogic;
	signal uart_rx_busy     : std_ulogic;
	signal uart_rx_busy_ff  : std_ulogic;
	
	--signal uart_rx_busy     : std_ulogic;
	--signal uart_rx_busy_ff  : std_ulogic;
	
	signal uart_rx_bitcnt   : std_ulogic_vector(03 downto 0);
	--signal uart_rx_bytecnt  : std_ulogic_vector(03 downto 0);
	signal uart_rx_bytecnt  : integer;
	
	signal uart_rx_reg      : std_ulogic_vector(07 downto 0);
	signal uart_rx_byte_reg : std_ulogic_vector(DATA_WIDTH + 31  downto 0);
	signal uart_rx_baud_cnt : std_ulogic_vector(07 downto 0);
	
	signal uart_baud_reg	: std_ulogic_vector(07 downto 0);
	signal uart_rx_sreg     : std_ulogic_vector(08 downto 0);
	
	
begin

	-- Clock Selection ----------------------------------------------------------
	-- -----------------------------------------------------------------------------
	-- clock enable --
	clkgen_en_o <= '1';
	
	-- uart clock select --
	uart_clk <= clkgen_i(uart_clk_prc); -- main clock / 64
	uart_baud_reg <= uart_baut_cnt; -- if 9600   main clock = 100 MHZ  100M/(64*9600) = xA3
	-- UART receiver ------------------------------------------------------------
	-- -----------------------------------------------------------------------------
	uart_rx_unit: process(clk_i,reset_n)
	begin
		if(reset_n = '0') then
			--uart_rx_bytecnt	<= "1001";
			uart_rx_bytecnt	<= uart_rx_byte_cnt_c;
			push 			<= '0';
			data_out		<= (others => '0');
		elsif (rising_edge(clk_i)) then
			push 		<= '0';
			data_out	<= (others => '0');
			-- synchronizer --
			uart_rx_sync <= uart_rxd_i & uart_rx_sync(4 downto 1);
			-- arbiter --
			if (uart_rx_busy /= '1') then -- idle or disabled
				uart_rx_busy     <= '0';
				uart_rx_baud_cnt <= '0' & uart_baud_reg(7 downto 1); -- half baud rate to sample in middle of bit
				uart_rx_bitcnt   <= "1001"; -- 9 bit (startbit + 8 data bits, ignore stop bit/s)
				if (uart_rx_sync(2 downto 0) = "001") then -- start bit? (falling edge)
					uart_rx_busy <= '1';
				end if;
			elsif (uart_clk = '1') then
				if (uart_rx_baud_cnt = x"00") then
					uart_rx_baud_cnt <= uart_baud_reg(7 downto 0);
					uart_rx_bitcnt   <= std_ulogic_vector(unsigned(uart_rx_bitcnt) - 1);
					uart_rx_sreg     <= uart_rx_sync(0) & uart_rx_sreg(8 downto 1);
					if (uart_rx_bitcnt = "0000") then
						uart_rx_busy <= '0'; -- done
						
						if (Big_Endian = 1) then
							uart_rx_byte_reg <= uart_rx_byte_reg(DATA_WIDTH + 23 downto 0) & uart_rx_sreg(8 downto 1);
						else
							uart_rx_byte_reg <= uart_rx_sreg(8 downto 1) & uart_rx_byte_reg(DATA_WIDTH + 31 downto 8);
						end if;
						
						--uart_rx_bytecnt   <= std_ulogic_vector(unsigned(uart_rx_bytecnt) - 1);
						uart_rx_bytecnt     <= uart_rx_bytecnt - 1;
					end if;
				else
					uart_rx_baud_cnt <= std_ulogic_vector(unsigned(uart_rx_baud_cnt) - 1);
				end if;
			end if;
			
			--if(uart_rx_bytecnt = "0001") then
			if(uart_rx_bytecnt = 1) then
				push 		<= '1'and (not full);
				data_out	<= uart_rx_byte_reg(DATA_WIDTH - 1 downto 0);
				addr_out	<= uart_rx_byte_reg(DATA_WIDTH + 31 downto DATA_WIDTH);
				--uart_rx_bytecnt	 <= "1001";
				uart_rx_bytecnt	 <= uart_rx_byte_cnt_c;
			end if;
		end if;
	end process uart_rx_unit;

end uart_rx_rtl;
