## OUP: an open source USB core for FPGAs

A work in progress USB device core for FPGAs, using the Wishbone bus and an ULPI physical link.
Currently the API is subject to changes.

Developed on the Terasic DE-10-Lite development board, that uses an Intel MAX-10 FPGA. My goal is to make this platform independent.

To initialize and use the repo, run the commands below on an Ubuntu Linux command line (you can use WSL on Windows).
```
sudo apt-get install make git lua5.1
git clone https://github.com/IvanVeloz/oup
# (or substitute the URL if you're not getting this from my GitHub repo)
cd oup
git submodule update --init --recursive
# (note this downloads and stores about 7GB due to the RISCV toolchain)
cd dependencies/oup-wishbone
make
```
Note that `git submodule update --init --recursive` pulls about 7GB of files from the RISC-V GNU toolchain. If you already have this, you can instead initialize the other submodules individually.

After this, on Linux or Windows, create a new Quartus Prime project from the `oup.tcl` script as follows:
1. Open Quartus Prime (don't create or open a project).
2. Locate the TCL console.
3. Navigate to the `quartus` directory by typing `cd path/to/oup/quartus`.
4. Create the project by typing `source oup.tcl`. This will execute the `oup.tcl` script.
    * At this point Quartus may complain about you not having Cyclone V support installed, and will ask you if you want to remove the current assignemts. Select "No".
5. Open the project you just created by clicking File > Open Project.
