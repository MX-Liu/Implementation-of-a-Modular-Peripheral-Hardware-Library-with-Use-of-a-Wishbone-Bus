library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity wb_i2c_slave is 
	port(
		clock		: in std_ulogic;
		reset_n		: in std_ulogic;
		
		slave_in 	: in wb_slave_in;
		slave_out 	: out wb_slave_out;
		
		sda 		: inout std_logic := 'Z';
		scl 		: inout std_logic := 'Z';
		
		i2c_irq_o	: out std_ulogic
	);
end entity wb_i2c_slave;

architecture rtl of wb_i2c_slave is
	
	
    signal full        : std_ulogic;
    signal empty       : std_ulogic;
    signal push        : std_ulogic;
    signal pop         : std_ulogic;
    signal data_in     : std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal addr_in     : std_ulogic_vector(31 downto 0);
    signal data_out    : std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal clkgen_en_o : std_ulogic; 
	signal clkgen_i    : std_ulogic_vector(07 downto 0);
	
	component i2c_master_module 
	port (
		-- host access --
		clock       : in  std_ulogic; -- global clock line
		reset_n		: in  std_ulogic;
		
		-- fifo interface
        full        : in  std_ulogic;
        empty       : in  std_ulogic;
        push        : out std_ulogic;
        pop         : out std_ulogic;
        data_in     : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        addr_in     : in  std_ulogic_vector(31 downto 0);
        data_out    : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        
		-- clock generator --
		clkgen_en_o : out std_ulogic; -- enable clock generator
		clkgen_i    : in  std_ulogic_vector(07 downto 0);
		-- com lines --
		i2c_sda_io  : inout std_logic; -- serial data line
		i2c_scl_io  : inout std_logic; -- serial clock line
		-- interrupt --
		i2c_irq_o   : out std_ulogic -- transfer done IRQ
	);
	end component i2c_master_module;
	
	component slave_wrapper
		port(
			clock		: in std_ulogic;
			reset_n		: in std_ulogic;
			
			---- bus interface
			wb_in		: in wb_slave_in;
			wb_out		: out wb_slave_out;
			
			---- fifo interface
			empty		: out std_ulogic;
			full		: out std_ulogic;
			
			data_in		: in std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			data_out 	: out std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			
			--the fifo to store the intern register addr,the control and status signal is same as the master_to_i2c_fifo.
			addr_out 	: out std_ulogic_vector(31 downto 0);
			
			push 		: in std_ulogic;
			pop			: in std_ulogic	
		);
	end component slave_wrapper;
	
begin
	inst_i2c_master_module : i2c_master_module
	port map(
		
		clock       => clock,
		reset_n		=> reset_n,
        full        => full,
        empty       => empty,
        push        => push,
        pop         => pop,
        data_in     => data_in,
        addr_in     => addr_in,
        data_out    => data_out,
		clkgen_en_o => clkgen_en_o,
		clkgen_i    => clkgen_i,
		i2c_sda_io  => sda,
		i2c_scl_io  => scl,
		i2c_irq_o   => i2c_irq_o
	);
	
	inst_clock_generator : clock_generator
    port map(
        clock       => clock,
        reset_n     => reset_n,
        
        clkgen_en   => clkgen_en_o,
        clkgen_o    => clkgen_i
    );
    
    inst_slave_wrapper : slave_wrapper
    port map(
			clock		=> clock,
			reset_n		=> reset_n,
			wb_in		=> slave_in,
			wb_out		=> slave_out,
			empty		=> empty,
			full		=> full,
			data_in		=> data_out,
			data_out 	=> data_in,
			addr_out 	=> addr_in,
			push 		=> push,
			pop			=> pop
		);
    
end rtl;
	
	
