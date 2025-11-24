library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity myKeyboard is
    port (
        CLK             : in  std_logic;                    -- Board clock
        PS2_CLK         : in  std_logic;                    -- Keyboard clock signal
        PS2_DATA        : in  std_logic;                    -- Keyboard data signal
        
        -- !!! NEW OUTPUTS !!!
        scan_code_out   : out std_logic_vector(7 downto 0); -- The actual 8-bit scan code
        new_code_int    : out std_logic;                    -- Interrupt: Pulses '1' for one CLK cycle when a new code is valid
        
        LED             : out std_logic_vector(7 downto 0)  -- 8 LEDs
    );
end entity myKeyboard;

architecture Behavioral of myKeyboard is
	 
	 -- Define the clock reduction constant
	 constant CLK_DIV_COUNT : integer := 249; -- For a reduction factor of 250 (0 to 249)
    -- Constants (equivalent to 'wire [7:0]' with an initial value)
    constant ARROW_UP   : std_logic_vector(7 downto 0) := X"75";
    constant ARROW_DOWN : std_logic_vector(7 downto 0) := X"72";

    -- Signals (equivalent to 'reg' in Verilog)
    signal reads             : std_logic := '0';
    signal count_reading     : unsigned(11 downto 0) := (others => '0');
    signal previous_state    : std_logic := '1';
    signal scan_err          : std_logic := '0';
    signal scan_code         : std_logic_vector(10 downto 0) := (others => '0');
    signal codeword          : std_logic_vector(7 downto 0) := (others => '0');
    signal trig_arr          : std_logic := '0';
    signal count             : unsigned(3 downto 0) := (others => '0');
    signal trigger           : std_logic := '0';
    signal downcounter       : unsigned(7 downto 0) := (others => '0');
    
    -- !!! INTERNAL SIGNAL FOR INTERRUPT !!!
    signal int_reg           : std_logic := '0'; -- Internal register for the interrupt pulse
	-- !!! NEW INTERNAL SIGNAL FOR LED STATE !!!
    signal led_internal : std_logic_vector(7 downto 0) := (others => '0');

begin
    -- 2. Connect the internal signal to the external port
    scan_code_out <= codeword;
    new_code_int <= int_reg;
    LED <= led_internal; -- Connect the internal state to the external pin

    process (CLK) is
        variable parity_check_v : std_logic;
    begin
        if rising_edge(CLK) then

            -- Reset the interrupt flag every cycle unless re-asserted later
            int_reg <= '0'; 

            -- ----------------------------------------------------
            -- 1. Clock Reduction Logic (Simplified for brevity)
            -- ----------------------------------------------------
            if downcounter < to_unsigned(CLK_DIV_COUNT, downcounter'length) then
                downcounter <= downcounter + 1;
                trigger <= '0';
            else
                downcounter <= (others => '0');
                trigger <= '1';
            end if;

            -- Timeout counter logic 
            if trigger = '1' then
                if reads = '1' then
                    count_reading <= count_reading + 1;
                else
                    count_reading <= (others => '0');
                end if;
            end if;

            -- ----------------------------------------------------
            -- 2. PS/2 Data Reading and Error Checking 
            -- ----------------------------------------------------
            if trigger = '1' then
                
                if PS2_CLK /= previous_state then
                    if PS2_CLK = '0' then -- Falling edge of PS2_CLK
                        reads <= '1';
                        scan_err <= '0';
                        scan_code <= PS2_DATA & scan_code(10 downto 1);
                        count <= count + 1;
                    end if;
                elsif count = 11 then
                    count <= (others => '0');
                    reads <= '0';
                    trig_arr <= '1';
                    
                    parity_check_v := scan_code(1) xor scan_code(2) xor scan_code(3) xor scan_code(4) xor 
                                      scan_code(5) xor scan_code(6) xor scan_code(7) xor scan_code(8) xor 
                                      scan_code(9);
                    
                    -- Error Check: (Start Bit is '1') OR (Stop Bit is '0') OR (Parity is WRONG)
                    if (scan_code(10) = '1') or (scan_code(0) = '0') or (parity_check_v /= scan_code(9)) then
                        scan_err <= '1';
                    else
                        scan_err <= '0';
                    end if;

                else -- count < 11
                    trig_arr <= '0';
                    if count < 11 and count_reading >= 4000 then
                        count <= (others => '0');
                        reads <= '0';
                    end if;
                end if;
                
                previous_state <= PS2_CLK;
            end if;
            
            -- ----------------------------------------------------
            -- 3. CODEWORD Assignment and INTERRUPT Assertion
            -- ----------------------------------------------------
            if trigger = '1' then
                if trig_arr = '1' then
                    if scan_err = '1' then
                        codeword <= (others => '0');
                    else
                        codeword <= scan_code(8 downto 1);
                        
                        -- !!! ASSERT INTERRUPT HERE !!!
                        int_reg <= '1'; 
                        
                    end if;
                else
                    codeword <= (others => '0');
                end if;
            else
                codeword <= (others => '0');
            end if;

            -- ----------------------------------------------------
            -- 4. LED/Output Logic
            -- ----------------------------------------------------
           if trigger = '1' then
                if trig_arr = '1' and scan_err = '0' then
                    if codeword = ARROW_UP then
                        -- Now you read from led_internal and write back to led_internal
                        led_internal <= std_logic_vector(unsigned(led_internal) + 1);
                    elsif codeword = ARROW_DOWN then
                        led_internal <= std_logic_vector(unsigned(led_internal) - 1);
                    else
                        led_internal <= scan_code(8 downto 1);
                    end if;
                end if;
            end if;
            
        end if; 
    end process;
    
end architecture Behavioral;