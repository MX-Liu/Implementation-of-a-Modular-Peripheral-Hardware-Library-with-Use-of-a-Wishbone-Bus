library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity m_wb2ahb is
	port(
		
		-- ahb master signal
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
		
		-- wishbone slave signal 
		--~ from_wb_adr_o	: in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
		--~ from_wb_sel_o	: in  std_ulogic_vector(3 downto 0);
		--~ from_wb_we_o	: in  std_ulogic;
		--~ from_wb_dat_o	: in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
		--~ from_wb_cyc_o	: in  std_ulogic;
		--~ from_wb_stb_o   : in  std_ulogic;
		--~ from_wb_cti_o	: in  std_ulogic_vector(2 downto 0);
		--~ from_wb_bte_o	: in  std_ulogic_vector(1 downto 0);
		
		--~ to_wb_ack_i		: out std_ulogic;
		--~ to_wb_err_i		: out std_ulogic;
		--~ to_wb_dat_i		: out std_ulogic_vector(DATA_WIDTH - 1 downto 0)
		wb_in 				: in  wb_slave_in;
		wb_out				: out wb_slave_out
		
	);
end entity m_wb2ahb;

architecture rtl of m_wb2ahb is
	constant IDLE 		: std_ulogic_vector := "00";
	constant BUSY 		: std_ulogic_vector := "01";
	constant NONSEQ 	: std_ulogic_vector := "10";
	constant SEQ 		: std_ulogic_vector := "11";
	
	signal ackmask		: std_ulogic;
	signal ctrlstart 	: std_ulogic;
	signal isburst		: std_ulogic;
	signal test_askmask	: std_ulogic;
	signal isHBUSREQ    : std_ulogic;
	signal wb_ack_i		: std_ulogic;

begin
	--isburst		<= '0' when (from_wb_cti_o = "000" or from_wb_cti_o = "111") else '1';
	isburst		<= '0' when (wb_in.cti_i = "000" or wb_in.cti_i = "111") else '1';
	
	
	--to_wb_dat_i	<= mHRDATA;
	--to_wb_ack_i	<= wb_ack_i; 
	wb_out.dat_o <= mHRDATA;
	wb_out.ack_o <= wb_ack_i;
	
	--~ wb_ack_i <= ackmask and mHREADY and from_wb_stb_o;
	wb_ack_i <= ackmask and mHREADY and wb_in.stb_i;
	
	--~ to_wb_err_i <= '0' when (mHRESP = "00") else '1';
	
	--~ mHADDR		<= from_wb_adr_o when (isburst = '0' or (ctrlstart = '1' and ackmask = '0') or ctrlstart = '0') else 
					--~ std_ulogic_vector(unsigned(from_wb_adr_o) + 4);
	mHADDR		<= wb_in.adr_i when (isburst = '0' or (ctrlstart = '1' and ackmask = '0') or ctrlstart = '0') else 
					std_ulogic_vector(unsigned(wb_in.adr_i) + 4);
					
	--~ mHWDATA		<= from_wb_dat_o;
	mHWDATA		<= wb_in.dat_i;
	mHSIZE		<= "010";
	--~ mHBURST		<= "011" when (ctrlstart = '1' and (from_wb_cti_o = "010")) else "000";
	mHBURST		<= "011" when (ctrlstart = '1' and (wb_in.cti_i = "010")) else "000";
	
	--~ mHWRITE		<= from_wb_we_o;
	mHWRITE		<= wb_in.we_i;
	--~ mHTRANS		<= NONSEQ when (ctrlstart = '1' and ackmask = '0') else SEQ 
                          --~ when (from_wb_cti_o = "010" and ctrlstart = '1') else IDLE;
    mHTRANS		<= NONSEQ when (ctrlstart = '1' and ackmask = '0') else SEQ 
                          when (wb_in.cti_i = "010" and ctrlstart = '1') else IDLE;
                          	
	--~ isHBUSREQ	<= '1' when ((isburst = '1' and from_wb_cti_o = "010") or (isburst = '0' and from_wb_stb_o = '1' and ackmask = '0')) else '0';
	isHBUSREQ	<= '1' when ((isburst = '1' and wb_in.cti_i = "010") or (isburst = '0' and wb_in.stb_i = '1' and ackmask = '0')) else '0';
	HBUSREQ		<= isHBUSREQ;
	
	ctrl_prc : process(HCLK, HRESETn)
	begin
		if (HRESETn = '0') then
			ctrlstart <= '0';
		elsif (rising_edge(HCLK)) then
			if (isHBUSREQ = '0') then
				ctrlstart <= '0';
			elsif(mHGRANT = '1' and mHREADY = '1' and ctrlstart = '0') then 
				ctrlstart <= '1';
			else
				ctrlstart <= ctrlstart;
			end if;
		end if;
	end process ctrl_prc;
	
	ack_prc : process(HCLK, HRESETn)
	begin
		if (HRESETn = '0') then
			ackmask <= '0';
		elsif (rising_edge(HCLK)) then
			--~ if (from_wb_stb_o = '0') then
			if (wb_in.stb_i = '0') then
				ackmask <= '0';
			elsif (ctrlstart = '0' and ackmask = '0') then 
				ackmask <= '0';
			elsif (ctrlstart = '1' and wb_ack_i = '0' and mHREADY = '1') then
				ackmask <= '1';
			elsif (wb_ack_i = '1' and isburst = '0') then
				ackmask <= '0';
			--~ elsif (from_wb_cti_o = "111" and isburst = '0' and mHREADY = '1') then
			elsif (wb_in.cti_i = "111" and isburst = '0' and mHREADY = '1') then
				ackmask <= '0';
			else
				ackmask <= '1';
			end if;
		end if;
	end process ack_prc;

end rtl;
