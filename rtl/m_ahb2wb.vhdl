library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity m_ahb2wb is
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
		wb_in 			: in  wb_master_in
	);
end entity m_ahb2wb;

architecture rtl of m_ahb2wb is
	signal HRESP_nxt	: std_ulogic_vector(1 downto 0);
	signal isHRESP		: std_ulogic_vector(1 downto 0);
	signal wb_cyc_o		: std_ulogic;
	signal wb_cyc_nxt	: std_ulogic;
	signal wb_stb_o		: std_ulogic;
	signal wb_stb_nxt	: std_ulogic;
	signal wb_bte_o		: std_ulogic_vector(1 downto 0);
	signal wb_bte_nxt	: std_ulogic_vector(1 downto 0);
	signal wb_cti_o		: std_ulogic_vector(2 downto 0);
	signal wb_cti_nxt	: std_ulogic_vector(2 downto 0);
	signal wb_sel_o		: std_ulogic_vector(3 downto 0);
	signal wb_sel_nxt	: std_ulogic_vector(3 downto 0);
	signal wb_adr_o		: std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
	signal wb_adr_nxt	: std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
	signal wb_we_o		: std_ulogic;
	signal wb_we_nxt	: std_ulogic;
	signal adr_valid	: std_ulogic;
begin
	-- output --------------------------------------------------------
	
	wb_out.adr_o 	<= wb_adr_o;
	wb_out.we_o		<= wb_we_o;
	wb_out.sel_o	<= wb_sel_o;
	wb_out.cyc_o	<= wb_cyc_o;
	wb_out.stb_o	<= wb_stb_o;
	wb_out.dat_o	<= sHWDATA;
	wb_out.bte_o	<= wb_bte_o;
	wb_out.cti_o	<= wb_cti_o;
	
	
	sHRDATA		<= wb_in.dat_i;
	sHREADY		<= wb_in.ack_i when (wb_stb_o = '1') else '1';
	sHRESP		<= isHRESP;
	
	bridge : process(wb_bte_o, wb_cti_o, wb_cyc_o, wb_stb_o, wb_sel_o, wb_adr_o, wb_we_o, isHRESP, sHSEL, sHREADYIN, sHSIZE, sHTRANS, sHADDR, sHWRITE)
	begin
		wb_cyc_nxt 	<= wb_cyc_o;
		wb_stb_nxt	<= wb_stb_o;
		wb_sel_nxt	<= wb_sel_o;
		wb_adr_nxt	<= wb_adr_o;
		wb_we_nxt	<= wb_we_o;
		wb_bte_nxt	<= wb_bte_o;
		wb_cti_nxt	<= wb_cti_o;
		HRESP_nxt	<= isHRESP;
		wb_bte_nxt	<= (others => '0');
		wb_cti_nxt	<= (others => '0');
		if (sHSEL = '1') then -- slave has been selected 
			if (sHREADYIN = '1') then -- the last data transfer phase is finished 
				-- the bus only support 32 bit data 
				if (sHSIZE /= "010") then   
					wb_cyc_nxt 	<= '0';
					wb_stb_nxt	<= '0';
					wb_we_nxt	<= '0';
					wb_sel_nxt	<= (others => '0');
					wb_adr_nxt	<= (others => '0');
					wb_bte_nxt	<= (others => '0');
					wb_cti_nxt	<= (others => '0');
					if (sHTRANS = "00") then
						HRESP_nxt <= "00";
					else
						HRESP_nxt <= "01";
					end if;
				else
					case sHTRANS is
						when "00" => -- IDLE state, no operation 
							wb_cyc_nxt 	<= '0';
							wb_stb_nxt	<= '0';
							wb_sel_nxt	<= (others => '0');
							wb_adr_nxt	<= (others => '0');
							wb_bte_nxt	<= (others => '0');
							wb_cti_nxt	<= (others => '0');
							HRESP_nxt <= "00";
						when "01" => -- busy state, master insert into a wait state.
							wb_cyc_nxt 	<= '1';
							wb_stb_nxt	<= '0';
							wb_bte_nxt	<= (others => '0');
							wb_cti_nxt	<= (others => '0');
							
						when "10" => -- begin to tranfer
							HRESP_nxt <= "00";
							wb_cyc_nxt 	<= '1';
							wb_stb_nxt	<= '1';
							wb_sel_nxt	<= "1111";
							wb_adr_nxt	<= sHADDR;
							wb_we_nxt	<= sHWRITE;
							wb_bte_nxt	<= (others => '0');
							wb_cti_nxt	<= (others => '0');
						when "11" =>
							HRESP_nxt <= "00";
							wb_cyc_nxt 	<= '1';
							wb_stb_nxt	<= '1';
							wb_sel_nxt	<= "1111";
							wb_adr_nxt	<= sHADDR;
							wb_we_nxt	<= sHWRITE;
							wb_bte_nxt	<= (others => '0'); -- burst mode
							wb_cti_nxt	<= "001";
						-- coverage off	
						when others =>
							wb_cyc_nxt 	<= '0';
							wb_stb_nxt	<= '0';
							wb_we_nxt	<= '0';
							wb_sel_nxt	<= (others => '0');
							wb_adr_nxt	<= (others => '0');
							HRESP_nxt <= "00";
					end case;
					-- coverage on
				end if;
			end if;
		else
			wb_cyc_nxt 	<= '0';
			wb_stb_nxt	<= '0';
			wb_we_nxt	<= '0';
			wb_sel_nxt	<= (others => '0');
			wb_adr_nxt	<= (others => '0');
			HRESP_nxt <= "00";
		end if;
	end process bridge;
	
	reg_prc	: process(HCLK, HRESETn)
	begin
		if (HRESETn = '0') then
			wb_cyc_o	<= '0';
			wb_stb_o	<= '0';
			wb_sel_o	<= (others => '0');
			wb_adr_o	<= (others => '0');
			wb_bte_o	<= (others => '0');
			wb_cti_o    <= (others => '0');
			wb_we_o		<= '0';
			isHRESP		<= (others => '0');
		elsif(rising_edge(HCLK)) then
			wb_cyc_o	<= wb_cyc_nxt; 	
			wb_stb_o    <= wb_stb_nxt;	
			wb_sel_o    <= wb_sel_nxt;
			if(sHREADY = '1') then	
				wb_adr_o    <= wb_adr_nxt;	
			end if;
			wb_we_o	    <= wb_we_nxt;
			wb_bte_o	<= wb_bte_nxt;
			wb_cti_o    <= wb_cti_nxt;
			isHRESP	    <= HRESP_nxt;	
		end if;
	end process reg_prc;
end rtl;

