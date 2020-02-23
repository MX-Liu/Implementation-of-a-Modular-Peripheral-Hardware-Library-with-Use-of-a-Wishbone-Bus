library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clock_generator is 
    port(
        clock   : in std_ulogic;
        reset_n : in std_ulogic;
        
        clkgen_en   : in std_ulogic;
        clkgen_o    : out  std_ulogic_vector(07 downto 0)
    );
end entity clock_generator;

architecture rtl of clock_generator is
    signal clk_div      : std_ulogic_vector(11 downto 0);
    signal clk_div_ff   : std_ulogic_vector(11 downto 0);

begin

    clkdiv_process : process(clock, reset_n)
    begin
        if(reset_n = '0') then
            clk_div <= (others => '0');
        elsif(rising_edge(clock)) then
            if(clkgen_en = '1') then 
                clk_div <= std_ulogic_vector(unsigned(clk_div) + 1);
            end if;
        end if;
    end process clkdiv_process;
    
    clk_div_buff : process(clock)
    begin
        if(rising_edge(clock)) then
            clk_div_ff <= clk_div;
        end if;
    end process clk_div_buff;
    
    clkgen_o(0) <= clk_div_ff(0) and (not clk_div(0)); --clk/2
    clkgen_o(1) <= clk_div_ff(1) and (not clk_div(1)); --clk/4
    clkgen_o(2) <= clk_div_ff(2) and (not clk_div(2)); --clk/8
    clkgen_o(3) <= clk_div_ff(5) and (not clk_div(5)); --clk/64
    clkgen_o(4) <= clk_div_ff(6) and (not clk_div(6)); --clk/128
    clkgen_o(5) <= clk_div_ff(9) and (not clk_div(9)); --clk/1024
    clkgen_o(6) <= clk_div_ff(10) and (not clk_div(10)); -- clk/2048
    clkgen_o(7) <= clk_div_ff(11) and (not clk_div(11)); -- clk/4096
end rtl;
