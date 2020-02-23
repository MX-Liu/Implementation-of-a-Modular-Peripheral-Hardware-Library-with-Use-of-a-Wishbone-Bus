library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity tb_ahb_wb_register is

end entity tb_ahb_wb_register;

architecture dut of tb_ahb_wb_register is

	constant period   	: time := 20 ns; -- main clock period
	signal HCLK				: std_ulogic := '0';
	signal HRESETn			: std_ulogic;
	                  
	signal sHADDR			: std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
	signal sHWDATA			: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal sHWRITE			: std_ulogic;
	signal sHSIZE 			: std_ulogic_vector(2 downto 0);
	signal sHBURST 			: std_ulogic_vector(2 downto 0);
	signal sHSEL 			: std_ulogic;
	signal sHTRANS			: std_ulogic_vector(1 downto 0);
	signal sHREADYIN		: std_ulogic;
	signal sHREADY			: std_ulogic;
	signal sHRDATA			: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal sHRESP			: std_ulogic_vector(1 downto 0);
	
	component ahb_wb_register is
	port(
		-- ahb slave signal 
		HCLK			: in  std_ulogic;
		HRESETn			: in  std_ulogic;
			                  
		sHADDR			: in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
		sHWDATA			: in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
		sHWRITE			: in  std_ulogic;
		sHSIZE 			: in  std_ulogic_vector(2 downto 0);
		sHBURST 		: in  std_ulogic_vector(2 downto 0);
		sHSEL 			: in  std_ulogic;
		sHTRANS			: in  std_ulogic_vector(1 downto 0);
		sHREADYIN		: in  std_ulogic;
		sHREADY			: out std_ulogic;
		sHRDATA			: out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
		sHRESP			: out std_ulogic_vector(1 downto 0)
		);
	end component ahb_wb_register;
	
begin
	inst_ahb_wb_register : ahb_wb_register
	port map(
	
		HCLK			,
		HRESETn			,
			            
		sHADDR			,
		sHWDATA			,
		sHWRITE			,
		sHSIZE 			,
		sHBURST 		,
		sHSEL 			,
		sHTRANS			,
		sHREADYIN		,
		sHREADY			,
		sHRDATA			,
		sHRESP			
		 
	);
	
	HCLK <= not HCLK after period /2;
	
	sim : process
	begin
		HRESETn <= '0';
		sHWRITE <= '0';
		sHBURST <= (others => '0');
		sHSIZE 	<= (others => '0');
		sHSEL	<= '0';
		sHREADYIN <= '0';
		sHADDR	<= (others => '0');
		sHTRANS <= (others => '0');
		sHWDATA <= (others => '0');
		sHADDR	<= (others => '0');
		sHTRANS <= (others => '0');
		
		
		wait for 3 * period;
		wait until (rising_edge(HCLK));
		HRESETn <= '1';
		
		wait for period;
		sHWRITE 	<= '1';
		sHBURST 	<= "011";
		sHSIZE 		<= "010";
		sHSEL		<= '1';
		sHREADYIN 	<= '1';
		sHADDR		<= "000001";
		sHTRANS 	<= "10";
		wait for period;
		
		sHWDATA 	<= x"00000001";
		sHADDR		<= "000010";
		wait until(sHREADY = '1');
		sHTRANS 	<= "00";
		
		wait for period;
		sHADDR		<= "000010";
		sHTRANS 	<= "10";
		wait for period;
		sHADDR		<= "000011";
		sHWDATA 	<= x"00000002";
		wait until(sHREADY = '1');
		sHTRANS 	<= "00";
		
		wait for period;
		sHADDR		<= "000011";
		sHTRANS 	<= "10";
		wait for period;
		sHWDATA 	<= x"00000003";
		sHADDR		<= "000100";
		wait until(sHREADY = '1');
		sHTRANS 	<= "00";
		
		wait for period;
		sHADDR		<= "000100";
		sHTRANS 	<= "10";
		wait for period;
		sHADDR		<= "000101";
		sHWDATA 	<= x"00000004";
		wait until(sHREADY = '1');
		sHTRANS 	<= "00";
		
		wait for period;
		wait for period;
		wait for period;
		wait for period;

		sHADDR		<= "000101";
		sHTRANS 	<= "10";
		wait for period;
		sHTRANS 	<= "11";
		sHWDATA 	<= x"00000005";
		sHADDR		<= "000110";
		wait until(sHREADY = '1');
		wait for period;
		sHTRANS 	<= "11";
		sHWDATA 	<= x"00000006";
		sHADDR		<= "000111";
		wait for period;
		sHWDATA 	<= x"00000007";
		sHADDR		<= "000000";
		wait for period;
		sHWDATA 	<= x"00000008";
		sHADDR		<= "000001";
		sHTRANS 	<= "00";
		wait for period;
		sHTRANS 	<= "00";
		wait; 
	end process sim;
end dut; 
	
	
	
	
