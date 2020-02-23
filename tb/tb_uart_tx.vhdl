library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.wb_type.all;


entity tb_uart_tx is
	
end tb_uart_tx;

architecture rtl of tb_uart_tx is

	signal clock	: std_ulogic := '0';
	signal reset_n	: std_ulogic;
	constant PERIOD: time := 10 ns;
	
		
	--uart model signal ------------------------  
	signal end_simulation	: std_ulogic := '0';
	signal beg_simulation	: std_ulogic := '0';
	signal u_rx				: std_ulogic;
	signal u_tx				: std_ulogic;
	
	-- fifo signal 
	
	signal data_in		: std_ulogic_vector(31 downto 0);
	signal data_out		: std_ulogic_vector(31 downto 0);

	signal empty		: std_logic;
	signal full			: std_logic;

	signal pop			: std_logic;
	signal push			: std_logic;
	
	signal clkgen_en	: std_ulogic;
	signal clkgen_o     : std_ulogic_vector(07 downto 0);

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
	component clock_generator is 
	port(
		clock	: in std_ulogic;
		reset_n	: in std_ulogic;
		
		clkgen_en	: in std_ulogic;
		clkgen_o    : out  std_ulogic_vector(07 downto 0)
	);
	end component clock_generator;
	
	component fifo is
	generic(
		fifo_width : integer := 32;
		fifo_depth : integer := 8
		);
	port(
		clock		: in std_logic;
		reset_n		: in std_logic;
		data_in		: in std_ulogic_vector(fifo_width-1 downto 0);
		data_out	: out std_ulogic_vector(fifo_width-1 downto 0);

		empty		: out std_logic;
		full		: out std_logic;

		pop			: in std_logic;
		push		: in std_logic
	);
	end component fifo;

	component uart_tx is
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
		data_in 	: in std_ulogic_vector(31 downto 0);
		-- com lines --
		uart_txd_o  : out std_ulogic
	);
	end component uart_tx;
	
begin
	
	
	uart_inst : uart_model 
	generic map(
		SYSTEM_CYCLE_TIME 	=> 10 ns, 
		FILE_NAME_COMMAND 	=> "uart_command.txt",
		FILE_NAME_DUMP 		=> "dump.txt",
		BAUD_RATE 			=> 9600,
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
	
	uart_tx_inst : uart_tx
	port map(
		
		clk_i       => clock,
		reset_n		=> reset_n,
		clkgen_en_o => clkgen_en,
		clkgen_i    => clkgen_o,
		pop			=> pop,
		empty 		=> empty,
		data_in 	=> data_out,
		uart_txd_o  => u_rx
	);
	
	tx_fifo_inst : fifo
	generic map(
		fifo_width => 32,
		fifo_depth => 8
		)
	port map(
		clock		=> clock,
		reset_n		=> reset_n,
		data_in		=> data_in,
		data_out	=> data_out,

		empty		=> empty,
		full		=> full,

		pop			=> pop,
		push		=> push
	);
	
	clock_inst : clock_generator
	port map(
		clock		=> clock,
		reset_n		=> reset_n,
		
		clkgen_en	=> clkgen_en,
		clkgen_o    => clkgen_o
	);



	
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
		wait for(3*PERIOD);
		push <= '1';
		data_in <= x"01020304";
		wait for(PERIOD);
		push <= '0';
		data_in <= (others => '0');
		wait for(PERIOD);
		push <= '1';
		data_in <= x"05060708";
		wait for(PERIOD);
		push <= '0';
		data_in <= (others => '0');
		
		wait for(35 ms);
			
		wait for (40 ms);
		end_simulation <= '1';
		wait for (PERIOD);
		wait;
	end process test;
	
	
end rtl;


