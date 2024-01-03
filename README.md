## OUP: an open source USB core for FPGAs

A work in progress USB device core for FPGAs, using the Wishbone bus and an ULPI physical link.
Currently the API is subject to changes.

Developed on the Terasic DE-10-Lite development board, that uses an Intel MAX-10 FPGA. My goal is to make this platform independent.

To initialize and use the repo, do the following on an Ubuntu Linux command line (you can use WSL on Windows):
```
sudo apt-get install make git lua5.1
git clone https://github.com/IvanVeloz/oup-wishbone
# (or substitute the URL if you're not getting this from my GitHub repo)
cd oup-wishbone
git submodule update --init --recursive
cd dependencies/oup-wishbone
make
```

Then on Linux or Windows, create a new Quartus Prime project from a TCL file as follows:
1. Open Quartus Prime (don't create or open a project).
2. Locate the TCL console.
3. Navigate to the `quartus` directory by typing `cd path/to/oup/quartus`.
4. Create the project by typing `source oup.tcl`. This will execute the `oup.tcl` script.
5. Open the project you just created by clicking File > Open Project.