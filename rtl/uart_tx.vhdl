library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity uart_tx is
  port (
    -- host access --
    clk_i       : in  std_ulogic; -- global clock line
    reset_n		: in std_ulogic;

    -- clock generator --
    clkgen_en_o : out std_ulogic; -- enable clock generator
    clkgen_i    : in  std_ulogic_vector(07 downto 0);
	
	-- fifo interface 
	pop			: out std_ulogic;
	empty 		: in std_ulogic;
	data_in 	: in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    -- com lines --
    uart_txd_o  : out std_ulogic
   
  );
end uart_tx;

architecture rtl of uart_tx is

	-- clock generator --
	signal uart_clk : std_ulogic;

	-- uart tx unit --
	signal uart_tx_busy     : std_ulogic;
	signal uart_tx_byte_busy: std_ulogic;
	signal uart_tx_done     : std_ulogic;
	signal uart_tx_bitcnt   : std_ulogic_vector(03 downto 0);
	
	--signal uart_tx_bytecnt   : std_ulogic_vector(02 downto 0);
	signal uart_tx_bytecnt	: integer;
	signal uart_tx_sreg     : std_ulogic_vector(09 downto 0);
	signal uart_tx_baud_cnt : std_ulogic_vector(07 downto 0);
	signal uart_baud_reg	: std_ulogic_vector(07 downto 0);
	signal uart_4byte_tx_down : std_ulogic;
	signal uart_tx_enable	: std_ulogic;
	signal uart_tx_byte_reg : std_ulogic_vector(DATA_WIDTH - 1 downto 0);

begin

	-- Clock Selection ----------------------------------------------------------
	-- -----------------------------------------------------------------------------
	-- clock enable --
	clkgen_en_o <= '1';

	-- uart clock select --
	uart_clk <= clkgen_i(uart_clk_prc); 
	uart_baud_reg <= uart_baut_cnt; 
	-- UART transmitter ---------------------------------------------------------
	-- -----------------------------------------------------------------------------
    uart_tx_unit: process(clk_i,reset_n)
    begin
		if(reset_n = '0') then
			uart_tx_byte_busy <= '0';
			pop <= '0';
			uart_tx_enable <= '0';
			--uart_tx_bytecnt <= "100";
			uart_tx_bytecnt	<= uart_tx_byte_cnt_c;
			uart_tx_busy 	<= '0';
			uart_txd_o		<= '1';
			uart_tx_sreg    <= (others=>'1');
		elsif rising_edge(clk_i) then
			pop <= '0';
            if (uart_tx_busy = '0') then -- idle or disabled
				uart_tx_busy     <= '0';
				uart_tx_baud_cnt <= uart_baud_reg;
				uart_tx_bitcnt   <= "1010"; -- 10 bit
				--if (uart_tx_enable = '1' and (uart_tx_bytecnt = "100")) then
				if (uart_tx_enable = '1' and (uart_tx_bytecnt = 4)) then
					uart_tx_byte_reg <= data_in;
					--uart_tx_sreg <= '1' & data_in(7 downto 0) & '0'; -- stopbit & data & startbit
					if (Big_Endian = 1) then
						uart_tx_sreg <= '1' & data_in(DATA_WIDTH - 1 downto DATA_WIDTH - 8) & '0';
					else
						uart_tx_sreg <= '1' & uart_tx_byte_reg(7 downto 0) & '0';
					end if;
					uart_tx_busy <= '1';
				--elsif(uart_tx_enable = '1' and ((uart_tx_bytecnt = "001") or (uart_tx_bytecnt = "010")or(uart_tx_bytecnt = "011"))) then
				elsif(uart_tx_enable = '1' and ((uart_tx_bytecnt = 1) or (uart_tx_bytecnt = 2)or(uart_tx_bytecnt = 3))) then
					
					if (Big_Endian = 1) then
						uart_tx_sreg <= '1' & uart_tx_byte_reg(DATA_WIDTH - 1 downto DATA_WIDTH - 8) & '0';
					else
						uart_tx_sreg <= '1' & uart_tx_byte_reg(7 downto 0) & '0';
					end if;
					uart_tx_busy <= '1';
				else
					uart_tx_byte_busy <= '0';
					uart_tx_enable <= '0';
				end if;
            elsif (uart_clk = '1') then
				if (uart_tx_baud_cnt = x"00") then
					uart_tx_baud_cnt <= uart_baud_reg;
					uart_tx_bitcnt   <= std_ulogic_vector(unsigned(uart_tx_bitcnt) - 1);
					uart_tx_sreg     <= '1' & uart_tx_sreg(9 downto 1);
					if (uart_tx_bitcnt = "0000") then
						uart_tx_busy <= '0'; -- done
						--uart_tx_bytecnt <= std_ulogic_vector(unsigned(uart_tx_bytecnt) - 1);
						uart_tx_bytecnt <= uart_tx_bytecnt - 1;
						
						if (Big_Endian = 1) then
							uart_tx_byte_reg <= uart_tx_byte_reg(DATA_WIDTH - 9 downto 0)& x"FF";
						else
							uart_tx_byte_reg <= x"FF" & uart_tx_byte_reg(DATA_WIDTH - 1 downto 8);
						end if;
					end if;
				else
					uart_tx_baud_cnt <= std_ulogic_vector(unsigned(uart_tx_baud_cnt) - 1);
				end if;
            end if;
            -- transmitter output --
            uart_txd_o <= uart_tx_sreg(0);
			
			-- fetch the data from fifo
			if((empty = '0') and (uart_tx_byte_busy = '0')) then
				uart_tx_byte_busy <= '1';
				pop <= '1';
				uart_tx_enable <= '1';
				--uart_tx_bytecnt <= "100";
				uart_tx_bytecnt <= uart_tx_byte_cnt_c;
			end if;
        end if;
    end process uart_tx_unit;
	
	
end rtl;
