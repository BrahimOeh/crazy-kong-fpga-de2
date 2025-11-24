---
# Crazy Kong Altera DE2 FPGA Implementation
![license](https://img.shields.io/badge/license-MIT-purple)
[![GitHub Repo](https://img.shields.io/badge/GitHub-Repo-181717?style=flat&logo=github&logoColor=white)](https://github.com/BrahimOeh?tab=repositories)
[![Intel](https://img.shields.io/badge/Altera_DE2_FPGA-Intel-blue?style=flat&logo=intel&logoColor=white&logoSize=auto)](https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&CategoryNo=53&No=30&PartNo=1#contents)
[![LinkedIn](https://custom-icon-badges.demolab.com/badge/LinkedIn-0A66C2?logo=linkedin-white&logoColor=fff)](https://www.linkedin.com/in/brahimoeh) 
[![Nintendo eShop](https://custom-icon-badges.demolab.com/badge/Arcade%20Donkey%20Kong-FF7D00?logo=nintendo&logoColor=fff)](https://www.youtube.com/watch?v=KJkcNP4VkiM)
[![VHDL](https://img.shields.io/badge/VHDL-5D87BF?logo=v&logoColor=fff)](#)

![DK1981](docs/Donkey_Kong_1981.svg)


This project is an FPGA implementation of the **Crazy Kong** arcade game (Falcon hardware), targeting the **Altera/Intel DE2** development board.

It’s based on an original VHDL core (Z80 + SRAM-based ROMs), with the following additions and tweaks:

* ✅ Ported to the **DE2 board**
* ✅ **VGA Timing** & Graphics implementation
* ✅ **Sound Decoding** and DAC Modules
* ✅ **PS/2 keyboard controls** (arrows / jump / start / coin)
* ✅ Optional **board switches** as backup controls
* ✅ **VGA output** via line doubler (or 15kHz RGB if desired)
* ✅ On-board **LED debug** for PS/2 scan codes

> ⚠️ **ROMs** for Crazy Kong are copyrighted. This repo only contains the FPGA logic and loader. You are responsible for legally obtaining and converting your own ROMs.
---
## 📘 Table of Contents
- [DEMO](#-demo-)
- [1. Hardware Requirements](#1-hardware-requirements)
- [2. Project Overview](#2-project-overview)
- [3. File / Module Overview](#3-file--module-overview)
  - [Top-level](#top-level)
  - [CPU / Sound](#cpu--sound)
  - [Video](#video)
  - [Memory / ROM Handling](#memory--rom-handling)
  - [Input / Keyboard](#input--keyboard)
- [4. Controls](#4-controls)
  - [4.1 Keyboard](#41-keyboard-current-mapping)
  - [4.2 DE2 Switches / Buttons](#42-de2-switches--buttons-original-style)
- [5. Building the Project](#5-building-the-project)
  - [5.1 Toolchain](#51-toolchain)
  - [5.2 Steps](#52-steps)
- [6. Running the Game](#6-running-the-game)
- [7. Customizing Controls](#7-customizing-controls)
- [8. Troubleshooting](#8-troubleshooting)
- [9. Credits & License](#9-credits)
- [10. License](#10-license)

---
# → DEMO :

![Video](docs/Brahim_Kong4K.mp4)

Implementation Demo video with VGA Graphics, Speakers, And PS2 Keyboard; And a Professional Gameplay of the game by the man the myth the legend himself (me)

## 1. Hardware Requirements

* **Board:** Altera/Intel **DE2** (Cyclone II)
* **Display:**

  * VGA monitor (via line_doubler), or
  * 15 kHz RGB monitor/TV (arcade-style) if you wire it
* **Controls:**

  * PS/2 keyboard connected to the DE2 PS/2 port
  * Optional: DE2 switches / keys as extra inputs (depending on how you wire them)
* **Audio:** Speakers / headphones connected to the DE2 audio output
* **Power & USB-Blaster:** For programming the FPGA

---

## 2. Project Overview

At a high level, the design does this:

* Generates the **main clocks** (36 MHz input → 12 MHz game clock).
* Implements a **Z80-compatible CPU core** (`T80s`).
* Uses external **SRAM** to hold program ROM, graphics, and color tables.
* Implements the **Falcon video pipeline**:

  * Tile/sprite system (`video_gen`)
  * Big sprite logic
  * Palette lookup (`ckong_palette`, `ckong_big_sprite_palette`)
  * Optional line doubler (`line_doubler`) to generate VGA-friendly timings
* Implements the **sound subsystem** (`ckong_sound`), using a YM2149/AY-3-8910 compatible block.
* Adds a **PS/2 keyboard interface** to control the player instead of a hard-wired joystick *( the game was originally developed for Arcade's and the Atari 2600 )*.

---

## 3. File / Module Overview


### Top-level

* **`ckong_de2.vhd`** (DE2 top module):

  * Board-specific top-level.
  * Instantiates the core (`ckong`) and maps it to:

    * 36 MHz clock (from PLL or DE2 oscillator)
    * PS/2 pins, VGA pins, SRAM, audio, LEDs, switches, etc.

* **`ckong.vhd`**

  * Main game core top-level:

    * Clock division: 36 MHz → 12 MHz (`clock_12mhz`, `div3_clk`)
    * Video pipeline connections
    * Z80 + memory bus + SRAM arbitration
    * Player inputs (`player1`, `coins`)
    * PS/2 keyboard→game control logic (through `joy_pcfrldu` and/or `ssw_*`)

### CPU / Sound

* **`T80s.vhd`**

  * Z80-compatible soft-core CPU.
  * Drives the address, data, and control lines used to fetch instructions & access RAM.

* **`ckong_sound.vhd`**

  * Handles the Z80 I/O writes related to sound.
  * Implements interface to an AY-3-8910/YM2149 style sound generator.
  * Outputs a `sound_string` / mixed audio sample.

### Video

* **`video_gen.vhd`**

  * Video timing generator:

    * Generates `hsync`, `vsync`, `csync`, `blank`.
    * Generates tile/sprite addressing state (`addr_state`, `x_tile`, `y_tile`, `x_pixel`, `y_pixel`, etc.).
  * Drives the background/sprite pipeline in `ckong.vhd`.

* **`line_doubler.vhd`**

  * Converts original 15 kHz arcade timings into VGA-like 31 kHz.
  * Takes `video_i` (8-bit color) + `hsync`, `vsync` and produces `video_o`, `hsync_o`, `vsync_o`.

* **`ckong_palette.vhd`**

  * Palette ROM lookup for normal tiles/sprites.
  * Maps a 6-bit color index (`pixel_color_r`) → 8-bit RGB value (`do_palette`).

* **`ckong_big_sprite_palette.vhd`**

  * Separate palette for big sprite graphics.
  * Maps 5-bit big sprite color (`big_sprite_pixel_color`) → 8-bit RGB value (`do_big_sprite_palette`).

### Memory / ROM Handling

* **`ram_loader.vhd`**

  * Handles loading external ROM content into SRAM at power-up/reset.
  * Drives `load_addr`, `load_data`, `load_we`, and `loading` signals.
    * `loading = '1'` → loader owns the SRAM bus;
    * `loading = '0'` → CPU + video own it.

* **External SRAM interface** (inside `ckong.vhd`):

  * Time-multiplexes:

    * CPU access (program + work RAM, tilemap, colors…)
    * Video access (tile/sprite/big sprite graphics)
    * Loader access at startup

### Input / Keyboard

Depending on which version you like to use:

* **`io_ps2_keyboard.vhd`**  _<small>Copyright 2005-2008 by Peter Wendrich (pwsoft@syntiac.com)</small>_
  * PS/2 protocol decoder.
  * Outputs:

    * `interrupt` pulse when a byte is ready
    * `scanCode` = 8-bit raw PS/2 scan code

* **`ps2_keyboard.vhd`** (my custom module <small>which subsequently is the one that ended up working</small>
)

  * PS/2 decoder + LED output for debugging.
  * Outputs:

    * `ps2_code_new` → goes into `kbd_int`
    * `ps2_code` → goes into `kbd_scan_code`
    * `LED` → shows last code on the board’s LEDs

* **`kbd_joystick.vhd`** (simple joystick adapter through the DE2 board's GPIO extension pins)

  * Takes `kbd_int`, `kbd_scan_code`
  * Decodes specific keys into `joy_pcfrldu(6 downto 0)`:

    * bit 0: UP
    * bit 1: DOWN
    * bit 2: LEFT
    * bit 3: RIGHT
    * bit 4: FIRE/JUMP
    * bit 5: START
    * bit 6: COIN


---

## 4. Controls
<h1 style="text-align:center;">There's Two Main Schemes (Keybord || Switches)</h1>


### 4.1 Keyboard (current mapping)

Using the custom `ps2_keyboard` module and the “release-aware” logic ( so the logic isn't stuck on the last button input ):

* **Arrows**←↨→: Move the player
  * Up    → `joy_pcfrldu(0)`
  * Down  → `joy_pcfrldu(1)`
  * Left  → `joy_pcfrldu(2)`
  * Right → `joy_pcfrldu(3)`
* **Space**: Jump (`joy_pcfrldu(4)`)
* **Start**:

  *  `F1` (you can change the button by putting the appropriate scan code) → `joy_pcfrldu(5)`
* **Coin**:

  * `F2` (you can change the button by putting the appropriate scan code) → `joy_pcfrldu(6)`

Internally, the logic looks like this style (simplified):

```vhdl
if kbd_int = '1' then
  if kbd_scan_code = x"F0" then
    is_released <= '1';
  else
    if is_released = '1' then
      -- key release → set bit back to '0' or '1' depending on active level
    else
      -- key press → set corresponding joy_pcfrldu bit
    end if;
  end if;
end if;
```

### 4.2 DE2 Switches / Buttons (original style)

The original design can also drive `joy_pcfrldu` from on-board inputs:

```vhdl
if sw_coin  = '0' then joy_pcfrldu(6) <= '1'; else joy_pcfrldu(6) <= '0'; end if;
if sw_start = '0' then joy_pcfrldu(5) <= '1'; else joy_pcfrldu(5) <= '0'; end if;
if sw_jump  = '0' then joy_pcfrldu(4) <= '1'; else joy_pcfrldu(4) <= '0'; end if;
if sw_right = '0' then joy_pcfrldu(3) <= '1'; else joy_pcfrldu(3) <= '0'; end if;
if sw_left  = '0' then joy_pcfrldu(2) <= '1'; else joy_pcfrldu(2) <= '0'; end if;
if sw_down  = '0' then joy_pcfrldu(1) <= '1'; else joy_pcfrldu(1) <= '0'; end if;
if sw_up    = '0' then joy_pcfrldu(0) <= '1'; else joy_pcfrldu(0) <= '0'; end if;
```

The **final game input bus** is then built as:

```vhdl
player1 <= ( joy_pcfrldu(3) & joy_pcfrldu(2) & joy_pcfrldu(1) & joy_pcfrldu(0) & joy_pcfrldu(4) & "000" );
coins   <= not( "00000" & joy_pcfrldu(5) & joy_pcfrldu(6) & '0');
```

> Note: `coins` is **active-low inverted**, following the original hardware’s dip-switch style.

---

## 5. Building the Project

### 5.1 Toolchain

* **Quartus II** (version matching the DE2 board support — e.g. Quartus II 13.x Web Edition)
* **Modelsim** (optional) if you want HDL simulation

### 5.2 Steps

1. **Clone the repo**

   ```bash
   git clone https://github.com/---/---.git
   cd ---
   ```

2. **Open the Quartus project**

   * Open `.qpf` / `.qsf` in Quartus.
   * Ensure the **top-level entity** is set to your DE2-specific top (`ckong_de2` or whatever you choose to named it).

3. **Assign pins (if not already in .qsf)**
   Make sure these are mapped correctly for the DE2:

   * Clocks: 50 MHz / PLL outputs → `clock_36mhz`
   * PS/2: `ps2_clk`, `ps2_dat`
   * VGA: `video_r`, `video_g`, `video_b`, `video_hs`, `video_vs`
   * SRAM: `sram_addr`, `sram_data`, `sram_we`
   * Switches/Keys (if used instead of keyboard)
   * LEDs: `LEDckong` (optional debug)

4. **Add ROM/loader files**

   * Ensure `ram_loader.vhd` and any ROM initialization files (MIF/HEX) are in the project.
   * Verify that `ram_loader` is instantiated in `ckong.vhd` and that the internal loader mode is selected (i.e. the lines using external loader are commented).
   * follow the steps in the following text file `tools\README` to load the game ROM's

5. **Compile**

   * Run **Full Compilation** in Quartus.
   * Fix any pin/constraint warnings as needed.

6. **Program the FPGA**

   * Use the Quartus **Programmer**.
   * Select the `.sof` file.
   * Program via USB-Blaster.

---

## 6. Running the Game

1. **Power on** the DE2 with the bitstream programmed ( JTAG/AS switch being on the position High ).

2. Connect:

   * VGA monitor to the VGA connector.
   * PS/2 keyboard to the PS/2 port.
   * Audio out to speakers (optional).

3. On reset, the **RAM loader** (`ram_loader`) will fill the external SRAM with ROM data.

   * During this time, `loading = '1'` and the Z80 core is held in reset.
   * Once loading finishes, the game starts executing.

4. Insert coins:

   * Use the mapped **Coin key** (e.g. `F2` ) on the keyboard.

5. Start:

   * Use the mapped **Start key** (e.g. `F1` ).

6. Play:

   * Move with **arrow keys**.
   * Jump with **Space**.

---

## 7. Customizing Controls

You can easily change which keyboard scan codes map to actions by editing the keyboard process in `ckong.vhd`, e.g.:

for QWERTY PS2 scan codes consult 
<span style="color: red; font-size: 1em; font-weight: bold;">Scan Code Set 1</span> : https://wiki.osdev.org/PS/2_Keyboard

for AZERTY PS2 scan codes consult 
<span style="color: blue; font-size: 1em; font-weight: bold;">Scan Code Set 2</span> : https://wiki.osdev.org/PS/2_Keyboard
```vhdl
-- Handle keyboard inputs for movement
        if kbd_int = '1' then
            -- Break Code Handling (F0 is the break code indicating key release)
            if kbd_scan_code = "11110000" then
                is_released <= '1';  -- Mark the key as released
            else
                is_released <= '0';  -- Key pressed
            end if;

            -- Handle specific key presses and releases (same mapping for UP, DOWN, LEFT, RIGHT, JUMP, START, COIN)
            if kbd_scan_code = "01110101" then 
                joy_pcfrldu(0) <= not(is_released);  -- UP
            end if;
            
            if kbd_scan_code = "01110010" then 
                joy_pcfrldu(1) <= not(is_released);  -- DOWN
            end if;
            
            if kbd_scan_code = "01101011" then 
                joy_pcfrldu(2) <= not(is_released);  -- LEFT
            end if;
            
            if kbd_scan_code = "01110100" then 
                joy_pcfrldu(3) <= not(is_released);  -- RIGHT
            end if;
            
            if kbd_scan_code = "00101001" then 
                joy_pcfrldu(4) <= not(is_released);  -- JUMP
            end if;
            
            if kbd_scan_code = "00000101" then 
                joy_pcfrldu(5) <= not(is_released);  -- START
            end if;
            
            if kbd_scan_code = "00000110" then 
                joy_pcfrldu(6) <= not(is_released);  -- COIN
            end if;
        end if;
```

You can also combine **switch + keyboard** by OR-ing their contributions into `joy_pcfrldu`.

---

## 8. Troubleshooting

Some common issues and hints:

### No reaction to keyboard

* Check that:

  * `ps2_keyboard` or `io_ps2_keyboard` is instantiated and wired to:

    * `ps2_clk`, `ps2_dat`, and
    * `kbd_int`, `kbd_scan_code`.
  * `kbd_int` actually toggles when you press a key:

    * Use `LEDckong` to visualize `kbd_scan_code`.
  * Your **scan codes** match the actual keyboard output (some keyboards output set 2 codes; check in simulation or by logging `LEDckong`).

### Player moves constantly in one direction

* Likely one `joy_pcfrldu` bit is stuck at `'1'` (active).
* Check the **release handling**:

  * After receiving `F0`, the next scan code must reset the correct bit back to `'0'` (or `'1'` depending on your active polarity).
* Verify no leftover processes are also driving `joy_pcfrldu`.

### Coin / Start not working

* Confirm:

  * The bits `joy_pcfrldu(5)` and `joy_pcfrldu(6)` are toggling.
  * `coins` is generated the same way as original:

    ```vhdl
    coins <= not( "00000" & joy_pcfrldu(5) & joy_pcfrldu(6) & '0');
    ```
  * The keyboard process and/or switches actually change `joy_pcfrldu(5)`/`(6)`.

---

## 9. Credits

* Original Crazy Kong FPGA core and Falcon hardware reverse-engineering by **Dar** (Feb 2014) and possibly other contributors.
* Z80 core: **T80s** by Daniel Wallner (and/or associated authors).
* This DE2 + VGA Timing + Sound Decoding + PS/2 keyboard adaptation by **OUELD EL HAIRECH BRAHIM**.
---
## 10. 📜 License
+ This project is open-source under the MIT License. See the LICENSE file for details.
  + and respect due to the licenses of any third-party cores i used.

> ⚠️ Again: The arcade ROM data is **not** included and must be obtained legally by the user.

---

