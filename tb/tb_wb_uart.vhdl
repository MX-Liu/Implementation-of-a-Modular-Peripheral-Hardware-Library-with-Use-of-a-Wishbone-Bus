library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.wb_type.all;

entity tb_wb_uart is

end entity tb_wb_uart;

architecture dut of tb_wb_uart is
	
	signal clock	: std_ulogic := '0';
	signal reset_n	: std_ulogic;
	constant PERIOD: time := 20 ns;
	
	-- wishbonen interface of uart signal-------
	signal m_wb_out	: wb_master_out;
	signal m_wb_in	: wb_master_in;
	signal s_wb_out : wb_slave_out;
	signal s_wb_in  : wb_slave_in;
	--uart model signal ------------------------  
	signal end_simulation	: std_ulogic := '0';
	signal beg_simulation	: std_ulogic := '0';
	signal u_rx				: std_ulogic;
	signal u_tx				: std_ulogic;
	signal wb_rx			: std_ulogic;
	signal wb_tx			: std_ulogic;
	
	component uart_model is
	generic (
		SYSTEM_CYCLE_TIME 	: time := 10 ns; -- 100 MHz
		-- file with data to be send to fpga
		FILE_NAME_COMMAND 	: string := "command.txt";
		-- file for dump of data, received by pc
		FILE_NAME_DUMP 		: string := "dump.txt";
		-- communication speed for uart-link
		BAUD_RATE 			: natural := 9600;
		SIMULATION 			: boolean := false
	);
	port (
		-- global signals
		beg_simulation	: in std_ulogic;
		end_simulation	: in  std_ulogic;
		-- uart-pins (pc side)
		rx 				: in  std_ulogic; 
		tx 				: out std_ulogic
    );
	end component uart_model;
	
begin
	inst_wb_uart : wb_uart
	port map(
		clock		=> clock,
		reset_n		=> reset_n,
		
		m_wb_out	=> m_wb_out,
		m_wb_in		=> m_wb_in,
		
		s_wb_out 	=> s_wb_out,
		s_wb_in		=> s_wb_in,
		
		uart_tx_o	=> wb_tx,
		uart_rx_i	=> wb_rx
	);
	
	uart_inst : uart_model 
	generic map(
		SYSTEM_CYCLE_TIME 	=> 20 ns, 
		FILE_NAME_COMMAND 	=> "uart_command.txt",
		FILE_NAME_DUMP 		=> "dump.txt",
		BAUD_RATE 			=> 115200,
		SIMULATION 			=> false
		)
	port map(
		-- global signals
		beg_simulation 	=> beg_simulation,
		end_simulation 	=> end_simulation,
		-- uart-pins (pc side)
		rx 				=> u_rx,
		tx 				=> u_tx
	);
	
	wb_rx		  <= u_tx;
	u_rx  		  <= wb_tx;
	
	s_wb_in.cyc_i <= m_wb_out.cyc_o;
	s_wb_in.stb_i <= m_wb_out.stb_o;
	s_wb_in.we_i  <= m_wb_out.we_o;
	s_wb_in.dat_i <= m_wb_out.dat_o;
	s_wb_in.adr_i <= m_wb_out.adr_o;
	m_wb_in.ack_i <= s_wb_out.ack_o;
	m_wb_in.dat_i <= s_wb_out.dat_o;
	
	clk_gen : process(clock)
	begin 
		clock<=not clock after PERIOD / 2;
	end process;
	
    
	test : process
	
		file tvfile:    text;
        variable L:     line;
        variable C:     character;
        
	begin
		
		reset_n		<= '0';

		wait for (PERIOD/2);
	
		beg_simulation  <= '0';

		wait for(3*PERIOD);
		reset_n<= '1';
	
		
		beg_simulation  <= '1';
		wait for(35 ms);
			
		end_simulation <= '1';
		wait for (PERIOD);
		wait;
	end process test;


end dut;
