library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity wb_dma_slave is
	port(
		clock		: std_ulogic;
		dma_clock	: std_ulogic;
		reset_n		: std_ulogic;
		
		---- bus interface
		wb_in		: in wb_slave_in;
		wb_out		: out wb_slave_out;
		
		-- memory interface
		--hold_req	: out std_ulogic;
		--hold_ack	: in  std_ulogic;
		mem_en		: out  std_ulogic;
		mem_wr		: out std_ulogic;
		mem_rd		: out std_ulogic;
		mem_addr_o	: out std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
		mem_dat_o	: out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
		mem_dat_i	: in  std_ulogic_vector(DATA_WIDTH - 1 downto 0)
	);
end entity wb_dma_slave;

architecture rtl of wb_dma_slave is
	
	signal L_full		: std_ulogic;
	signal L_data_in	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal L_push 		: std_ulogic;
	signal L_empty		: std_ulogic;
	signal L_data_out	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal L_addr_out	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal L_pop 		: std_ulogic;
	

	component dma is
	port(
		clock		: in std_ulogic;
		reset_n		: in std_ulogic;
			
		-- fifo interface
		full 		: in  std_ulogic;
		empty 		: in  std_ulogic;
		push		: out std_ulogic;
		pop			: out std_ulogic;
		data_in		: in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
		addr_in 	: in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
		data_out	: out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
			
		-- memory interface
		--hold_req	: out std_ulogic;
		--hold_ack	: in  std_ulogic;
		mem_en		: out  std_ulogic;
		mem_wr		: out std_ulogic;
		mem_rd		: out std_ulogic;
		mem_addr_o	: out std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
		mem_dat_o	: out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
		mem_dat_i	: in  std_ulogic_vector(DATA_WIDTH - 1 downto 0)		
		);
	end component dma;
	
	--~ component slave_wrapper_with_burst is
	--~ port(
			--~ clock		: in std_ulogic;
			--~ reset_n		: in std_ulogic;
			
			--~ ---- bus interface
			--~ wb_in		: in wb_slave_in;
			--~ wb_out		: out wb_slave_out;
			
			--~ ---- fifo interface
			--~ empty		: out std_ulogic;
			--~ full		: out std_ulogic;
			
			--~ data_in		: in std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			--~ data_out 	: out std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			--~ --the fifo to store the intern register addr,the control and status signal is same as the master_to_uart_fifo.
			--~ addr_out 	: out std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
			
			--~ push 		: in std_ulogic;
			--~ pop			: in std_ulogic	
		--~ );
	--~ end component slave_wrapper_with_burst;
	
	-- here replace the synchronous fifo with asynchronous fifo
	component slave_wrapper_dma 
    port(
            clock       : in std_ulogic;
            reset_n     : in std_ulogic;
            
            dma_clock	: in std_ulogic;
            
            ---- bus interface
            wb_in       : in wb_slave_in;
            wb_out      : out wb_slave_out;
            
            ---- fifo interface
            empty       : out std_ulogic;
            full        : out std_ulogic;
            
            data_in     : in std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
            data_out    : out std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
            --the fifo to store the intern register addr,the control and status signal is same as the master_to_uart_fifo.
            addr_out    : out std_ulogic_vector(DATA_WIDTH  - 1 downto 0);
            
            push        : in std_ulogic;
            pop         : in std_ulogic 
        );
	end component slave_wrapper_dma;

begin
	inst_dma : dma 
	port map(
		clock		=> dma_clock,
		reset_n		=> reset_n,
			
		-- fifo interface
		full 		=> L_full,
		empty 		=> L_empty,
		push		=> L_push,
		pop			=> L_pop,
		data_in		=> L_data_out,
		addr_in 	=> L_addr_out,
		data_out	=> L_data_in,
			
		-- memory interface
		mem_en		=> mem_en,
		mem_wr		=> mem_wr,
		mem_rd		=> mem_rd,
		mem_addr_o	=> mem_addr_o,
		mem_dat_o	=> mem_dat_o,
		mem_dat_i	=> mem_dat_i		
		);
		
	--~ inst : slave_wrapper_with_burst
	--~ port map(
			--~ clock		=> clock,
			--~ reset_n		=> reset_n,
			
			--~ ---- bus interface
			--~ wb_in		=> wb_in,
			--~ wb_out		=> wb_out,
			
			--~ ---- fifo interface
			--~ empty		=> L_empty,
			--~ full		=> L_full,
			
			--~ data_in		=> L_data_in,
			--~ data_out 	=> L_data_out,
			--~ --the fifo to store the intern register addr,the control and status signal is same as the master_to_uart_fifo.
			--~ addr_out 	=> L_addr_out,
			
			--~ push 		=> L_push,
			--~ pop			=> L_pop
		--~ );
		inst_slave_wrapper : slave_wrapper_dma
		port map(
			clock		=> clock,
			dma_clock   => dma_clock,
			reset_n		=> reset_n,
			
			---- bus interface
			wb_in		=> wb_in,
			wb_out		=> wb_out,
			
			---- fifo interface
			empty		=> L_empty,
			full		=> L_full,
			
			data_in		=> L_data_in,
			data_out 	=> L_data_out,
			--the fifo to store the intern register addr,the control and status signal is same as the master_to_uart_fifo.
			addr_out 	=> L_addr_out,
			
			push 		=> L_push,
			pop			=> L_pop
		);


end rtl;
