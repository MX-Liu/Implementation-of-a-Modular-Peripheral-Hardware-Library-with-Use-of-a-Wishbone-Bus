library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity tb_wb2ahb is

end entity tb_wb2ahb;

architecture dut of tb_wb2ahb is
	constant period   		: time := 20 ns; -- main clock period
	signal HCLK				: std_ulogic := '1';
	
	signal HRESETn			: std_ulogic;
	signal mHRDATA			: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal mHRESP			: std_ulogic_vector(1 downto 0);
	signal mHREADY			: std_ulogic;
	signal mHGRANT			: std_ulogic;
	signal mHSIZE			: std_ulogic_vector(2 downto 0);
	signal mHWRITE			: std_ulogic;
	signal mHBURST			: std_ulogic_vector(2 downto 0);
	signal mHADDR			: std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
	signal mHTRANS			: std_ulogic_vector(1 downto 0);
	signal mHWDATA			: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal HBUSREQ			: std_ulogic;
	signal wb_in 			: wb_slave_in;
	signal wb_out			: wb_slave_out;

	component m_wb2ahb 
	port(
		
		HCLK			: in  std_ulogic;
		HRESETn			: in  std_ulogic;
			
		mHRDATA			: in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
		mHRESP			: in  std_ulogic_vector(1 downto 0);
		mHREADY			: in  std_ulogic;
		mHGRANT			: in  std_ulogic;
			
		mHSIZE			: out std_ulogic_vector(2 downto 0);
		mHWRITE			: out std_ulogic;
		mHBURST			: out std_ulogic_vector(2 downto 0);
		mHADDR			: out std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
		mHTRANS			: out std_ulogic_vector(1 downto 0);
		mHWDATA			: out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
		HBUSREQ			: out std_ulogic;
		wb_in 			: in  wb_slave_in;
		wb_out			: out wb_slave_out
		
	);
	end component m_wb2ahb;	
	
begin
	inst_m_wb2ahb: m_wb2ahb
	port map(
		HCLK,	
		HRESETn,	
			
		mHRDATA,	
		mHRESP,	
		mHREADY,	
		mHGRANT,	
			
		mHSIZE,	
		mHWRITE,	
		mHBURST,	
		mHADDR,	
		mHTRANS,	
		mHWDATA,	
		HBUSREQ,	
		wb_in, 	
	    wb_out	
	);
	HCLK <= not HCLK after period /2;
	
	sim : process
	begin
		wb_in.stb_i <= '0';
		wb_in.cyc_i <= '0';
		wb_in.we_i <= '0';
		wb_in.adr_i <= (others => '0');
		wb_in.dat_i <= (others => '0');
		wb_in.bte_i <= (others => '0');
		wb_in.cti_i	<= (others => '0');
		HRESETn <= '0';
		
		wait until (rising_edge(HCLK));
		wait for 3*period;
		
		HRESETn <= '1';
		wait for period;
		
		wb_in.stb_i <= '1';
		wb_in.cyc_i <= '1';
		wb_in.we_i <= '1';
		wb_in.cti_i	<= (others => '0');
		wb_in.adr_i <= "000100";
		wb_in.dat_i <= x"00000231";
		
		wait until (wb_out.ack_o = '1');
		wait for period;
		wb_in.stb_i <= '0';
		wb_in.cyc_i <= '0';
		wb_in.we_i <= '0';
		wb_in.adr_i <= (others => '0');
		wb_in.dat_i <= (others => '0');
		wb_in.bte_i <= (others => '0');
		wb_in.cti_i	<= (others => '0');
		
		wait for period;
		wb_in.stb_i <= '1';
		wb_in.cyc_i <= '1';
		wb_in.we_i <= '1';
		wb_in.cti_i	<= "010";
		wb_in.adr_i <= "000100";
		wb_in.dat_i <= x"00000232";
		wait until (wb_out.ack_o = '1');
		wait for period;
		wb_in.dat_i <= x"00000233";
		wb_in.adr_i <= "001000";
		
		wait for period;
		wb_in.dat_i <= x"00000234";
		wb_in.adr_i <= "001100";
		
		wait for period;
		
		wb_in.dat_i <= x"00000235";
		wb_in.adr_i <= "010000";
		
		wait for period;
		wb_in.stb_i <= '0';
		wb_in.cyc_i <= '0';
		wb_in.we_i <= '0';
		wb_in.adr_i <= (others => '0');
		wb_in.dat_i <= (others => '0');
		wb_in.bte_i <= (others => '0');
		wb_in.cti_i	<= (others => '0');
		wait;
	end process sim;
	
	sim_ahb : process
	begin
		--wait until (HBUSREQ = '1');
		wait until (rising_edge(HCLK));
		mHGRANT <= '1';
		mHREADY <= '1';
		wait for period;
		
		wait;
	end process sim_ahb;
	
	
end dut; 
	
	
	
	
