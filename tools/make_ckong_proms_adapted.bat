
copy /B ckong_unzip\7.5d + ckong_unzip\8.5e + ckong_unzip\9.5h + ckong_unzip\10.5k + ckong_unzip\11.5l + ckong_unzip\12.5n prog.bin

copy /B gap_8192.bin + gap_8192.bin + gap_8192.bin + gap_8192.bin + gap_8192.bin gap_49152.bin

copy /B ckong_unzip\prom.v6 + ckong_unzip\prom.u6 ckong_palette.bin

copy /B ckong_unzip\6.11n + ckong_unzip\5.11l ckong_tile0.bin
copy /B ckong_unzip\4.11k + ckong_unzip\3.11h ckong_tile1.bin

copy /B ckong_unzip\2.11c + ckong_unzip\1.11a ckong_big_sprite_tiles.bin

copy /B ckong_unzip\13.5p + ckong_unzip\14.5s ckong_samples.bin

copy /B prog.bin + gap_49152.bin + ckong_tile0.bin + ckong_tile1.bin + ckong_big_sprite_tiles.bin ckong_sram_8bits.bin

duplicate_byte.exe ckong_sram_8bits.bin ckong_sram_16bits.bin

make_vhdl_prom prog.bin ckong_program.vhd
make_vhdl_prom ckong_tile0.bin ckong_tile_bit0.vhd
make_vhdl_prom ckong_tile1.bin ckong_tile_bit1.vhd
make_vhdl_prom ckong_unzip\2.11c ckong_big_sprite_tile_bit0.vhd
make_vhdl_prom ckong_unzip\1.11a ckong_big_sprite_tile_bit1.vhd
make_vhdl_prom ckong_palette.bin ckong_palette.vhd
make_vhdl_prom ckong_unzip\prom.t6 ckong_big_sprite_palette.vhd
make_vhdl_prom ckong_samples.bin ckong_samples.vhd

del prog.bin gap_49152.bin ckong_palette.bin ckong_tile0.bin ckong_tile1.bin ckong_big_sprite_tiles.bin ckong_samples.bin




