library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity wb_pwm is
	--~ generic(
		--~ pwm_channel_count_c : integer:= 8 -- 1 to 8
	--~ );
	port (
		clock		: in std_ulogic;
		reset_n		: in std_ulogic;
		
		-- wishbone interface 
		wb_in		: in wb_slave_in;
		wb_out		: out wb_slave_out;
		
		-- pwm output channels --
		pwm_o       : out std_ulogic_vector(pwm_channel_count_c - 1 downto 0)
	);
end wb_pwm;

architecture rtl of wb_pwm is
	-- register address
	constant ctrl_adr_c 			: integer := 1; 
	constant pwm10_cnt_adr_c		: integer := 2; -- the count address of pwm channe0(bit 0 to 15) and channel1(bit 16 to 31)
	constant pwm32_cnt_adr_c		: integer := 3;	-- the count address of pwm channe2(bit 0 to 15) and channel3(bit 16 to 31)
	constant pwm54_cnt_adr_c		: integer := 4; -- the count address of pwm channe4(bit 0 to 15) and channel5(bit 16 to 31)
	constant pwm76_cnt_adr_c		: integer := 5; -- the count address of pwm channe6(bit 0 to 15) and channel7(bit 16 to 31)
	
	-- Control register bits --
	constant ctrl_enable_c 			: natural := 19; 	-- r/w: PWM enable
	constant ctrl_prsc2_bit_c  		: natural := 18; 	-- r/w: prescaler select bit 2
	constant ctrl_prsc1_bit_c  		: natural := 17; 	-- r/w: prescaler select bit 1
	constant ctrl_prsc0_bit_c  		: natural := 16; 	-- r/w: prescaler select bit 0
	--~ constant ctrl_pwm7_en_c			: natural := 15;	-- r/w: pwm7 enable
	--~ constant ctrl_pwm6_en_c         : natural := 14;    -- r/w: pwm6 enable
	--~ constant ctrl_pwm5_en_c         : natural := 13;    -- r/w: pwm5 enable
	--~ constant ctrl_pwm4_en_c         : natural := 12;    -- r/w: pwm4 enable
	--~ constant ctrl_pwm3_en_c         : natural := 11;    -- r/w: pwm3 enable
	--~ constant ctrl_pwm2_en_c         : natural := 10;    -- r/w: pwm2 enable
	--~ constant ctrl_pwm1_en_c         : natural := 9;     -- r/w: pwm1 enable
	--~ constant ctrl_pwm0_en_c         : natural := 8;	    -- r/w: pwm0 enable
	--~ constant ctrl_pwm7_mode_c       : natural := 7;     -- r/w: pwm7 mode choose, 1 high resolution mode 65536, 0: 256 
	--~ constant ctrl_pwm6_mode_c       : natural := 6;     -- r/w: pwm6 mode choose, 1 high resolution mode 65536, 0: 256
	--~ constant ctrl_pwm5_mode_c       : natural := 5;     -- r/w: pwm5 mode choose, 1 high resolution mode 65536, 0: 256
	--~ constant ctrl_pwm4_mode_c       : natural := 4;     -- r/w: pwm4 mode choose, 1 high resolution mode 65536, 0: 256
	--~ constant ctrl_pwm3_mode_c       : natural := 3;     -- r/w: pwm3 mode choose, 1 high resolution mode 65536, 0: 256
	--~ constant ctrl_pwm2_mode_c       : natural := 2;     -- r/w: pwm2 mode choose, 1 high resolution mode 65536, 0: 256
	--~ constant ctrl_pwm1_mode_c       : natural := 1;     -- r/w: pwm1 mode choose, 1 high resolution mode 65536, 0: 256
	--~ constant ctrl_pwm0_mode_c       : natural := 0;     -- r/w: pwm0 mode choose, 1 high resolution mode 65536, 0: 256
	
	signal ctrl_reg			: std_ulogic_vector(31 downto 0);
	signal pwm10_cnt_reg	: std_ulogic_vector(31 downto 0);
	signal pwm32_cnt_reg	: std_ulogic_vector(31 downto 0);
	signal pwm54_cnt_reg	: std_ulogic_vector(31 downto 0);
	signal pwm76_cnt_reg	: std_ulogic_vector(31 downto 0);
	
	signal ctrl_nxt			: std_ulogic_vector(31 downto 0);
	signal pwm10_cnt_nxt	: std_ulogic_vector(31 downto 0);
	signal pwm32_cnt_nxt	: std_ulogic_vector(31 downto 0);
	signal pwm54_cnt_nxt	: std_ulogic_vector(31 downto 0);
	signal pwm76_cnt_nxt	: std_ulogic_vector(31 downto 0);
	
	signal ctrl_en 			: std_ulogic;
	-- prescaler clock generator --
	signal prsc_tick 	: std_ulogic;
	signal pwm_cnt	 	: std_ulogic_vector(15 downto 0); 
	type t_pwm_channel	is array(0 to 7) of std_ulogic_vector(15 downto 0);
	signal pwm_channel 	: t_pwm_channel;
	
	-- clock generator --
	signal clkgen_en 	: std_ulogic; -- enable clock generator
	signal clkgen_i    	: std_ulogic_vector(07 downto 0);
	
	type wb_state is ( IDLE, W_ACK, W_FINISH, R_ACK, R_FINISH);
	signal wb_ack_state   			: wb_state := IDLE;
	signal wb_ack_state_nxt   		: wb_state := IDLE;
	
begin
	inst_clock_generator : clock_generator 
	port map(
        clock   	=> clock,
        reset_n 	=> reset_n,
        
        clkgen_en   => clkgen_en,
        clkgen_o    => clkgen_i
    );
   

	 -- PWM frequency select --
	clkgen_en <= ctrl_reg(ctrl_enable_c); -- enable clock generator
	prsc_tick   <= clkgen_i(to_integer(unsigned(ctrl_reg(ctrl_prsc2_bit_c downto ctrl_prsc0_bit_c))));
	ctrl_en 	<= ctrl_reg(ctrl_enable_c);
	
	pwm_channel(0) <= pwm10_cnt_reg(15 downto 0);
	pwm_channel(1) <= pwm10_cnt_reg(31 downto 16);
	pwm_channel(2) <= pwm32_cnt_reg(15 downto 0);
	pwm_channel(3) <= pwm32_cnt_reg(31 downto 16);
	pwm_channel(4) <= pwm54_cnt_reg(15 downto 0);
	pwm_channel(5) <= pwm54_cnt_reg(31 downto 16);
	pwm_channel(6) <= pwm76_cnt_reg(15 downto 0);
	pwm_channel(7) <= pwm76_cnt_reg(31 downto 16);
	
	access_bus: process(wb_in, wb_ack_state, ctrl_reg, pwm10_cnt_reg, pwm32_cnt_reg, pwm54_cnt_reg, pwm76_cnt_reg)
    begin
		wb_ack_state_nxt 	<= wb_ack_state;
		wb_out.ack_o 		<= '0';	
		wb_out.dat_o		<= (others => '0');
		ctrl_nxt 			<= ctrl_reg;		
		pwm10_cnt_nxt  		<= pwm10_cnt_reg;  	
		pwm32_cnt_nxt  		<= pwm32_cnt_reg;  	
		pwm54_cnt_nxt  		<= pwm54_cnt_reg;  	
		pwm76_cnt_nxt  		<= pwm76_cnt_reg;  	
		
    	--bus write uart module
		case wb_ack_state is
			when IDLE =>
				--bus write mode
				if(wb_in.we_i = '1' and wb_in.cyc_i = '1' and wb_in.stb_i = '1') then
					wb_ack_state_nxt 	<= W_ACK;
					wb_out.ack_o     	<= '0';
				end if;
				
				--bus read mode
				if(wb_in.we_i = '0' and wb_in.cyc_i = '1' and wb_in.stb_i = '1') then
					wb_ack_state_nxt 	<= R_ACK;
					wb_out.ack_o    	<= '0';
				end if;
				
			when W_ACK =>
				wb_out.ack_o <= '1';
				wb_ack_state_nxt <= W_FINISH;
				case to_integer(unsigned(wb_in.adr_i(MODULE_REG_ADDR_WIDTH - 1 downto 0))) is
					when ctrl_adr_c 	 => ctrl_nxt 		<= wb_in.dat_i(31 downto 0);
					when pwm10_cnt_adr_c => pwm10_cnt_nxt  	<= wb_in.dat_i(31 downto 0);
					when pwm32_cnt_adr_c => pwm32_cnt_nxt  	<= wb_in.dat_i(31 downto 0);
					when pwm54_cnt_adr_c => pwm54_cnt_nxt  	<= wb_in.dat_i(31 downto 0);
					when pwm76_cnt_adr_c => pwm76_cnt_nxt  	<= wb_in.dat_i(31 downto 0);
					when others => null;
				end case;		
			when W_FINISH =>
    			wb_out.ack_o		<= '0';
				wb_ack_state_nxt 	<= IDLE;
				
			-- bus read ankowledge
			when R_ACK	=>
				wb_out.ack_o   		<= '1';
				case to_integer(unsigned(wb_in.adr_i(MODULE_REG_ADDR_WIDTH - 1 downto 0))) is
					when ctrl_adr_c 	 => wb_out.dat_o(31 downto 0) 	<= ctrl_reg;
					when pwm10_cnt_adr_c => wb_out.dat_o(31 downto 0) 	<= pwm10_cnt_reg;
					when pwm32_cnt_adr_c => wb_out.dat_o(31 downto 0) 	<= pwm32_cnt_reg;
					when pwm54_cnt_adr_c => wb_out.dat_o(31 downto 0)	<= pwm54_cnt_reg;
					when pwm76_cnt_adr_c => wb_out.dat_o(31 downto 0)   <= pwm76_cnt_reg;
					when others => null;
				end case;
				wb_ack_state_nxt <= R_FINISH;
			when R_FINISH =>
				wb_out.ack_o   		<= '0';
				wb_ack_state_nxt 	<= IDLE;
			--coverage off
			when others =>
				wb_out.ack_o   		<= '0';
				wb_ack_state_nxt 	<= IDLE;
			--coverage on
		end case;	
    end process access_bus;
	
	-- PWM Core -----------------------------------------------------------------
	-- -----------------------------------------------------------------------------
	pwm_core: process(clock)
	begin
		if rising_edge(clock) then
		-- pwm counter --
			if (ctrl_en = '0') then 
				pwm_cnt <= (others => '0');
			elsif (prsc_tick = '1') then
				pwm_cnt <= std_ulogic_vector(unsigned(pwm_cnt) + 1);
			end if;
			-- channels --
			for i in 0 to pwm_channel_count_c-1 loop
				if(ctrl_reg(i) = '0') then -- low resolution 256
					if (unsigned(pwm_cnt(7 downto 0)) >= unsigned(pwm_channel(i)(7 downto 0))) or (ctrl_en = '0') then
						pwm_o(i) <= '0';
					else
						pwm_o(i) <= '1' and ctrl_reg(i+8);
					end if;
				else -- high resolution 65536
					if (unsigned(pwm_cnt) >= unsigned(pwm_channel(i))) or (ctrl_en = '0') then
						pwm_o(i) <= '0';
					else
						pwm_o(i) <= '1' and ctrl_reg(i+8);
					end if;
				end if;
				
			end loop; -- i, pwm channel
		end if;
	end process pwm_core;
  
	register_prc : process(clock,reset_n)
    begin
		if(reset_n = '0') then
			wb_ack_state<= IDLE;
			ctrl_reg      <= (others => '0');	
			pwm10_cnt_reg <= (others => '0');
			pwm32_cnt_reg <= (others => '0');
			pwm54_cnt_reg <= (others => '0');
			pwm76_cnt_reg <= (others => '0');
    	elsif(rising_edge(clock)) then
			wb_ack_state	<= wb_ack_state_nxt;
			ctrl_reg      	<= ctrl_nxt;
			pwm10_cnt_reg 	<= pwm10_cnt_nxt;
			pwm32_cnt_reg 	<= pwm32_cnt_nxt;
			pwm54_cnt_reg 	<= pwm54_cnt_nxt;
			pwm76_cnt_reg 	<= pwm76_cnt_nxt;
		end if;
	end process register_prc;
	
end rtl;
 
  

