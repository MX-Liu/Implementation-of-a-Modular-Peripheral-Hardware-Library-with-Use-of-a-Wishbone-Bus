library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity priority_arbiter is
    port(
			clock	: in std_ulogic;
			reset_n	: in std_ulogic;
			
			cyc_i	: in std_ulogic_vector(MASTER_MODULE_COUNT - 1 downto 0);
			
			comcyc	: out std_ulogic;
			
			en_gnt_o: out std_ulogic_vector(index_size(MASTER_MODULE_COUNT) - 1 downto 0);
			gnt_o	: out std_ulogic_vector(MASTER_MODULE_COUNT - 1 downto 0)
         );

end entity priority_arbiter;

architecture rtl of priority_arbiter is 
	--signal lst_gnt_mas		: std_ulogic_vector(MASTER_MODULE_COUNT - 1 downto 0);
	signal l_gnt_o			: bit_vector(MASTER_MODULE_COUNT - 1 downto 0);
	signal l_gnt_lst		: bit_vector(MASTER_MODULE_COUNT - 1 downto 0);
	--signal usr_zero			: std_ulogic_vector(MASTER_MODULE_COUNT - 1 downto 0) := (others => '0');	
	

	signal en_gnt			: std_ulogic_vector(index_size(MASTER_MODULE_COUNT) - 1 downto 0) := (others => '0');
	signal en_gnt_nxt		: std_ulogic_vector(index_size(MASTER_MODULE_COUNT) - 1 downto 0) := (others => '0');
	signal l_cyc_i			: std_ulogic_vector(MASTER_MODULE_COUNT - 1 downto 0);
	
	signal l_comcyc			: std_ulogic;
	
	signal beg				: std_ulogic;
	--signal edge, edge_nxt	: std_ulogic := '0';
	signal lst_mst			: std_ulogic;--last master is granted
	signal lst_mst_nxt		: std_ulogic;
	
	
begin
	
	encoder_logic: process( l_gnt_o )
    begin
		en_gnt_o <= n_bit_encoder(to_stdulogicvector(l_gnt_o));
    end process encoder_logic;
	
	
	arbiter_logic : process(clock, reset_n)
	begin
		if(rising_edge(clock)) then
			l_gnt_o <= l_gnt_o;
			--l_gnt_o <= l_gnt_o;
			if(reset_n = '0')then 
				l_gnt_o <= (others => '0');
			elsif(l_comcyc = '0') then
			
				l_gnt_o <= (others => '0');
				
				if(cyc_i = (cyc_i'range => '0')) then
					l_gnt_o <= (others => '0');
				else	
					l_gnt_o(priority_encoding((to_bitvector(cyc_i)))) <= '1';
				end if;

			end if;
		end if;
		
	end process arbiter_logic;
	
	
	
	
	------------------------------------------------------------------
    -- COMCYC logic.
    ------------------------------------------------------------------

    comcyc_logic: process( cyc_i,l_gnt_o)
    begin  
	
		 if((cyc_i and to_stdulogicvector(l_gnt_o)) = "0000") then
			 l_comcyc <= '0';
		 else
			 l_comcyc <= '1';
		 end if;
		
    end process comcyc_logic;
	
	
	make_visiable: process(l_comcyc, l_gnt_o)
	begin
		comcyc	<= l_comcyc;
		gnt_o	<= to_stdulogicvector(l_gnt_o);
	end process make_visiable;

end rtl;

