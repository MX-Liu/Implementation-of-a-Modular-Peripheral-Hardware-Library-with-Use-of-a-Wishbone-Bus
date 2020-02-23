library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity tb_m_ahb2wb is

end entity tb_m_ahb2wb;

architecture dut of tb_m_ahb2wb is

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
	
	
	signal wb_out			: wb_master_out;
	signal wb_in 			: wb_master_in;
	
	component m_ahb2wb 
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
		sHRESP			: out std_ulogic_vector(1 downto 0);
		
		wb_out			: out wb_master_out;
		wb_in 			: in wb_master_in
	);
	end component m_ahb2wb;
	
begin
	inst_ahb2wb : m_ahb2wb
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
		sHRESP			,
		 
		wb_out,
	    wb_in 
	);
	
	HCLK <= not HCLK after period /2;
	
	sim : process
	begin
		HRESETn <= '0';
		sHWRITE <= '0';
		sHBURST <= (others => '0');
		sHSIZE 	<= (others => '0');
		sHSEL	<= '0';
		
		sHADDR	<= (others => '0');
		sHTRANS <= (others => '0');
		sHWDATA <= (others => '0');
		--wb_out.dat_o <= (others => '0');
		sHADDR	<= (others => '0');
		sHTRANS <= (others => '0');
		
		
		wait for 3 * period;
		wait until (rising_edge(HCLK));
		HRESETn <= '1';
		
		wait for period;
		sHWRITE <= '1';
		sHBURST <= "011";
		sHSIZE 	<= "010";
		sHSEL	<= '1';
		
		sHADDR	<= "000001";
		sHTRANS <= "10";
		
		wait for period;
		sHTRANS <= "01";
		sHWDATA <= x"00000321";
		sHADDR	<= "000010";
		--wait for period;
		wait until(sHREADY = '1');
		sHTRANS <= "01";
		--wait for period;
		--sHWDATA <= x"00000002";
		wait for 3 * period;
		sHTRANS <= "11";
		sHWDATA <= x"00000322";
		--wait for period;
		wait until(sHREADY = '1');
		sHADDR	<= "000011";
		wait for period;
		sHWDATA <= x"00000323";
		sHADDR	<= "000100";
		wait for period;
		sHTRANS <= "00";
		sHWDATA <= x"00000324";
		
		wait for period;
		sHWRITE <= '0';
		sHBURST <= "011";
		sHSIZE 	<= "010";
		sHSEL	<= '1';
		
		sHADDR	<= "000001";
		sHTRANS <= "10";
		
		wait for period;
		sHTRANS <= "01";
		sHWDATA <= x"00000321";
		sHADDR	<= "000010";
		
		wait for 3 * period;
		sHSIZE 	<= "100";
		wait; 
		
		
	end process sim;

	ack_prc : process
	begin
		wb_in.ack_i <= '0';
		wait until (HRESETn = '1');
		sHREADYIN <= '1';
		wb_in.ack_i <= '0';
		wait until (wb_out.stb_o = '1');
		sHREADYIN <= '0';
		wait for period;
		wb_in.ack_i <= '1';
		sHREADYIN <= '1';
		wait for period;
		
		
		wb_in.ack_i <= '0';
		
		
		wait until (wb_out.stb_o = '1');
		wait for period;
		wb_in.ack_i <= '1';
		
		wait until (wb_out.stb_o = '0');
		wb_in.ack_i <= '0';
		
		wait until (wb_out.stb_o = '1');
		wait for period;
		wb_in.ack_i <= '1';
		wb_in.dat_i <= x"71832989";
		
		
	end process ack_prc;
end dut; 
	
	
	
	
