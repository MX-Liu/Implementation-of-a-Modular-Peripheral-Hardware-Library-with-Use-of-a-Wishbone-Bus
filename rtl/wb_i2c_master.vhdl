library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity wb_i2c_master is
	port(
		clock		: in std_ulogic;
		reset_n		: in std_ulogic;
		
		master_in 	: in wb_master_in;
		master_out 	: out wb_master_out;
		
		sda 		: inout std_logic := 'Z';
		scl 		: inout std_logic := 'Z'
	);
end entity wb_i2c_master;

architecture rtl of wb_i2c_master is
	
	signal data_in		: std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
	signal addr_in		: std_ulogic_vector(31 downto 0);
	signal data_out		: std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
	signal push			: std_ulogic;
	signal pop			: std_ulogic;
	--signal wr_en		: std_ulogic;
	--signal rd_en		: std_ulogic;
	signal empty		: std_ulogic;
	signal full 		: std_ulogic;
	
	component master_wrapper
		port(
			clock		: in std_ulogic;
			reset_n		: in std_ulogic;
			
			---- bus interface
			wb_in		: in wb_master_in;
			wb_out		: out wb_master_out;
			
			---- fifo interface
			empty		: out std_ulogic;
			full		: out std_ulogic;
			
			data_in		: in std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			addr_in 	: in std_ulogic_vector(31 downto 0);
			data_out 	: out std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			
			push 		: in std_ulogic;
			pop			: in std_ulogic
	
		);
	end component master_wrapper;
	
	
	component i2c_slave_module
	generic (
		SLAVE_ADDR : std_ulogic_vector(6 downto 0) := "1010011");
	port (
			clock		: in std_ulogic;
			reset_n		: in std_ulogic;
			---- external fifo control interface
			empty		: in std_ulogic;
			full		: in std_ulogic;
			
			data_in		: in std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			data_out 	: out std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			addr_out 	: out std_ulogic_vector(31 downto 0);
	
			push 		: out std_ulogic;
			pop			: out std_ulogic;
--			wr_en		: out std_ulogic;
--			rd_en		: out std_ulogic;
			
			-- I2C interface 
			sda 		: inout std_logic := 'Z';
			scl 		: inout std_logic := 'Z'
		);
	end component i2c_slave_module;
	
begin
	inst_master_wrapper : master_wrapper
	port map(
				clock		=> clock,
				reset_n		=> reset_n,
				
				---- bus interface
				wb_in		=> master_in,
				wb_out		=> master_out,
				
				---- fifo interface
				empty		=> empty,
				full		=> full,
				
				data_in		=> data_in,
				addr_in 	=> addr_in,
				data_out 	=> data_out,
				
		
				push 		=> push,
				pop			=> pop
						
		);
	
	inst_i2c_slave_module: i2c_slave_module
	generic map(
		SLAVE_ADDR => "1010011")
	port map(
			clock		=> clock,
			reset_n		=> reset_n,
			---- external fifo control interface
			empty		=> empty,
			full		=> full,
			
			data_in		=> data_out,
			data_out 	=> data_in,
			addr_out 	=> addr_in,
	
			push 		=> push,
			pop			=> pop,
			
			-- I2C interface 
			sda 		=> sda,
			scl 		=> scl
		);
	
end rtl;
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
