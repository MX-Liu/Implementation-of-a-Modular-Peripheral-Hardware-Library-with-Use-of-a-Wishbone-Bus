library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package wb_type is
------------------------------
-- constants
------------------------------
    constant MODULE_COUNT               : integer := 4; -- be powered of 2
      
    constant MODULE_REG_ADDR_WIDTH      : integer := 3;
    
    constant MASTER_MODULE_COUNT		: integer := 4; -- be powered of 2 and it is master module
    constant SLAVE_MODULE_COUNT			: integer := 8; 
    
    constant NEO430_MASTER_USE			: boolean := false;
    constant UART_USE					: boolean := true;
    constant I2C_MASTER_USE				: boolean := true;
    constant I2C_SLAVE_USE              : boolean := true;
    constant DMA_SLAVE_USE              : boolean := true;
    constant SPI_SLAVE_USE              : boolean := true;
    constant REGISTER_SLAVE_USE	        : boolean := true;
    constant TIMER_SLAVE_USE            : boolean := true;
    constant PWM_SLAVE_USE              : boolean := true;
    constant GPIO_SLAVE_USE             : boolean := true;
    constant ROUND_ROBIN_ARBITER_USE	: boolean := true;
    constant PRIORITY_ARBITER_USE       : boolean := false;
    
    constant DMA_RAM_USE				: boolean := false;
    
     
    -- length of peripheral system bus address
    constant ADDR_MODULES               : integer := 3; -- is equal to log2(SLAVE_MODULE_COUNT)
    constant ADDR_WIDTH                 : integer := MODULE_REG_ADDR_WIDTH + ADDR_MODULES;
    constant MEM_DATA_WIDTH				: integer := 32;
    -- width of data bus
    constant DATA_WIDTH                 : integer := 32;
    -- FIFO depth Configuration --------------------------
    constant FIFO_DEPTH 		: integer := 8;
    
    -- declaration of module indexes (MODULE_COUNT adjust!...)
    -- declaration of master module indexes
    constant uart_master_id_base 		: integer := 0;
    constant uart_master_count			: integer := 1;
    constant neo_master_id_base 		: integer := uart_master_id_base + uart_master_count;
    constant neo_master_count 			: integer := 0;
    constant i2c_master_id_base			: integer := neo_master_id_base + neo_master_count;
    constant i2c_master_count			: integer := 1;
    
    constant uart_slave_id_base			: integer := 0;
    constant uart_slave_count 			: integer := 2;
    constant reg_slave_id_base 			: integer := uart_slave_id_base + uart_slave_count;
    constant reg_slave_count			: integer := 1;
    constant i2c_slave_id_base 			: integer := reg_slave_id_base + reg_slave_count;
    constant i2c_slave_count 			: integer := 1;
   
    
    constant dma_slave_id_base			: integer := i2c_slave_id_base + i2c_slave_count;
    constant dma_slave_count			: integer := 1;
    constant spi_slave_id_base			: integer := dma_slave_id_base + dma_slave_count;
    constant spi_slave_count			: integer := 1;
    constant pwm_slave_id_base			: integer := spi_slave_id_base + spi_slave_count;
    constant pwm_slave_count			: integer := 1;
    constant timer_slave_id_base		: integer := pwm_slave_id_base + pwm_slave_count;
    constant timer_slave_count			: integer := 1;
    
    
    ------------------------------------------------------
    -- uart configuration --------------------------------
    -- f(uart_clk_prc) :----------------------------------
    --uart_clk_prc = 0 : clk/2 
    --uart_clk_prc = 1 : clk/4
    --uart_clk_prc = 2 : clk/8
    --uart_clk_prc = 3 : clk/64
    --uart_clk_prc = 4 : clk/128
    --uart_clk_prc = 5 : clk/1024
    --uart_clk_prc = 6 : clk/2048
    --uart_clk_prc = 7 : clk/4096
    --uart_baut_cnt = mainclock/(f(uart_clk_prc)*bautrate)
    constant uart_baut_cnt  : std_ulogic_vector := x"D9"; --if 9600   main clock = 100 MHZ  100M/(64*9600) = xA3
    constant uart_clk_prc   : integer := 0;                --if 115200   main clock = 50 MHZ  50M/(2*115200) = xD9
    
    -- pwm configuration ---------------------------------
    constant pwm_channel_count_c : integer:= 1; 
    
    -- Endianness configfuration----------------------+----
    constant Big_Endian			: integer := 1; -- when Big_Endian = 0, it is little Eandian.
    
    ------------------------------------------------------
    -- user is not allowed to change following constant 
    ------------------------------------------------------
    
    constant uart_rx_byte_cnt_c : integer := DATA_WIDTH/8 + 5;  
    constant uart_tx_byte_cnt_c : integer := DATA_WIDTH/8;
    
    constant i2c_rx_byte_cnt_c 	: integer := DATA_WIDTH/8 + 3;
    constant i2c_tx_byte_cnt_c  : integer := DATA_WIDTH/8 - 1;
    
    constant spi_byte_cnt_c		: integer := DATA_WIDTH/8;
    
    constant zero_data			: std_ulogic_vector(DATA_WIDTH - 1 downto 0):= (others => '0');
    
    
    type wb_master_in is record
        dat_i   : std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        ack_i   : std_ulogic;
    end record;
    
    type wb_master_out is record
        adr_o   : std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
        dat_o   : std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        we_o    : std_ulogic;
        
        stb_o   : std_ulogic;
        cyc_o   : std_ulogic;
        
        sel_o   : std_ulogic_vector(3 downto 0);
        cti_o   : std_ulogic_vector(2 downto 0);
        bte_o   : std_ulogic_vector(1 downto 0);
    end record;
    
    type wb_slave_in is record
        adr_i   : std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
        dat_i   : std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        we_i    : std_ulogic;

        stb_i   : std_ulogic;
        cyc_i   : std_ulogic;
        sel_i   : std_ulogic_vector(3 downto 0);
        cti_i   : std_ulogic_vector(2 downto 0);
        bte_i   : std_ulogic_vector(1 downto 0);
    end record;
    
    type wb_slave_out is record
        dat_o       : std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        ack_o       : std_ulogic;
    end record;
    
    type t_wb_adr_i is array (0 to MODULE_COUNT - 1) of std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
    
    -- function declaration:    
    function index_size(input : natural) return natural;
    function priority_encoding(input : bit_vector) return natural;
    function n_bit_encoder(input : std_ulogic_vector) return std_ulogic_vector;
    function conditional(sel : boolean; x : integer; y : integer) return integer;
    function convert_endianess(input : std_ulogic_vector) return std_ulogic_vector;
    function max(a, b : integer) return integer;
    function min(a, b : integer) return integer;
    function genmux(s,v : std_ulogic_vector) return std_ulogic;
    function charater2vector(input : character) return std_ulogic_vector;
    function charater2bit(input : character) return std_ulogic;
    
    ------------------------------------------------------------------
    -- round-robin arbiter.
    ------------------------------------------------------------------
    component round_robin_arbiter
    port(
            clock   : in std_ulogic;
            reset_n : in std_ulogic;
            
            cyc_i   : in std_ulogic_vector(MODULE_COUNT - 1 downto 0);
            
            comcyc  : out std_ulogic;
            en_gnt_o: out std_ulogic_vector(index_size(MODULE_COUNT) - 1 downto 0);
            gnt_o   : out std_ulogic_vector(MODULE_COUNT - 1 downto 0)
         );
    end component round_robin_arbiter;
    
    ------------------------------------------------------------------
    -- priority_arbiter
    ------------------------------------------------------------------
    component priority_arbiter
    port(
            clock   : in std_ulogic;
            reset_n : in std_ulogic;
            
            cyc_i   : in std_ulogic_vector(MODULE_COUNT - 1 downto 0);
            
            comcyc  : out std_ulogic;
            en_gnt_o: out std_ulogic_vector(index_size(MODULE_COUNT) - 1 downto 0);
            gnt_o   : out std_ulogic_vector(MODULE_COUNT - 1 downto 0)
         );
    end component priority_arbiter;
    
    
    ------------------------------------------------------------------
    -- regiter module with slave wishbone bus interface
    ------------------------------------------------------------------ 
    component wb_register is
    port(
            clock       : in std_ulogic;
            reset_n     : in std_ulogic;
            
            ---- bus interface
            wb_in       : in wb_slave_in;
            wb_out      : out wb_slave_out
        );
    end component wb_register;

    ------------------------------------------------------------------
    -- i2c module with master wishbone bus interface
    ------------------------------------------------------------------
    component wb_i2c_master
    port(
        clock       : in std_ulogic;
        reset_n     : in std_ulogic;
        
        master_in   : in wb_master_in;
        master_out  : out wb_master_out;
        
        sda         : inout std_logic := 'Z';
        scl         : inout std_logic := 'Z'
    );
    end component wb_i2c_master;
    
    -------------------------------------------------------------------
    -- i2c module with slave wishbone bus interface
    -------------------------------------------------------------------
    component wb_i2c_slave 
        port(
            clock       : in std_ulogic;
            reset_n     : in std_ulogic;
            
            slave_in    : in wb_slave_in;
            slave_out   : out wb_slave_out;
            
            sda         : inout std_logic := 'Z';
            scl         : inout std_logic := 'Z';
            
            i2c_irq_o	: out std_ulogic
        );
    end component wb_i2c_slave;
    
   
    --------------------------------------------------------------------
    -- uart module with wishbone bus interface
    --------------------------------------------------------------------
    component wb_uart 
    port(
        clock       : in  std_ulogic;
        reset_n     : in  std_ulogic;
        
        m_wb_out    : out wb_master_out;
        m_wb_in     : in  wb_master_in;
        
        s_wb_out    : out wb_slave_out;
        s_wb_in     : in  wb_slave_in;
        
        uart_tx_o   : out std_ulogic;
        uart_rx_i   : in  std_ulogic
    );
    end component wb_uart;
    
    --------------------------------------------------------------------
    -- dma slave module with wishbone bus interface
    --------------------------------------------------------------------
    component wb_dma_slave 
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
	end component wb_dma_slave;
	
	--------------------------------------------------------------------
    -- spi slave module with wishbone bus interface
    --------------------------------------------------------------------
    component wb_spi_slave is
	port(
		clock		: std_ulogic;
		reset_n		: std_ulogic;
		
		---- bus interface
		wb_in		: in wb_slave_in;
		wb_out		: out wb_slave_out;
		
		-- spi interface
		spi_irq_o	: out std_ulogic;
		spi_sclk_o  : out std_ulogic; -- SPI serial clock
        spi_mosi_o  : out std_ulogic; -- SPI master out, slave in
        spi_miso_i  : in  std_ulogic; -- SPI master in, slave out
        spi_cs_o    : out std_ulogic_vector(07 downto 0)
	);
	end component wb_spi_slave;
	
	--------------------------------------------------------------------
    -- timer slave module with wishbone bus interface
    --------------------------------------------------------------------
	component wb_timer is
	port (
		clock		: in std_ulogic;
		reset_n		: in std_ulogic;
		
		-- wishbone interface 
		wb_in		: in wb_slave_in;
		wb_out		: out wb_slave_out;
		
		irq_o       : out std_ulogic  -- interrupt request
	);
	end component wb_timer;

	--------------------------------------------------------------------
    -- pwm slave module with wishbone bus interface
    --------------------------------------------------------------------
	component wb_pwm is
	--~ generic(
		--~ pwm_channel_count_c : integer:= 8 -- 1 to 8
	--~ );
	port (
		clock		: in std_ulogic;
		reset_n		: in std_ulogic;
		
		-- wishbone interface 
		wb_in		: in wb_slave_in;
		wb_out		: out wb_slave_out;
		-- clock generator --
		--~ clkgen_en_o : out std_ulogic; -- enable clock generator
		--~ clkgen_i    : in  std_ulogic_vector(07 downto 0);
		-- pwm output channels --
		pwm_o       : out std_ulogic_vector(pwm_channel_count_c - 1 downto 0)
	);
	end component wb_pwm;

	
	
    component slave_wrapper_with_burst 
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
	end component slave_wrapper_with_burst;
	
	
	component clock_generator is 
	port(
        clock   : in std_ulogic;
        reset_n : in std_ulogic;
        
        clkgen_en   : in std_ulogic;
        clkgen_o    : out  std_ulogic_vector(07 downto 0)
    );
    end component clock_generator;
    
     --------------------------------------------------------------------
    -- fifo module -----------------------------------------------------
    --------------------------------------------------------------------
    component fifo 
    generic(
        fifo_width : integer := 32;
        fifo_depth : integer := 8
        );
    port(
        clock       : in std_logic;
        reset_n     : in std_logic;
        data_in     : in  std_ulogic_vector(fifo_width - 1 downto 0);
        data_out    : out std_ulogic_vector(fifo_width - 1 downto 0);

        empty       : out std_logic;
        full        : out std_logic;

        pop         : in std_logic;
        push        : in std_logic
    );
    end component fifo;
    
    --------------------------------------------------------------------
    -- asynchronous fifo 
    component asyn_fifo 
	generic(
		FIFO_WIDTH 	: integer := 32;
		FIFO_DEPTH 	: integer := 8
	);
	port(
		reset_n		: in std_ulogic;
		wr_en		: in std_ulogic;
		wr_clk		: in std_ulogic;
		data_i		: in std_ulogic_vector(FIFO_WIDTH - 1 downto 0);
		full		: out std_ulogic;
		
		rd_en 		: in std_ulogic;
		rd_clk		: in std_ulogic;
		data_o 		: out std_ulogic_vector(FIFO_WIDTH - 1 downto 0);
		empty 		: out std_ulogic
	);
	end component asyn_fifo;
	
	
	component ram 
	port(
		clock 		: in std_ulogic;
		reset_n 	: in std_ulogic;
		mem_en_i    : in std_ulogic;
        mem_wr_i    : in std_ulogic;
        mem_rd_i    : in std_ulogic;
        mem_addr_i  : in std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
        mem_dat_i   : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        mem_dat_o   : out  std_ulogic_vector(DATA_WIDTH - 1 downto 0)
	);
	end component ram;

	
end wb_type;


package body wb_type is
--coverage off
------------------------------
-- some functions
------------------------------

-- conditional operator ( ? : )
    function conditional(sel : boolean; x : integer; y : integer) return integer is
    begin
        if sel then
            return x;
        else
            return y;
        end if;
    end function conditional;
-- endianess conversation
    function convert_endianess(input : std_ulogic_vector) return std_ulogic_vector is
        variable output_v : std_ulogic_vector(input'range);
        variable high_byte : integer;
    begin
        high_byte := input'length / 8 - 1;
        for i in 0 to high_byte loop
            output_v(i * 8 + 7 downto i * 8) := input((high_byte - i) * 8 + 7 downto (high_byte - i) * 8);
        end loop; -- i
    return output_v;
  end function convert_endianess;
  
-- max
    function max(a, b : integer) return integer is
    begin
        if a > b then
            return a;
        else
            return b;
        end if;
    end function;

    function max(a, b : unsigned) return unsigned is
    begin
        if a > b then
            return a;
        else
            return b;
    end if;
    end function;

-- min
    function min(a, b : integer) return integer is
    begin
        if a < b then
            return a;
        else
            return b;
        end if;
    end function;

    function min(a, b : unsigned) return unsigned is
    begin
        if a < b then
            return a;
        else
            return b;
        end if;
    end function;
    
-- log2(input)
    function index_size(input : natural) return natural is
    begin
        if (input = 0) then
          return 0;
        end if;
        for i in 0 to natural'high loop
          if (2**i >= input) then
            return i;
          end if;
        end loop;
        return 0;
    end function index_size;

-- n_bit priority encoder
    function priority_encoding(input : bit_vector) return natural is
        variable first_bit  : natural;
    begin
        for i in 0 to input'length - 1 loop
            if(input(i) = '1')then
                first_bit := i;
                exit;
            else
                first_bit := 0;
            end if;
        end loop;
        return(first_bit);
    end function priority_encoding;
    
-- n_bit_encoder
    function n_bit_encoder(input : std_ulogic_vector) return std_ulogic_vector is
        variable encoder    : std_ulogic_vector(index_size(input'length) - 1 downto 0);
        variable input_len  : integer;
    begin
        input_len := input'length;
        if(input = (input'range => '0')) then
            encoder := (others=> '0');
        else
            for i in 0 to input_len - 1 loop
                if(input(i) = '1') then
                    encoder := std_ulogic_vector(to_unsigned(i,index_size(MODULE_COUNT)));
                    exit;
                end if;
            end loop;
        end if;
        return encoder;
    end function n_bit_encoder;

-- mux, s is the encoded vector, v is to be selected 
    function genmux(s,v : std_ulogic_vector) return std_ulogic is
        variable res : std_ulogic_vector(v'length-1 downto 0);
        variable i   : integer;
    begin
    
        res := v;
        i := 0;
        i := to_integer(unsigned(s));
        return(res(i));
        
    end function genmux;
    
    
    function charater2vector(input : character) return std_ulogic_vector is
        variable v  : std_ulogic_vector(3 downto 0);
    begin
        --assert( input = ' ' ) report "CHARACTER FOUND IN PLACE OF EXPECTED WHITE SPACE." severity ERROR;
        case input is
            when '0' => v := b"0000";
            when '1' => v := b"0001";
            when '2' => v := b"0010";
            when '3' => v := b"0011";
            when '4' => v := b"0100";
            when '5' => v := b"0101";
            when '6' => v := b"0110";
            when '7' => v := b"0111";
            when '8' => v := b"1000";
            when '9' => v := b"1001";
            when 'A' => v := b"1010";
            when 'B' => v := b"1011";
            when 'C' => v := b"1100";
            when 'D' => v := b"1101";
            when 'E' => v := b"1110";
            when 'F' => v := b"1111";
            when others => v := b"0000";
        end case;
        return v;
    end function charater2vector;
    
    function charater2bit(input : character) return std_ulogic is
        variable b  : std_ulogic;
    begin
        --assert( input = ' ' ) report "CHARACTER FOUND IN PLACE OF EXPECTED WHITE SPACE." severity ERROR;
        if(input = '1') then
            b := '1';
        else
            b := '0'; 
        end if;
        return b;
    end function charater2bit;
--coverage on
end wb_type;    

        
        
        
        
        
        
