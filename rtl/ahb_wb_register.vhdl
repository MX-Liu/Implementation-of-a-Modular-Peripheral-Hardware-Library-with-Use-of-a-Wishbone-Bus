library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity ahb_wb_register is
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
end entity ahb_wb_register;

architecture rtl of ahb_wb_register is

	signal to_wb_dat_i 		: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal to_wb_adr_i		: std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
	signal to_wb_sel_i		: std_ulogic_vector(3 downto 0);
	signal to_wb_we_i		: std_ulogic;
	signal to_wb_cyc_i		: std_ulogic;
	signal to_wb_stb_i		: std_ulogic;
	
	signal to_wb_bte_i		: std_ulogic_vector(1 downto 0);
	signal to_wb_cti_i		: std_ulogic_vector(2 downto 0);
	
	signal from_wb_dat_o	: std_ulogic_vector(DATA_WIDTH - 1 downto 0); 
	signal from_wb_ack_o	: std_ulogic;
	signal from_wb_err_o	: std_ulogic;
	
	signal wb_in			: wb_slave_in;
	signal wb_out			: wb_slave_out;
	
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
		
		-- wishbone master signal
		to_wb_dat_i 	: out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
		to_wb_adr_i		: out std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
		to_wb_sel_i		: out std_ulogic_vector(3 downto 0);
		to_wb_we_i		: out std_ulogic;
		to_wb_cyc_i		: out std_ulogic;
		to_wb_stb_i		: out std_ulogic;
		
		to_wb_bte_i		: out std_ulogic_vector(1 downto 0);
		to_wb_cti_i		: out std_ulogic_vector(2 downto 0);
		
		from_wb_dat_o	: in  std_ulogic_vector(DATA_WIDTH - 1 downto 0); 
		from_wb_ack_o	: in  std_ulogic;
		from_wb_err_o	: in  std_ulogic
	);
	end component m_ahb2wb;
	
	
	component wb_register 
	port(
			clock		: in std_ulogic;
			reset_n		: in std_ulogic;
			
			---- bus interface
			wb_in		: in wb_slave_in;
			wb_out		: out wb_slave_out
			
		);
	end component wb_register;
	
begin
	inst_m_ahb2wb : m_ahb2wb
	port map(
		
		HCLK		 ,
		HRESETn		 ,       
		sHADDR		 ,
		sHWDATA		 ,
		sHWRITE		 ,
		sHSIZE 		 ,
		sHBURST 	 ,
		sHSEL 		 ,
		sHTRANS		 ,
		sHREADYIN	 ,
		sHREADY		 ,
		sHRDATA		 ,
		sHRESP		 ,
		to_wb_dat_i  ,
		to_wb_adr_i	 ,
		to_wb_sel_i	 ,
		to_wb_we_i	 ,
		to_wb_cyc_i	 ,
		to_wb_stb_i	 ,
		to_wb_bte_i  ,
		to_wb_cti_i	 ,
		from_wb_dat_o,
		from_wb_ack_o,
		from_wb_err_o	
	
	);

	inst_wb_register : wb_register
	port map(
		HCLK,
		HRESETn,
		wb_in,
		wb_out
		
	);
	
	from_wb_dat_o <= wb_out.dat_o;
	from_wb_ack_o <= wb_out.ack_o;
	
	wb_in.dat_i	  <= to_wb_dat_i;
	wb_in.adr_i   <= to_wb_adr_i;
	wb_in.sel_i   <= to_wb_sel_i;
	wb_in.we_i    <= to_wb_we_i ;
	wb_in.cyc_i   <= to_wb_cyc_i;
	wb_in.stb_i   <= to_wb_stb_i;
	wb_in.bte_i	  <= to_wb_bte_i;
	wb_in.cti_i	  <= to_wb_cti_i;
	
end rtl;
	
	
	
