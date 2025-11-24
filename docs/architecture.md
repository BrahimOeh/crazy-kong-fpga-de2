# Crazy Kong FPGA – Architecture Overview

This document is an overview of the internal architecture of my Crazy Kong FPGA core for the DE2 + PS/2 keyboard project.  
I focus on **how the major blocks are connected** and what the key signals mean.

---

## 1. Top-Level Structure

In this project I mainly work with two “top” modules:

- `ckong_de2.vhd` (or similar):
  - DE2-specific wrapper
  - Connects FPGA pins (clock, VGA, SRAM, PS/2, audio, switches, LEDs) to the game core

- `ckong.vhd`:
  - The actual game core
  - Instantiates:
    - Z80 CPU (`T80s`)
    - Video system (`video_gen`, palettes, big sprite logic)
    - SRAM interface + loader (`ram_loader`)
    - Sound core (`ckong_sound`)
    - Keyboard/joystick logic (PS/2 + DE2 switches)
    - Line doubler (`line_doubler`) for VGA

### High-Level Block Diagram (Conceptual)

```text
           ┌────────────────────────┐
           │       ckong_de2        │
           │                        │
   36MHz ──► clock_36mhz            │
 PS/2 CLK ─► ps2_clk                │
 PS/2 DAT ─► ps2_dat                │
VGA out ◄──► video_r/g/b, hs, vs    │
SRAM bus◄──► sram_addr/data/we      │
 Audio  ◄──► sound_string           │
 Switches►─► sw_*                   │
           │                        │
           │    ┌─────────────┐     │
           │    │   ckong     │◄────┘
           │    └─────────────┘
           └────────────────────────┘
````

Inside `ckong`:

```text
      ┌─────────┐
      │ T80s    │  Z80 CPU
      └─────────┘
           │
           ▼
   ┌─────────────┐         ┌──────────────┐
   │  SRAM       │◄───────►│  ram_loader  │
   └─────────────┘         └──────────────┘
         ▲  ▲
         │  │
         │  └────────── video_gen / sprite / big sprite
         │
         └───────────── ckong_sound

PS/2 keyboard → ps2_keyboard/io_ps2_keyboard → key decode → joy_pcfrldu → player1/coins → CPU
```

---

## 2. Clocking

### Main Clocks

* **`clock_36mhz : in std_logic`**

  * Main input clock from the DE2 board (or PLL output).

* **`clock_12mhz : std_logic`**

  * Internal clock for most of the game logic (CPU + video).
  * I derive it from 36 MHz by dividing the clock by 3.

Original style logic:

```vhdl
signal div3_clk : unsigned(1 downto 0) := "00";

process(clock_36mhz)
begin
    if rising_edge(clock_36mhz) then
        if div3_clk = 2 then
            div3_clk    <= to_unsigned(0,2);
        else
            div3_clk    <= div3_clk + 1;
        end if;
        clock_12mhz <= div3_clk(0);
    end if;
end process;
```

* `div3_clk` increments at 36 MHz.
* It cycles 0 → 1 → 2 → 0, so `div3_clk(0)` toggles at 12 MHz (approx).
* `clock_12mhz` is used by:

  * `video_gen`
  * SRAM access state machine
  * Big sprite logic
  * Palettes
  * Z80 bus clock (`cpu_clock`, after additional logic)

---

## 3. CPU Core and Bus Interface

### Z80 Core: `T80s`

I instantiate the Z80-compatible core like this:

```vhdl
Z80 : entity work.T80s
generic map(Mode => 0, T2Write => 1, IOWait => 1)
port map(
  RESET_n => not loading,   -- hold CPU in reset while RAM is loading
  CLK_n   => cpu_clock,     -- usually derived from clock_12mhz
  WAIT_n  => '1',
  INT_n   => '1',           -- main maskable interrupt not used (NMI used instead)
  NMI_n   => cpu_int_n,     -- vertical blank NMI
  BUSRQ_n => '1',
  M1_n    => open,
  MREQ_n  => cpu_mreq_n,
  IORQ_n  => cpu_iorq_n,
  RD_n    => open,
  WR_n    => cpu_wr_n,
  RFSH_n  => open,
  HALT_n  => open,
  BUSAK_n => open,
  A       => cpu_addr,
  DI      => cpu_di,
  DO      => cpu_data
);
```

Key CPU signals in my design:

* **`cpu_addr : std_logic_vector(15 downto 0)`**
  Z80 address bus. I use it to select memory region: ROM, RAM, color RAM, I/O, etc.

* **`cpu_data : std_logic_vector(7 downto 0)`**
  CPU data output (writes).

* **`cpu_di   : std_logic_vector(7 downto 0)`**
  Data input to the CPU (reads).

* **`cpu_mreq_n`, `cpu_iorq_n`, `cpu_wr_n`**
  Standard Z80 control signals for memory and I/O cycles.

### Memory vs IO Reads

I multiplex the CPU’s `DI` input between memory and I/O devices:

```vhdl
with cpu_addr(15 downto 11) select 
    cpu_di_mem <=
        "00000000"       when "10110", -- dip switch
        player1          when "10100", -- player controls
        coins            when "10111", -- coin/start inputs
        sram_data_to_cpu when others;  -- everything else via external SRAM

cpu_di <= ym_8910_data when cpu_iorq_n = '0' else cpu_di_mem;
```

* When `cpu_iorq_n = '0'`, Z80 I/O reads come from the YM2149/AY-3-8910 sound chip.
* Otherwise, reads come from:

  * `player1` input port
  * `coins` port
  * `dips` (if implemented)
  * `sram_data_to_cpu` (main memory via SRAM)

### Scrambled Color RAM Addressing

Crazy Kong uses a **scrambled color RAM** mapping. I handle that via `cpu_addr_mod`:

```vhdl
with cpu_addr(15 downto 11) select
cpu_addr_mod <= "100110" & cpu_addr(10 downto 6) & cpu_addr(4 downto 0) when "10011",
                "100110" & cpu_addr(10 downto 6) & cpu_addr(4 downto 0) when "11011",
                cpu_addr when others;
```

* Addresses in certain ranges (e.g. `10011`, `11011`) are remapped for color RAM access.
* All SRAM accesses in the controller use `cpu_addr_mod` instead of `cpu_addr` directly.

---

## 4. SRAM Bus and Addressing State Machine

I use **external SRAM** both for program/data and graphics.
To share it between CPU and video logic, I time-multiplex the bus using a 4-bit **`addr_state`**.

### Global SRAM Interface

At the top level (`ckong.vhd`):

```vhdl
sram_addr : out   std_logic_vector(16 downto 0);
sram_we   : out   std_logic;
sram_data : inout std_logic_vector(7 downto 0);
```

Internal helper signals:

* **`load_addr, load_data, load_we, loading`**
  Driven by `ram_loader` while it fills the SRAM.

* **`sram_data_to_cpu`**
  Latched read data for CPU cycles.

### SRAM Control Process

The main SRAM controller looks roughly like this:

```vhdl
process(clock_12mhz)
begin
    if rising_edge(clock_12mhz) then
        sram_addr <= (others => '1');
        sram_we   <= '0';
        sram_data <= (others => 'Z');

        if loading = '1' then
            -- Loader owns the bus
            sram_addr <= load_addr;
            sram_we   <= load_we;
            sram_data <= load_data;

        else
            -- Normal game bus sharing, depending on addr_state
            if    addr_state = "0000" then
                -- X sprite
            elsif addr_state = "0001" then
                -- Y sprite
            elsif addr_state = "0010" then
                -- CPU access
            elsif addr_state = "0011" then
                -- tile-code fetch
            ...
            end if;
        end if;
    end if;
end process;
```

At each `addr_state`, I give the bus to:

* The CPU for memory read/write (`cpu_addr_mod`)
* Background tilemap fetch (tile codes & colors)
* Sprite attribute table (x/y/attributes)
* Tile graphics ROM (`tile_graph1`, `tile_graph2`)
* Big sprite tables & graphics

`addr_state` is generated by `video_gen` in sync with the scan, so that:

* Every scanline has the necessary tile and sprite data ready in time.
* CPU accesses are interleaved with video fetches.

---

## 5. Video Pipeline

The video system is built around tiles, sprites, and one big sprite.

### Key Video Signals

* **`x_tile, y_tile : std_logic_vector(4 downto 0)`**
  Tile coordinates on the screen.

* **`x_pixel, y_pixel : std_logic_vector(2 downto 0)`**
  Fine pixel coordinates inside each 8×8 tile.

* **`y_line : std_logic_vector(7 downto 0)`**
  I define `y_line` as `y_tile & y_pixel`.

* **`tile_code : std_logic_vector(12 downto 0)`**
  Selects the tile graphic:

  * lower 11 bits: tile index + row within tile
  * upper 2 bits: bank / attributes

* **`tile_graph1, tile_graph2 : std_logic_vector(7 downto 0)`**
  The two bitplanes of the tile data.

* **`tile_color : std_logic_vector(3 downto 0)`**
  Palette index.

* **`pixel_color, pixel_color_r : std_logic_vector(5 downto 0)`**
  Combined color index: `[palette bits][plane1 bit][plane2 bit]`.

#### Background / Sprite Tile Fetch

In the “sram reading background/sprite data” process:

* When `addr_state = "0100"`:

  * For sprites:

    ```vhdl
    if sram_data(7) = '1' then
      tile_code(10 downto 0) <= sram_data(5 downto 0) & not (y_add_sprite(3)) &
                                (x_tile(0) xor sram_data(6)) & not(y_add_sprite(2 downto 0));
    else
      tile_code(10 downto 0) <= sram_data(5 downto 0) &      y_add_sprite(3)  &
                                (x_tile(0) xor sram_data(6)) &     y_add_sprite(2 downto 0);
    end if;
    inv_sprite <= sram_data(7 downto 6);
    ```

  * For background:

    ```vhdl
    tile_code(10 downto 0) <= sram_data & y_pixel;
    ```

* When `addr_state = "0101"`:

  ```vhdl
  tile_code(12 downto 11) <= sram_data(4) & sram_data(5);
  tile_color              <= sram_data(3 downto 0);
  ```

* When `addr_state = "1000"` and `"1001"`:

  ```vhdl
  tile_graph1 <= sram_data;
  tile_graph2 <= sram_data;
  ```

#### Sprite Line Buffer

I use a small line buffer for sprite pixels:

```vhdl
type ram_256x6 is array(0 to 255) of std_logic_vector(5 downto 0);
signal ram_sprite : ram_256x6;
```

Two processes handle the address and data:

* **Addressing (`addr_ram_sprite`)**

  * On sprite tiles and at certain states, I set `addr_ram_sprite <= '0' & x_sprite`.
  * At the start of a background line: `addr_ram_sprite <= "000000001"`.
  * Otherwise, it auto-increments when `addr_state(0) = '1'`.

* **Read/write**

  * When `addr_state(0) = '0'`, I read from `ram_sprite` into `sprite_pixel_color`.
  * When `addr_state(0) = '1'` and sprite conditions are met (`keep_sprite`, position checks), I write `pixel_color_r` back into `ram_sprite`.

This gives me a **per-line compositing buffer** that merges background and sprites.

#### Pixel Serialization + Palette

Pixel serialization:

```vhdl
process (clock_12mhz)
begin
  if rising_edge(clock_12mhz) then
    pixel_color <= tile_color_r &
                   tile_graph1_r(to_integer(unsigned(not x_pixel))) &
                   tile_graph2_r(to_integer(unsigned(not x_pixel)));
  end if;
end process;
```

Sprite priority mux:

```vhdl
pixel_color_r <= pixel_color when sprite_pixel_color(1 downto 0) = "00"
                 else sprite_pixel_color;
```

Palette lookup:

```vhdl
palette : entity work.ckong_palette
port map (
    addr => pixel_color_r,
    clk  => clock_12mhz,
    data => do_palette 
);
```

Then I optionally override with the big sprite palette:

```vhdl
video_mux <= do_palette when is_big_sprite_on = '0' else do_big_sprite_palette;
```

---

## 6. Big Sprite Path

The big sprite (Kong, etc.) has a separate path.

Key signals:

* `x_big_sprite, y_big_sprite` : big sprite origin
* `y_add_big_sprite`           : `y_line + y_big_sprite`
* `big_sprite_color`           : color + flip bits
* `big_sprite_tile_code`       : tile index
* `big_sprite_graph1/2`        : graphics planes
* `x_big_sprite_counter`       : horizontal scanning

Tile address selection (`xy_big_sprite`) depends on flip bits:

```vhdl
with big_sprite_color(5 downto 4) select
xy_big_sprite <= y_add_big_sprite(6 downto 3)  & not(x_big_sprite_counter(7 downto 4)) when "00",
                 not(y_add_big_sprite(6 downto 3)) & not(x_big_sprite_counter(7 downto 4)) when "10",
                 y_add_big_sprite(6 downto 3)  & x_big_sprite_counter(7 downto 4) when "01",
                 not(y_add_big_sprite(6 downto 3)) & x_big_sprite_counter(7 downto 4) when others;
```

Final big sprite pixel index:

```vhdl
big_sprite_pixel_color <= big_sprite_color(2 downto 0) & 
                          big_sprite_graph1_r2(to_integer(unsigned(x_big_sprite_counter(3 downto 1)))) &
                          big_sprite_graph2_r2(to_integer(unsigned(x_big_sprite_counter(3 downto 1))));
```

Visibility window:

```vhdl
if  big_sprite_pixel_color(1 downto 0) /= "00" and y_add_big_sprite(7) = '1' and 
    x_big_sprite_counter >= (X"28" & '0') and 
    x_big_sprite_counter <  (X"A8" & '1') then
    is_big_sprite_on <= '1';
else
    is_big_sprite_on <= '0';
end if;
```

---

## 7. Interrupts / Frame Sync

The game uses a **non-maskable interrupt (NMI)** tied to a specific scanline:

```vhdl
process(clock_12mhz, raz_int_n)
begin
    if raz_int_n = '0' then
        cpu_int_n <= '1';
    else
        if rising_edge(clock_12mhz) then
            if y_tile = "11100" and y_pixel = "000" then
                cpu_int_n <= '0';
            end if;
        end if;
    end if;
end process;
```

* `y_tile = "11100"` & `y_pixel = "000"` correspond to a line near the bottom of the screen.
* The CPU can clear `raz_int_n` by writing to an I/O register (via `reg4_we_n` and `cpu_data(0)`).

---

## 8. Sound System

The sound core `ckong_sound` connects to the CPU I/O and produces audio samples:

```vhdl
ckong_sound : entity work.ckong_sound
port map(
  cpu_clock    => cpu_clock,
  cpu_addr     => cpu_addr,
  cpu_data     => cpu_data,
  cpu_iorq_n   => cpu_iorq_n,
  reg4_we_n    => reg4_we_n,
  reg5_we_n    => reg5_we_n,
  reg6_we_n    => reg6_we_n,
  ym_2149_data => ym_8910_data,
  sound_sample => sound_string
);
```

* The CPU writes sound registers via `reg4_we_n`, `reg5_we_n`, `reg6_we_n`.
* Internally, this updates AY-3-8910 / YM2149 registers to generate the actual audio.
* `sound_string` is a digital sample stream, which I route to the DE2’s audio output.

---

## 9. PS/2 Keyboard & Controls

I support arcade-style inputs using a PS/2 keyboard and/or the DE2 switches.

### 9.1 Original Keyboard Path

The original fork uses:

```vhdl
kdb : entity work.io_ps2_keyboard
port map (
  clk       => clock_36mhz,
  kbd_clk   => ps2_clk,
  kbd_dat   => ps2_dat,
  interrupt => kbd_int,
  scanCode  => kbd_scan_code
);

joystick : entity work.kbd_joystick
port map (
  clk           => clock_36mhz,
  kbd_int       => kbd_int,
  kbd_scan_code => std_logic_vector(kbd_scan_code),
  joy_pcfrldu   => joy_pcfrldu
);
```

* `io_ps2_keyboard` decodes the PS/2 protocol to `kbd_int` (strobe) + `scanCode` (8 bits).
* `kbd_joystick` maps specific scan codes to `joy_pcfrldu` bits (UP, DOWN, LEFT, RIGHT, FIRE, START, COIN).

### 9.2 Integrated Keyboard Logic

In my modified versions, I sometimes inline this logic directly instead of using `kbd_joystick`. The idea is always the same:

* Treat PS/2 make/break codes.
* Maintain a set of “virtual joystick” bits in `joy_pcfrldu`.
* Map those bits into `player1` and `coins`.

Final mapping to CPU-visible ports:

```vhdl
player1 <= ( joy_pcfrldu(3) & joy_pcfrldu(2) &
             joy_pcfrldu(1) & joy_pcfrldu(0) &
             joy_pcfrldu(4) & "000" );

coins   <= not( "00000" & joy_pcfrldu(5) & joy_pcfrldu(6) & '0');
```

Where:

* `joy_pcfrldu(0)` : UP
* `joy_pcfrldu(1)` : DOWN
* `joy_pcfrldu(2)` : LEFT
* `joy_pcfrldu(3)` : RIGHT
* `joy_pcfrldu(4)` : JUMP/FIRE
* `joy_pcfrldu(5)` : START
* `joy_pcfrldu(6)` : COIN

The internal convention is:

* `joy_pcfrldu` is **active-high** (1 = pressed),
* `coins` is built as an **active-low** port using `not(...)`.

I keep reset values and PS/2 logic consistent with this convention.

---

## 10. RAM Loader

`ram_loader` is responsible for filling the external SRAM with the ROM image at startup:

```vhdl
ram_loader : entity work.ram_loader
port map(
  clock    => clock_12mhz,
  reset    => reset,
  address  => load_addr,
  data     => load_data,
  we       => load_we,
  loading  => loading
);
```

* While `loading = '1'`:

  * The SRAM controller uses `load_addr`, `load_data`, `load_we`.
  * The CPU is held in reset (`RESET_n => not loading`).

* When `loading` goes to `'0'`:

  * The SRAM bus is handed over to the CPU + video logic.
  * The Z80 starts executing code from ROM in external SRAM.

The ROM layout in SRAM (code, tiles, sprites, color data, etc.) follows the original Crazy Kong hardware mapping, adapted to my loader.

---

## 11. Line Doubler

The original arcade video is 15 kHz. I use a `line_doubler` to generate a VGA-friendly 31 kHz output:

```vhdl
line_doubler : entity work.line_doubler
port map(
  clock_12mhz => clock_12mhz,
  video_i     => video_i,
  hsync_i     => hsync,
  vsync_i     => vsync,
  video_o     => video_o,
  hsync_o     => hsync_o,
  vsync_o     => vsync_o
);
```

* Input: 8-bit `video_i` + original `hsync` / `vsync`.
* Output: `video_o` + `hsync_o` / `vsync_o` for VGA.

At the very end, I select either original 15 kHz or doubled VGA via `tv15Khz_mode`:

```vhdl
video_r   <= video_o(2 downto 0) when tv15Khz_mode = '0' else video_i(2 downto 0);
video_g   <= video_o(5 downto 3) when tv15Khz_mode = '0' else video_i(5 downto 3);
video_b   <= video_o(7 downto 6) when tv15Khz_mode = '0' else video_i(7 downto 6);
video_clk <= clock_12mhz;
```

So the core can drive either a 15 kHz display (arcade monitor / SCART) or standard VGA (via the doubler).

---

## 12. Per-Frame Flow (Summary)

A rough high-level overview of one frame in my design:

1. **Reset / boot**

   * `ram_loader` writes ROM into external SRAM.
   * `loading = '1'` keeps the CPU in reset.

2. **After loading**

   * `loading` goes low.
   * Z80 starts running from ROM.
   * Video system begins scanning tiles and sprites.

3. **Each 12 MHz cycle**

   * `video_gen` updates `addr_state`, `x_tile`, `y_tile`, `x_pixel`, `y_pixel`.
   * SRAM controller fetches tile/sprite data at the right times.
   * CPU memory cycles are interleaved with video SRAM accesses.

4. **Each scanline**

   * Background pixels are generated from tile codes and graphics.
   * Sprites are merged via the line buffer.
   * Big sprite is composed and overlayed if active.
   * Palette turns pixel indices into 8-bit RGB.
   * Optionally, the `line_doubler` outputs a VGA-friendly picture.

5. **Once per frame / at a specific scanline**

   * `cpu_int_n` is pulsed low (NMI).
   * The CPU NMI handler runs (game logic, timers, etc.).

6. **Input handling**

   * PS/2 keyboard module emits new scan codes.
   * Keyboard/joystick logic updates `joy_pcfrldu`.
   * CPU reads `player1` and `coins` through memory-mapped inputs.

This is the overall structure I use to recreate the Crazy Kong hardware behavior on the DE2 FPGA with PS/2 keyboard controls.

```
::contentReference[oaicite:0]{index=0}
```
