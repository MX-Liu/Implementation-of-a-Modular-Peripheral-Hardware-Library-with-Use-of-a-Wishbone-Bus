library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity round_robin_arbiter is

    port(
			clock	: in std_ulogic;
			reset_n	: in std_ulogic;
			
			cyc_i	: in std_ulogic_vector(MASTER_MODULE_COUNT - 1 downto 0);
			
			comcyc	: out std_ulogic;
			
			en_gnt_o: out std_ulogic_vector(index_size(MASTER_MODULE_COUNT) - 1 downto 0);
			gnt_o	: out std_ulogic_vector(MASTER_MODULE_COUNT - 1 downto 0)
         );

end entity round_robin_arbiter;

architecture rtl of round_robin_arbiter is 
	--signal lst_gnt_mas		: std_ulogic_vector(MASTER_MODULE_COUNT - 1 downto 0);
	signal l_gnt_o			: bit_vector(MASTER_MODULE_COUNT - 1 downto 0);
	signal l_gnt_nxt		: bit_vector(MASTER_MODULE_COUNT - 1 downto 0);
	signal usr_zero			: std_ulogic_vector(MASTER_MODULE_COUNT - 1 downto 0) := (others => '0');	
	

	signal en_gnt			: std_ulogic_vector(index_size(MASTER_MODULE_COUNT) - 1 downto 0) := (others => '0');
	signal en_gnt_nxt		: std_ulogic_vector(index_size(MASTER_MODULE_COUNT) - 1 downto 0) := (others => '0');
	signal l_cyc_i			: std_ulogic_vector(MASTER_MODULE_COUNT - 1 downto 0);
	
	signal l_comcyc			: std_ulogic;
	
	signal beg				: std_ulogic;
	--signal edge, edge_nxt	: std_ulogic := '0';
	signal lst_mst			: std_ulogic;--last master is granted
	signal lst_mst_nxt		: std_ulogic;
	
	
begin
	-- encoder-----------
	
	l_cyc_i <= cyc_i;
	encoder_logic: process( l_gnt_o )
    begin
		en_gnt_nxt	<= n_bit_encoder(to_stdulogicvector(l_gnt_o));
    end process encoder_logic;
	
	 
	 arbiter_logic : process(reset_n,l_comcyc,en_gnt,cyc_i,l_gnt_o)
	 begin
		 l_gnt_nxt <= l_gnt_o;
		 if(reset_n = '0')then 
			 l_gnt_nxt <= (others => '0');
		 elsif(l_comcyc = '0') then
			 if(cyc_i = (cyc_i'range => '0')) then
				 l_gnt_nxt <= (others => '0');
			 else
			     --if(en_gnt = (en_gnt'range => '0')) then
					--l_gnt_nxt <= (others => '0');
					--l_gnt_nxt(priority_encoding((to_bitvector(cyc_i)))) <= '1'; 
			     --else
					l_gnt_nxt <= (others => '0');	
					l_gnt_nxt(((priority_encoding((to_bitvector(cyc_i) ror (to_integer(unsigned(en_gnt)+1))))+1+to_integer(unsigned(en_gnt))) rem MASTER_MODULE_COUNT)) <= '1'; 
			     --end if;
				 
			 end if;
		 end if;
		
	  end process arbiter_logic;
	 

	------------------------------------------------------------------
    -- LASMAS state machine.
    ------------------------------------------------------------------
	begin_logic: process( cyc_i, l_comcyc)
    begin  
		if(l_comcyc = '0' and (cyc_i /= (cyc_i'range => '0'))) then
			beg <= '1';
		else
			beg <= '0';
		end if;

    end process begin_logic;

    
    lst_mas_state: process(beg,lst_mst)
    begin

		lst_mst_nxt <= (beg and not(lst_mst));
				
    end process lst_mas_state;
    
    state_reg : process(clock,reset_n)
    begin
		if(reset_n = '0') then
			lst_mst <= '0';
			--edge     <= '0';
		elsif(rising_edge(clock)) then
			lst_mst <= lst_mst_nxt;
			--edge    <= edge_nxt;
		end if;
	end process state_reg;
    
	
	 ------------------------------------------------------------------
    -- COMCYC logic.
    ------------------------------------------------------------------

    comcyc_logic: process( cyc_i,l_gnt_o)
    begin  
	
		 if((cyc_i and to_stdulogicvector(l_gnt_o)) = usr_zero) then
			 l_comcyc <= '0';
		 else
			 l_comcyc <= '1';
		 end if;
		
    end process comcyc_logic;
	
	----------------------------------------------------------------------
	--encoder-------------------------------------------------------------
	----------------------------------------------------------------------
	
	register_syn: process(clock)
	begin
		
		if(rising_edge(clock)) then
			if(reset_n = '0') then
				l_gnt_o <= (others => '0');
				en_gnt <= (others => '0');
			else
				l_gnt_o <= l_gnt_nxt;
			end if;
			
			if(lst_mst = '1') then
				--lst_gnt_mas <= to_stdulogicvector(l_gnt_o);
				en_gnt <= en_gnt_nxt;
				
			end if;
		end if;
	end process register_syn;
	
	make_visiable: process(l_comcyc, l_gnt_o,en_gnt_nxt)
	begin
		comcyc	<= l_comcyc;
		gnt_o	<= to_stdulogicvector(l_gnt_o);
		en_gnt_o<= en_gnt_nxt;
	end process make_visiable;

end rtl;
