Crazy Kong Arcade for the Altera DE2-35 Dev Board.

Notes:
Setup for 1 player arcade controls (7 switches) (coin-start-up-down-left-right-jump).
Each switch is connected one side to DE2 I/O Pin and other side to DE2-Gnd pin (pin12 on GPIO(0)Pin Header).
Otherwise you can just hookup a PS2 interface keyboard and use the ps2_keyboard.vhd interface instead
Pin Header locations are specified in the "ckong_de2.qsf" File.

Build:
* Obtain correct roms file for crazy kong "ckongpt2.zip", see script in tools folder for rom filenames.
* Unzip rom files to ckong_unzip folder inside the tools folder.
* Run the make ckong proms script in the tools folder.
* Open the ckong_de2 project file using Quartus and compile.
* Program DE2 Board.
