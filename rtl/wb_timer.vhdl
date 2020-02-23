library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity wb_timer is
	port (
		clock		: in std_ulogic;
		reset_n		: in std_ulogic;
		
		-- wishbone interface 
		wb_in		: in wb_slave_in;
		wb_out		: out wb_slave_out;
		
		-- clock generator --
		--~ clkgen_en_o : out std_ulogic; -- enable clock generator
		--~ clkgen_i    : in  std_ulogic_vector(07 downto 0);
		-- interrupt --
		irq_o       : out std_ulogic  -- interrupt request
	);
end wb_timer;

architecture rtl of wb_timer is

	-- register address 
	constant ctrl_reg_adr_c			: natural := 1;		-- control register address
	constant cnt_reg_adr_c			: natural := 2;		-- counter register address
	constant thres_reg_adr_c		: natural := 3;		-- threshold register address
	-- control reg bits --	
	constant ctrl_en_bit_c     		: natural := 0; 	-- r/w: timer enable
	constant ctrl_arst_bit_c   		: natural := 1; 	-- r/w: auto reset on match
	constant ctrl_irq_en_bit_c 		: natural := 2; 	-- r/w: interrupt enable
	constant ctrl_prsc0_bit_c  		: natural := 3; 	-- r/w: prescaler select bit 0
	constant ctrl_prsc1_bit_c  		: natural := 4; 	-- r/w: prescaler select bit 1
	constant ctrl_prsc2_bit_c  		: natural := 5; 	-- r/w: prescaler select bit 2
	
	
	-- timer regs --
	signal cnt_reg  	: std_ulogic_vector(31 downto 0);
	signal thres_reg 	: std_ulogic_vector(31 downto 0);
	signal ctrl_reg 	: std_ulogic_vector(31 downto 0);
	signal cnt_nxt  	: std_ulogic_vector(31 downto 0);
	signal thres_nxt 	: std_ulogic_vector(31 downto 0);
	signal ctrl_nxt 	: std_ulogic_vector(31 downto 0);
	
	-- timer control signal
	signal timer_en		: std_ulogic;
	signal timer_auto_rst	: std_ulogic;
	signal timer_irq_en	: std_ulogic;
	-- prescaler clock generator --
	signal prsc_tick : std_ulogic;
	
	-- timer control --
	signal match       	: std_ulogic; -- thres = cnt
	signal irq_fire    	: std_ulogic;
	signal irq_fire_nxt : std_ulogic;
	
	signal cnt_load		: std_ulogic;
	signal cnt_load_nxt	: std_ulogic;
	signal count		: std_ulogic_vector(31 downto 0);
	
	signal clkgen_en_o 	: std_ulogic; -- enable clock generator
	signal clkgen_i    	: std_ulogic_vector(07 downto 0);
		
	type wb_state is ( IDLE, W_ACK, W_FINISH, R_ACK, R_FINISH);
	signal wb_ack_state   			: wb_state := IDLE;
	signal wb_ack_state_nxt   		: wb_state := IDLE;

begin
	
	inst_clock_generator : clock_generator 
	port map(
        clock   	=> clock,
        reset_n 	=> reset_n,
        
        clkgen_en   => clkgen_en_o,
        clkgen_o    => clkgen_i
    );
    
	-- timer clock select --
	prsc_tick <= clkgen_i(to_integer(unsigned(ctrl_reg(ctrl_prsc2_bit_c downto ctrl_prsc0_bit_c))));

	-- enable external clock generator --
	clkgen_en_o <= timer_en;
	
	-- match --
	match <= '1' when (count = thres_reg) else '0';

	-- interrupt line --
	irq_fire_nxt <= match and timer_en and timer_irq_en;
	
	-- edge detector --
	irq_o <= (not irq_fire) and irq_fire_nxt;
	
	-- control signal 
	timer_en		<= ctrl_reg(ctrl_en_bit_c);
	timer_auto_rst 	<= ctrl_reg(ctrl_arst_bit_c);
	timer_irq_en	<= ctrl_reg(ctrl_irq_en_bit_c);
	
	access_bus: process(wb_in, wb_ack_state, ctrl_reg, cnt_reg, thres_reg, count, cnt_load)
    begin
		wb_ack_state_nxt 	<= wb_ack_state;
		wb_out.ack_o 		<= '0';	
		wb_out.dat_o		<= (others => '0');
		ctrl_nxt			<= ctrl_reg;
		cnt_nxt 			<= cnt_reg;
		thres_nxt			<= thres_reg;
		cnt_load_nxt		<= '0';
		
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
				case to_integer(unsigned(wb_in.adr_i(MODULE_REG_ADDR_WIDTH - 1 downto 0))) is
					when ctrl_reg_adr_c => ctrl_nxt 	<= wb_in.dat_i(31 downto 0);
					when cnt_reg_adr_c => 
						cnt_nxt  		<= wb_in.dat_i(31 downto 0);
						cnt_load_nxt	<= '1';
					when thres_reg_adr_c => thres_nxt <= wb_in.dat_i(31 downto 0);
					when others => null;
				end case;		
				wb_ack_state_nxt <= W_FINISH;
				
			when W_FINISH =>
    			wb_out.ack_o		<= '0';
				wb_ack_state_nxt 	<= IDLE;
				
			-- bus read ankowledge
			when R_ACK	=>
				wb_out.ack_o   		<= '1';
				case to_integer(unsigned(wb_in.adr_i(MODULE_REG_ADDR_WIDTH - 1 downto 0))) is
					when ctrl_reg_adr_c	=> wb_out.dat_o(31 downto 0) 	<= ctrl_reg;
					when cnt_reg_adr_c  => wb_out.dat_o(31 downto 0) 	<= count;
					when thres_reg_adr_c=> wb_out.dat_o(31 downto 0) 	<= thres_reg;
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
	
	timer_counter: process(clock)
	begin
		if rising_edge(clock) then
			if(cnt_load = '1') then 
				count <= cnt_reg;
			elsif (timer_en = '1') then -- timer enabled
				if (match = '1' and timer_auto_rst = '1') then -- match?
					count <= (others => '0');
				elsif (match = '0') and (prsc_tick = '1') then -- count++ if no match
					count <= std_ulogic_vector(unsigned(count) + 1);
				end if;
			end if;
		end if;
	end process timer_counter;
	
	register_prc : process(clock,reset_n)
    begin
		if(reset_n = '0') then
			
			wb_ack_state<= IDLE;
			irq_fire	<= '0';
			cnt_load	<= '0';
			cnt_reg		<= (others => '0');
			ctrl_reg	<= (others => '0');
			thres_reg	<= (others => '0');
    	elsif(rising_edge(clock)) then
			wb_ack_state<= wb_ack_state_nxt;
			irq_fire  	<= irq_fire_nxt;
			cnt_load	<= cnt_load_nxt;
			cnt_reg		<= cnt_nxt;
			ctrl_reg	<= ctrl_nxt;
			thres_reg	<= thres_nxt;
		end if;
	end process register_prc;
end rtl;

  

  
