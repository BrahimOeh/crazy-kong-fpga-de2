---------------------------------------------------------------------------------
-- kbd to joystick - Dar - Feb 2014
---------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

entity kbd_joystick is
port (
  clk           : in std_logic;
  kbd_int       : in std_logic;
--  coin_switch   : in std_logic;
  kbd_scan_code : in std_logic_vector(7 downto 0)
--  joy_pcfrldu   : out std_logic_vector(6 downto 0)
);
end kbd_joystick;

architecture behavioral of kbd_joystick is

signal is_released : std_logic;

begin 

process(clk)
begin
  if rising_edge(clk) then
  
    if kbd_int = '1' then
      if kbd_scan_code = "11110000" then is_released <= '1'; else is_released <= '0'; end if; 
--     if kbd_scan_code = "01110101" then joy_pcfrldu(0) <= not(is_released); end if;	-- UP
--     if kbd_scan_code = "01110010" then joy_pcfrldu(1) <= not(is_released); end if;	-- DOWN
--     if kbd_scan_code = "01101011" then joy_pcfrldu(2) <= not(is_released); end if;	-- LEFT
--     if kbd_scan_code = "01110100" then joy_pcfrldu(3) <= not(is_released); end if;	-- RIGHT
--     if kbd_scan_code = "00101001" then joy_pcfrldu(4) <= not(is_released); end if;	-- JUMP
--     if kbd_scan_code = "00000101" then joy_pcfrldu(5) <= not(is_released); end if;	-- START
--     if kbd_scan_code = "00000110" then joy_pcfrldu(6) <= not(is_released); end if;	-- COIN
		end if;
	
-- if coin_switch = '0' then joy_pcfrldu(6) <= '1'; else joy_pcfrldu(6) <= '0'; end if;
	
  end if;
end process;

end behavioral;


