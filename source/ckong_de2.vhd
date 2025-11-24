---------------------------------------------------------------------------------
-- DE2 Top level for crazy kong - https://github.com/BrahimOeh - August 2025
--
-- Main features
--  15KHz(TV) / 31Khz(VGA) : board switch(0)
--  PS2 keyboard input
--  wm8731 sound output
--  128Ko of board SRAM used
--
-- Uses only one pll for 36MHz generation from 50MHz
-- DE1 and DE0 nano Top level also available
-- 
-- COIN SWITCH  = GPIO_0[0]   
-- START SWITCH = GPIO_0[1]  
-- JUMP SWITCH  = GPIO_0[2] 
-- UP SWITCH    = GPIO_0[3] 
-- DOWN SWITCH  = GPIO_0[4] 
-- LEFT SWITCH  = GPIO_0[5] 
-- RIGHT SWITCH = GPIO_0[6]  
--
---------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.ALL;
use IEEE.numeric_std.all;

entity ckong_de2 is
port(
	clock_50  : in std_logic;
--	clock_27  : in std_logic;
--	ext_clock : in std_logic;
--	ledr       : out std_logic_vector(17 downto 0);
--	ledg       : out std_logic_vector(8 downto 0);
	key       : in std_logic_vector(3 downto 0);
	sw        : in std_logic_vector(17 downto 0);
	
	sw_coin	: in std_logic;
	sw_start	: in std_logic;
	sw_jump	: in std_logic;
	sw_up		: in std_logic;
	sw_down	: in std_logic;
	sw_left	: in std_logic;
	sw_right	: in std_logic;

--	dram_ba_0 : out std_logic;
--	dram_ba_1 : out std_logic;
--	dram_ldqm : out std_logic;
--	dram_udqm : out std_logic;
--	dram_ras_n : out std_logic;
--	dram_cas_n : out std_logic;
--	dram_cke : out std_logic;
--	dram_clk : out std_logic;
--	dram_we_n : out std_logic;
--	dram_cs_n : out std_logic;
--	dram_dq : inout std_logic_vector(15 downto 0);
--	dram_addr : out std_logic_vector(11 downto 0);
--
--	fl_addr  : out std_logic_vector(21 downto 0);
--	fl_ce_n  : out std_logic;
--	fl_oe_n  : out std_logic;
--	fl_dq    : inout std_logic_vector(7 downto 0);
--	fl_rst_n : out std_logic;
--	fl_we_n  : out std_logic;
--
--	hex0 : out std_logic_vector(6 downto 0);
--	hex1 : out std_logic_vector(6 downto 0);
--	hex2 : out std_logic_vector(6 downto 0);
--	hex3 : out std_logic_vector(6 downto 0);
--	hex4 : out std_logic_vector(6 downto 0);
--	hex5 : out std_logic_vector(6 downto 0);
--	hex6 : out std_logic_vector(6 downto 0);
--	hex7 : out std_logic_vector(6 downto 0);

	ps2_clk : in std_logic;
	ps2_dat : inout std_logic;

--	uart_txd : out std_logic;
--	uart_rxd : in std_logic;
--
--	lcd_rw   : out std_logic;
--	lcd_en   : out std_logic;
--	lcd_rs   : out std_logic;
--	lcd_data : out std_logic_vector(7 downto 0);
--	lcd_on   : out std_logic;
--	lcd_blon : out std_logic;
	
	sram_addr : out std_logic_vector(17 downto 0);
	sram_dq   : inout std_logic_vector(15 downto 0);
	sram_we_n : out std_logic;
	sram_oe_n : out std_logic;
	sram_ub_n : out std_logic;
	sram_lb_n : out std_logic;
	sram_ce_n : out std_logic;
	
--	otg_addr   : out std_logic_vector(1 downto 0);
--	otg_cs_n   : out std_logic;
--	otg_rd_n   : out std_logic;
--	otg_wr_n   : out std_logic;
--	otg_rst_n  : out std_logic;
--	otg_data   : inout std_logic_vector(15 downto 0);
--	otg_int0   : in std_logic;
--	otg_int1   : in std_logic;
--	otg_dack0_n: out std_logic;
--	otg_dack1_n: out std_logic;
--	otg_dreq0  : in std_logic;
--	otg_dreq1  : in std_logic;
--	otg_fspeed : inout std_logic;
--	otg_lspeed : inout std_logic;
--	
--	tdi : in std_logic;
--	tcs : in std_logic;
--	tck : in std_logic;
--	tdo : out std_logic;
	
	vga_r     : out std_logic_vector(9 downto 0);
	vga_g     : out std_logic_vector(9 downto 0);
	vga_b     : out std_logic_vector(9 downto 0);
	vga_clk   : out std_logic;
	vga_blank : out std_logic;
	vga_hs    : out std_logic;
	vga_vs    : out std_logic;
	vga_sync  : out std_logic;

	i2c_sclk : out std_logic;
	i2c_sdat : inout std_logic;
	
--	td_clk27 : in std_logic;
--	td_reset : out std_logic;
--	td_data : in std_logic_vector(7 downto 0);
--	td_hs : in std_logic;
--	td_vs : in std_logic;

	aud_adclrck : out std_logic;
	aud_adcdat  : in std_logic;
	aud_daclrck : out std_logic;
	aud_dacdat  : out std_logic;
	aud_xck     : out std_logic;
	aud_bclk    : out std_logic;
	
--	enet_data : inout std_logic_vector(15 downto 0);
--	enet_clk : out std_logic;
--	enet_cmd : out std_logic;
--	enet_cs_n : out std_logic;
--	enet_int : in std_logic;
--	enet_rd_n : out std_logic;
--	enet_wr_n : out std_logic;
--	enet_rst_n : out std_logic;
--	
--	irda_txd : out std_logic;
--	irda_rxd : in std_logic;
--	
--	sd_dat : inout std_logic;
--	sd_dat3 : out std_logic;
--	sd_cmd : out std_logic;
--	sd_clk : out std_logic;
--	
--	gpio_0    : inout std_logic_vector(35 downto 0);
--	gpio_1    : inout std_logic_vector(35 downto 0);
	LED       : out std_logic_vector(7 downto 0)  -- 8 LEDs
);
end ckong_de2;

architecture struct of ckong_de2 is

	alias tv15Khz_mode : std_logic is sw(17);
	
--	signal tv15Khz_mode   : std_logic;

	alias ram_data : std_logic_vector is sram_dq(7 downto 0);

-- DE2 numbering
--	alias iec_atn_i  : std_logic is gpio_1(32);
--	alias iec_clk_o  : std_logic is gpio_1(33);
--	alias iec_data_o : std_logic is gpio_1(34);
--	alias iec_atn_o  : std_logic is gpio_1(35);
--	alias iec_data_i : std_logic is gpio_1(2);
--	alias iec_clk_i  : std_logic is gpio_1(0);

-- DE0 nano numbering
--	alias iec_atn_i  : std_logic is gpio_0(30);
--	alias iec_clk_o  : std_logic is gpio_0(31);
--	alias iec_data_o : std_logic is gpio_0(32);
--	alias iec_atn_o  : std_logic is gpio_0(33);
--	alias iec_data_i : std_logic is gpio_0_in(1);
--	alias iec_clk_i  : std_logic is gpio_0_in(0);

	signal clock_36 : std_logic;
	signal clock_18 : std_logic;
	signal r : std_logic_vector(2 downto 0);
	signal g : std_logic_vector(2 downto 0);
	signal b : std_logic_vector(1 downto 0);
	signal video_clk : std_logic;
	signal hsync : std_logic;
	signal vsync : std_logic;
	signal csync : std_logic;
	signal blank : std_logic;

	--signal adr_cpu : std_logic_vector (10 downto 0);
	signal sram_we  : std_logic;

	signal audio_data   : std_logic_vector(15 downto 0);
	signal sound_string : std_logic_vector(31 downto 0 );

begin

--	tv15Khz_mode <= sw(17);

--	gpio_1(35 downto 0) <= (others => 'Z');
--	gpio_0(35 downto 0) <= (others => 'Z');

	------------------
	pll36 : entity work.pll_50mhz_36mhz
	port map(
		inclk0 => clock_50,
		c0     => clock_36
	);

	process(clock_36)
	begin
		if falling_edge(clock_36) then
			clock_18 <= not clock_18;
		end if; 
	end process;

	ckong : entity work.ckong
	port map(
		clock_36mhz  => clock_36,
		reset        => key(0),
		ps2_clk      => ps2_clk,
		ps2_dat      => ps2_dat,
		tv15Khz_mode => tv15Khz_mode,
		sw_coin		 => sw_coin,
		sw_start		 => sw_start,
		sw_jump		 => sw_jump,
		sw_up		    => sw_up,
		sw_down		 => sw_down,
		sw_left		 => sw_left,
		sw_right		 => sw_right,		
		video_r      => r,
		video_g      => g,
		video_b      => b,
		video_clk    => video_clk,
		video_csync  => csync,
		video_hs     => hsync,
		video_vs     => vsync,
		sound_string => audio_data,
		sram_addr    => sram_addr(16 downto  0),
		sram_we      => sram_we,
		sram_data    => sram_dq(7 downto 0),
		LEDckong     => LED
	);

	sram_addr(17 downto 17) <= (others => '0');
	sram_ce_n <= '0';
	sram_we_n <= not sram_we;
	sram_oe_n <= sram_we;
	sram_ub_n <= '0';
	sram_lb_n <= '0';

	vga_clk <= video_clk;
	vga_sync <=  '0';
	vga_blank <= '1';

	vga_r <= std_logic_vector(r) & "0000000";
	vga_g <= std_logic_vector(g) & "0000000";
	vga_b <= std_logic_vector(b) & "00000000";

-- synchro composite/ synchro horizontale
	vga_hs <= csync when tv15Khz_mode = '1' else hsync;
-- commutation rapide / synchro verticale
	vga_vs <= '1'   when tv15Khz_mode = '1' else vsync;

	sound_string <= audio_data & audio_data;

wm8731_dac : entity work.wm_8731_dac
port map(
	clk18mhz    => clock_18,
	sampledata  => sound_string,
	i2c_sclk    => i2c_sclk,
	i2c_sdat    => i2c_sdat,
	aud_bclk    => aud_bclk,
	aud_daclrck => aud_daclrck,
	aud_dacdat  => aud_dacdat,
	aud_xck     => aud_xck
); 

end struct;
