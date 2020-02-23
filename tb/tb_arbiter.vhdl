
library ieee;
use ieee.std_logic_1164.all;
use work.wb_type.all;
library std;
use std.textio.all;


----------------------------------------------------------------------
-- Entity declaration.
----------------------------------------------------------------------

entity tb_arbiter is
	generic(
		arbiter_choose 		: integer := 2;  -- choose which arbiter two choose 1-priority arbiter 2-round robin abiter
		pty_test_file 		: string := "priority_arbiter_test_vector.txt";
		rr_test_file 		: string := "rr_arbiter_test_vector.txt"    -- round robin test vector
	);
end tb_arbiter;

architecture testbench of tb_arbiter is


    ------------------------------------------------------------------
    -- Define the module under test as a component.
    ------------------------------------------------------------------

	component priority_arbiter 
    port(
			clock	: in std_ulogic;
			reset_n	: in std_ulogic;
			
			cyc_i	: in std_ulogic_vector(MASTER_MODULE_COUNT - 1 downto 0);
			
			comcyc	: out std_ulogic;
			
			en_gnt_o: out std_ulogic_vector(index_size(MASTER_MODULE_COUNT) - 1 downto 0);
			gnt_o	: out std_ulogic_vector(MASTER_MODULE_COUNT - 1 downto 0)
         );

	end component priority_arbiter;

	component round_robin_arbiter 
    port(
			clock	: in std_ulogic;
			reset_n	: in std_ulogic;
			
			cyc_i	: in std_ulogic_vector(MASTER_MODULE_COUNT - 1 downto 0);
			
			comcyc	: out std_ulogic;
			
			en_gnt_o: out std_ulogic_vector(index_size(MASTER_MODULE_COUNT) - 1 downto 0);
			gnt_o	: out std_ulogic_vector(MASTER_MODULE_COUNT - 1 downto 0)
         );
   end component round_robin_arbiter;


    ------------------------------------------------------------------
    -- Define some local signals to assign values and observe.
    ------------------------------------------------------------------
	signal clock		: std_ulogic;
	signal reset_n		: std_ulogic;
	signal cyc_i		: std_ulogic_vector(MODULE_COUNT - 1 downto 0);
	signal comcyc		: std_ulogic;
	signal gnt_o		: std_ulogic_vector(MODULE_COUNT - 1 downto 0);
	signal en_gnt_o		: std_ulogic_vector(index_size(MASTER_MODULE_COUNT) - 1 downto 0);

begin

    ------------------------------------------------------------------
    -- Port map for the device under test.
    ------------------------------------------------------------------
    
    priority_arbiter_gen :
	if(arbiter_choose = 1) generate
		priority_arbiter_inst : priority_arbiter
		port map(
				clock	 => clock,
				reset_n	 => reset_n,
				cyc_i	 => cyc_i,
				comcyc	 => comcyc,
				en_gnt_o => en_gnt_o,
				gnt_o	 => gnt_o
			 );
	end generate priority_arbiter_gen;
	
	round_robin_arbiter_gen :
	if(arbiter_choose = 2) generate
		round_robin_arbiter_inst : round_robin_arbiter
		port map(
				clock	 => clock,
				reset_n	 => reset_n,
				cyc_i	 => cyc_i,
				comcyc	 => comcyc,
				en_gnt_o => en_gnt_o,
				gnt_o	 => gnt_o
			 );
	end generate round_robin_arbiter_gen;
	

    ------------------------------------------------------------------
    -- Test process.
    ------------------------------------------------------------------

    sim: process

        --------------------------------------------------------------
        -- Specify the test vector filename and other file parameters.
        --------------------------------------------------------------

        file tvfile:    text;
        variable L:     line;
        variable C:     character;


        --------------------------------------------------------------
        -- Specify the time duration for constant PERIOD.
        --------------------------------------------------------------
        constant PERIOD: time := 50 ns;

    begin

        --------------------------------------------------------------
        -- Open the file that contains the test vectors.
        --------------------------------------------------------------

        assert( false ) report "RUNNING TEST VECTORS" severity NOTE;
        case arbiter_choose is
			when 1 => 
				file_open( tvfile, pty_test_file, read_mode );
			when 2 =>
				file_open( tvfile, rr_test_file, read_mode );
			when others =>
				null;
        end case;
       
        READ_VECTORS: loop

            ----------------------------------------------------------
            -- If we're at the end of the file, then close the file
            -- and fall to the bottom of the loop.
            ----------------------------------------------------------

            if endfile( tvfile ) then
                file_close( tvfile );
                assert( false ) report "TEST VECTORS COMPLETE." severity NOTE;
                exit;
            end if;

            readline( tvfile, L );
   
            read( L, C );               -- Read the fireset_n character
            if( C = ':' ) then

                clock    <= '0';
                wait for (PERIOD / 4);


                ------------------------------------------------------
                -- Read and apply the input test vectors.
                ------------------------------------------------------

                read( L, C );
                assert( C = ' ' ) report "CHARACTER FOUND IN PLACE OF EXPECTED WHITE SPACE1." severity ERROR;
                read( L, C );
                assert( C = ' ' ) report "CHARACTER FOUND IN PLACE OF EXPECTED WHITE SPACE2." severity ERROR;


                ------------------------------------------------------
                -- Configure the 'reset_n' input.
                ------------------------------------------------------

                read( L, C );

                if( C = '0' ) then
                    reset_n <= '1';
                elsif( C = '1' ) then
                    reset_n <= '0';
                else
                    assert( false ) report "ILLEGAL TEST VECTOR, INPUT: 'reset_n'." severity ERROR;
                end if;


                ------------------------------------------------------
                -- Configure the 'CYCN' inputs.
                ------------------------------------------------------

                read( L, C );
                assert( C = ' ' ) report "CHARACTER FOUND IN PLACE OF EXPECTED WHITE SPACE3." severity ERROR;

                read( L, C );

                if( C = '0' ) then
                    cyc_i(3) <= '0';
                elsif( C = '1' ) then
                    cyc_i(3) <= '1';
                else
                    assert( false ) report "ILLEGAL TEST VECTOR, INPUT: 'cyc_i(3)'." severity ERROR;
                end if;

                read( L, C );

                if( C = '0' ) then
                    cyc_i(2) <= '0';
                elsif( C = '1' ) then
                    cyc_i(2) <= '1';
                else
                    assert( false ) report "ILLEGAL TEST VECTOR, INPUT: 'cyc_i(2)'." severity ERROR;
                end if;

                read( L, C );

                if( C = '0' ) then
                    cyc_i(1) <= '0';
                elsif( C = '1' ) then
                    cyc_i(1) <= '1';
                else
                    assert( false ) report "ILLEGAL TEST VECTOR, INPUT: 'cyc_i(1)'." severity ERROR;
                end if;

                read( L, C );

                if( C = '0' ) then
                    cyc_i(0) <= '0';
                elsif( C = '1' ) then
                    cyc_i(0) <= '1';
                else
                    assert( false ) report "ILLEGAL TEST VECTOR, INPUT: 'cyc_i(0)'." severity ERROR;
                end if;


                ------------------------------------------------------
                -- Configure the 'clock' inputs.
                ------------------------------------------------------

                read( L, C );
                assert( C = ' ' ) report "CHARACTER FOUND IN PLACE OF EXPECTED WHITE SPACE4." severity ERROR;

                wait for (PERIOD / 4);

                read( L, C );

                if( C = 'R' ) then
                    clock <= '1';
                else
                    assert( false ) report "ILLEGAL TEST VECTOR, INPUT: 'clock'." severity ERROR;
                end if;

                wait for (PERIOD / 4);


                ------------------------------------------------------
                -- Check the 'comcyc' output.
                ------------------------------------------------------

                read( L, C );
                assert( C = ' ' ) report "CHARACTER FOUND IN PLACE OF EXPECTED WHITE SPACE5." severity ERROR;

                read( L, C );
                if( C = '0' ) then
                    assert( comcyc = '0' ) report "comcyc ERROR." severity ERROR;
                elsif( C = '1' ) then
                    assert( comcyc = '1' ) report "comcyc ERROR." severity ERROR;
                else
                    assert( false ) report "ILLEGAL TEST VECTOR, OUTPUT: 'comcyc'." severity ERROR;
                end if;
				
				
				---------------------------------------------
				--~ read( L, C );
                --~ assert( C = ' ' ) report "CHARACTER FOUND IN PLACE OF EXPECTED WHITE SPACE6." severity ERROR;

                --~ read( L, C );
                ----------------------------------------------------
                
                ------------------------------------------------------
                -- Check the 'gnt_o(3)' output.
                ------------------------------------------------------

                read( L, C );
                assert( C = ' ' ) report "CHARACTER FOUND IN PLACE OF EXPECTED WHITE SPACE7." severity ERROR;

                read( L, C );
                if( C = '0' ) then
                    assert( gnt_o(3) = '0' ) report "gnt_o(3) ERROR." severity ERROR;
                elsif( C = '1' ) then
                    assert( gnt_o(3) = '1' ) report "gnt_o(3) ERROR." severity ERROR;
                else
                    assert( false ) report "ILLEGAL TEST VECTOR, OUTPUT: 'gnt_o(3)'." severity ERROR;
                end if;


                ------------------------------------------------------
                -- Check the 'gnt_o(2)' output.
                ------------------------------------------------------

                read( L, C );
                if( C = '0' ) then
                    assert( gnt_o(2) = '0' ) report "gnt_o(2) ERROR." severity ERROR;
                elsif( C = '1' ) then
                    assert( gnt_o(2) = '1' ) report "gnt_o(2) ERROR." severity ERROR;
                else
                    assert( false ) report "ILLEGAL TEST VECTOR, OUTPUT: 'gnt_o(2)'." severity ERROR;
                end if;


                ------------------------------------------------------
                -- Check the 'gnt_o(1)' output.
                ------------------------------------------------------

                read( L, C );
                if( C = '0' ) then
                    assert( gnt_o(1) = '0' ) report "gnt_o(1) ERROR." severity ERROR;
                elsif( C = '1' ) then
                    assert( gnt_o(1) = '1' ) report "gnt_o(1) ERROR." severity ERROR;
                else
                    assert( false ) report "ILLEGAL TEST VECTOR, OUTPUT: 'gnt_o(1)'." severity ERROR;
                end if;


                ------------------------------------------------------
                -- Check the 'gnt_o(0)' output.
                ------------------------------------------------------

                read( L, C );
                if( C = '0' ) then
                    assert( gnt_o(0) = '0' ) report "gnt_o(0) ERROR." severity ERROR;
                elsif( C = '1' ) then
                    assert( gnt_o(0) = '1' ) report "gnt_o(0) ERROR." severity ERROR;
                else
                    assert( false ) report "ILLEGAL TEST VECTOR, OUTPUT: 'gnt_o(0)'." severity ERROR;
                end if;


                ------------------------------------------------------
                -- All of the outputs have been checked for this test
                -- vector.  Delay a quarter of a period.
                ------------------------------------------------------

                wait for (PERIOD / 4);

            end if;
                
        end loop READ_VECTORS;

        wait;
        
    end process sim;

end architecture testbench;

