-----------------------------------------------------------------
-- Project      : IDEF
-- Module       : UART-Model for Simulation
-- Last update  : 28.11.2013
-----------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

entity uart_model is
	generic (
		SYSTEM_CYCLE_TIME 	: time := 100 ns; -- 50 MHz
		-- file with data to be send to fpga
		FILE_NAME_COMMAND 	: string := "command.txt";
		-- file for dump of data, received by pc
		FILE_NAME_DUMP 		: string := "dump.txt";
		-- communication speed for uart-link
		BAUD_RATE 			: natural := 600;
		SIMULATION 			: boolean := false
	);
	port (
		-- global signals
		beg_simulation	: in std_ulogic;	
		end_simulation	: in std_ulogic;
		-- uart-pins (pc side)
		rx 				: in  std_ulogic; 
		tx 				: out std_ulogic
    );
end uart_model;

architecture sim of uart_model is

	constant MAX_NO_OF_BYTES : natural := 128;
	
	constant UART_BIT_TIME 	: time := 1 us * 1000000/BAUD_RATE;

	file file_command	: text open read_mode is FILE_NAME_COMMAND;
	file file_dump 		: text open write_mode is FILE_NAME_DUMP;
	
	type bytelist_t is array (0 to MAX_NO_OF_BYTES-1) of std_ulogic_vector(7 downto 0);
	signal send_buf		: bytelist_t;
	
begin 
	-- send data to fpga
	uart_send : process
		variable commandlist : bytelist_t:= (others => (others => '0'));
		variable active_line : line;
		variable neol : boolean := false;
		variable data_value : integer:= 0;
		variable cnt : natural := 0;
	begin
		tx <= '1';
		wait until(beg_simulation = '1');
		-- set line to "no data"
		tx <= '1';	
		-- preload list with undefined
		commandlist := (others => (others => 'U'));
		
		-- read preload file
		while not endfile(file_command) loop
			-- read line
			readline(file_command, active_line);
			-- loop until end of line
			loop
				read(active_line, data_value, neol);
				exit when not neol;
				-- write command to array
				commandlist(cnt) := std_ulogic_vector(to_unsigned(data_value, 8));
				send_buf(cnt)	<= std_ulogic_vector(to_unsigned(data_value, 8));
				-- increment counter
				cnt := cnt + 1;
			end loop;
		end loop;
		
		file_close(file_command);
	
		-- send data to fpga
		for i in 0 to MAX_NO_OF_BYTES-1 loop
			-- check if byte is valid, else stop
			if commandlist(i)(0) /= 'U' then 
			
				-- uart send procedure
				
				-- wait some cycles before start
				wait for 10*SYSTEM_CYCLE_TIME;
				
				-- start bit
				tx <= '0';
				if SIMULATION = false then 	wait for UART_BIT_TIME;
				
				--coverage off
				else						wait for SYSTEM_CYCLE_TIME*16;
				--coverage on
				end if;
				
				
				-- loop over data
				for j in 0 to 7 loop
					tx <= commandlist(i)(j);
					if SIMULATION = false then 	wait for UART_BIT_TIME;
					--coverage off
					else						wait for SYSTEM_CYCLE_TIME*16;
					--coverage on
					end if;
				end loop;
				
				-- stop bit
				tx <= '1';
				if SIMULATION = false then 	wait for UART_BIT_TIME;
				--coverage off
				else						wait for SYSTEM_CYCLE_TIME*16;
				--coverage on
				end if;
				
				
				-- write(active_line, string'("[UART] Sent "));
				-- write(active_line, to_integer(unsigned(commandlist(i))));
				-- write(active_line, string'(" ("));
				-- write(active_line, to_bitvector(commandlist(i)));
				-- write(active_line, string'(") to Master."));
				-- writeline(output, active_line);
				
				-- wait for some cycles before continuing
				wait for 10*SYSTEM_CYCLE_TIME;
				
			end if;
		end loop;
				
		-- wait forever
		-- coverage off
		wait;
		-- coverage on
	end process uart_send;
	
	
	
	-- receive data from fpga
	uart_receive : process
		variable receivelist 	: bytelist_t;
		variable cnt : integer;
		variable cnt1 : integer;
		variable cnt2 : integer;
		variable active_line : line;
		
		
	begin
		-- initialize receive buffer
		receivelist := (others => (others => 'U'));
		
		cnt := 0;
		cnt1:= 1;
		cnt2:= 0;
		
		
		
		-- always detect in the centre of a bit
		if SIMULATION = false then 	wait for UART_BIT_TIME*0.5;
		--coverage off
		else						wait for SYSTEM_CYCLE_TIME*16*0.5;
		--coverage on
		end if;
		
		
		loop
			-- stop when simulation is ended
			exit when end_simulation = '1';
			-- check if space in receive buffer is available, else break			
			exit when cnt = MAX_NO_OF_BYTES;
			
			
			-- startbit detected
			if rx = '0' then 
				--wait for first data bit
				--always detect in the centre of a bit
				if SIMULATION = false then 	wait for (UART_BIT_TIME/2) *3;
				--coverage off
				else						wait for SYSTEM_CYCLE_TIME*16;
				--coverage on
				end if;
				
				-- receive 8 bit
				for i in 0 to 7 loop
					receivelist(cnt)(i) := rx;
					if SIMULATION = false then 	wait for UART_BIT_TIME;
					--coverage off
					else						wait for SYSTEM_CYCLE_TIME*16;
					--coverage on
					end if;
					
				end loop;
				
				
				
				-- receive stop bit
				if rx = '1' then
					write(active_line, string'("[UART] Received "));
					write(active_line, to_integer(unsigned(receivelist(cnt))));
					write(active_line, string'(" ("));
					write(active_line, to_bitvector(receivelist(cnt)));
					write(active_line, string'(") from FPGA."));
					writeline(output, active_line);
					if (cnt < 32) then
						assert (send_buf(4*(cnt1)+cnt) = receivelist(cnt)) report "the receive data is not same as the send data" severity error;
					else
						assert (x"55" = receivelist(cnt)) report "the receive data is not same as the send data" severity error;
					end if;
			
				--coverage off
				else
					-- stopbit not received!
					write(active_line, string'("[UART] Expected Stop-Bit!"));
					writeline(output, active_line);
					--coverage on
				end if;
				
				
				-- inc counter
				cnt := cnt + 1;
				cnt2 := cnt2 + 1;
				if(cnt2 = 4) then
					cnt2 := 0;
					cnt1 := cnt1 + 1;	
				end if;
				
				
			else
				-- wait a cycle
				wait for SYSTEM_CYCLE_TIME;
			end if;
		
		end loop;
		
		-- loop over max number of bytes
		for i in 0 to MAX_NO_OF_BYTES-1 loop
			-- check if recieved byte is valid, else stop
			if receivelist(i)(0) /= 'U' then 
				-- add value to line (will result in one value per line)
				write(active_line, to_integer(unsigned(receivelist(i))));
				-- write line to file
				writeline(file_dump, active_line);
			end if;
		end loop;
		
		file_close(file_dump);
		
		-- wait forever
		
		wait;
		
	end process uart_receive;

end sim;
