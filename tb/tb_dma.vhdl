library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wb_type.all;

entity tb_dma is

end entity tb_dma;

architecture dut of tb_dma is 
	constant periode 	: time := 20 ns;
	signal clock		: std_ulogic := '0';
	signal reset_n 		: std_ulogic;
	signal full 		: std_ulogic;
	signal empty 		: std_ulogic;
	signal empty_addr 	: std_ulogic;
	signal empty_data 	: std_ulogic;
	signal push			: std_ulogic;
	signal pop			: std_ulogic;
	signal data_in		: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal addr_in 		: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal data_out		: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	
	signal hold_req		: std_ulogic;
	signal hold_ack		: std_ulogic;
	signal mem_en		: std_ulogic;
	signal mem_wr		: std_ulogic;
	signal mem_rd		: std_ulogic;
	signal mem_addr_o	: std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
	signal mem_dat_o	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal mem_dat_i	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	
	-- the signal of wishbone side
	signal wb_push		: std_ulogic;
	signal wb_full		: std_ulogic;
	signal wb_full_addr	: std_ulogic;
	signal wb_full_data	: std_ulogic;
	signal wb_addr_in	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal wb_data_in	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	signal wb_pop 		: std_ulogic;
	signal wb_empty		: std_ulogic;
	signal wb_data_out	: std_ulogic_vector(DATA_WIDTH - 1 downto 0);
	
	component fifo is
	generic(
		fifo_width : integer := 32;
		fifo_depth : integer := 8
		);
	port(
		clock		: in std_logic;
		reset_n		: in std_logic;
		data_in		: in  std_ulogic_vector(fifo_width - 1 downto 0);
		data_out	: out std_ulogic_vector(fifo_width - 1 downto 0);

		empty		: out std_logic;
		full		: out std_logic;

		pop			: in std_logic;
		push		: in std_logic
	);
    end component fifo;
    
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

begin
	inst_data_fifo : fifo
	generic map(
		fifo_width => 32,
		fifo_depth => 8
		)
	port map(
		clock		=> clock,
		reset_n		=> reset_n,
		data_in		=> wb_data_in,
		data_out	=> data_in,

		empty		=> empty_data,
		full		=> wb_full_data,

		pop			=> pop,
		push		=> wb_push
	);
	
	inst_addr_fifo : fifo
	generic map(
		fifo_width => 32,
		fifo_depth => 8
		)
	port map(
		clock		=> clock,
		reset_n		=> reset_n,
		data_in		=> wb_addr_in,
		data_out	=> addr_in,

		empty		=> empty_addr,
		full		=> wb_full_addr,

		pop			=> pop,
		push		=> wb_push
	);
	
	empty <= empty_addr or empty_data;
	wb_full	<= wb_full_addr or wb_full_data;
	
	inst_data_read_fifo : fifo
	generic map(
		fifo_width => 32,
		fifo_depth => 8
		)
	port map(
		clock		=> clock,
		reset_n		=> reset_n,
		data_in		=> data_out,
		data_out	=> wb_data_out,

		empty		=> wb_empty,
		full		=> full,

		pop			=> wb_pop,
		push		=> push
	);
	
	inst_dma : dma 
	port map(
		clock		=> clock,
		reset_n		=> reset_n,
		
		full 		=> full,
		empty 		=> empty,
		push		=> push,
		pop			=> pop,
		data_in		=> data_in,
		addr_in 	=> addr_in,
		data_out	=> data_out,
		
		--hold_req	=> hold_req,
		--hold_ack	=> hold_ack,
		mem_en		=> mem_en,
		mem_wr		=> mem_wr,
		mem_rd		=> mem_rd,
		mem_addr_o	=> mem_addr_o,
		mem_dat_o	=> mem_dat_o,
		mem_dat_i	=> mem_dat_i
		);
	
	clock <= not clock after periode / 2;
	
	
	sim: process
	begin
		reset_n 	<= '0';
		wb_data_in	<= (others => '0');
		wb_addr_in  <= (others => '0');
		wb_pop		<= '0';
		wb_push		<= '0';
		
		wait for 3*periode;
		reset_n <= '1';
		
		-- burst write test
		wait for periode;
		wb_push <= '1';
		wb_addr_in	<= x"00000001";
		wb_data_in	<= x"F8000301";
		wait for periode;
		wb_push <= '1';
		wb_addr_in	<= x"00000002";
		wb_data_in	<= x"348980a2";
		wait for periode;
		wb_push <= '1';
		wb_addr_in	<= x"00000002";
		wb_data_in	<= x"348980a3";
		wait for periode;
		wb_push <= '1';
		wb_addr_in	<= x"00000002";
		wb_data_in	<= x"348980a4";
		wait for periode;
		wb_push <= '1';
		wb_addr_in	<= x"00000002";
		wb_data_in	<= x"348980a5";
		wait for periode;
		wb_push <= '1';
		wb_addr_in	<= x"00000002";
		wb_data_in	<= x"348980a6";
		wait for periode;
		wb_push <= '1';
		wb_addr_in	<= x"00000002";
		wb_data_in	<= x"348980a7";
		wait for periode;
		wb_push <= '0';
		wait for periode;
		wait for periode;
		wait for periode;
		wait for periode;
		wait for periode;
		wb_push <= '1';
		wb_addr_in	<= x"00000002";
		wb_data_in	<= x"348980a8";
		wait for periode;
		wb_push <= '1';
		wb_addr_in	<= x"00000002";
		wb_data_in	<= x"348980a9";
		wait for periode;
		wb_push <= '1';
		wb_addr_in	<= x"00000002";
		wb_data_in	<= x"348980aa";
		wait for periode;
		wb_push <= '1';
		wb_addr_in	<= x"00000002";
		wb_data_in	<= x"348980ab";
		wait for periode;
		wb_push <= '1';
		wb_addr_in	<= x"00000001";
		wb_data_in	<= x"00000000";
		
		-- single write test
		wait for periode;
		wb_push <= '1';
		wb_addr_in	<= x"00000001";
		wb_data_in	<= x"C8000306";
		wait for periode;
		wb_push <= '1';
		wb_addr_in	<= x"00000002";
		wb_data_in	<= x"348980aa";
		
		wait for periode;
		wb_push <= '1';
		wb_addr_in	<= x"00000001";
		wb_data_in	<= x"C8000305";
		wait for periode;
		wb_push <= '1';
		wb_addr_in	<= x"00000002";
		wb_data_in	<= x"348980BB";
		
		wait for periode;
		wb_push <= '1';
		wb_addr_in	<= x"00000001";
		wb_data_in	<= x"C8000303";
		wait for periode;
		wb_push <= '1';
		wb_addr_in	<= x"00000002";
		wb_data_in	<= x"348980CC";
		
		
		
		wait for periode;
		wb_push <= '0';
		wait for periode;
		
		wait;
	end process sim;


end dut;
