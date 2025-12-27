# Advent of Hardcaml

Hardcaml solutions for Advent of Code 2025, targeted for an iCE40 FPGA.

Solutions:
 - DayXX Part 1 and Part 2

## Setup

```
opam switch 4.14.1
eval $(opam env)
opam install hardcaml.v0.16.0
opam install hardcaml_waveterm
```

## Files

### Common Modules
Standardized modules that are not day-specific.

### Days/Day01a
Each day folder contains the code for the corresponding day, with Day01a indicating Dec 1st, Part 1 and Day01b indicating Dec 1st, Part 2.

Inside the folder is the solution circuit ([Day01a.ml](Days/Day01a/Day01a.ml)), the Hardcaml testbench ([Day01a_tb.ml](Days/Day01a/Day01a_tb.ml)), and a verilog generator file ([Day01a_v.ml](Days/Day01a/Day01a_v.ml)).

## Usage

### Simulation

Requires: ocaml, dune, and hardcaml

Run `dune build` and `dune exec ./Days/Day01a/Day01a_tb.exe` replacing the day number as needed. This will run the Cyclesim testbench.

### Flashing to FPGA

Requires: python, apio

Setup a python virtual enviroment and install apio with `pip install --force-reinstall -U git+https://github.com/fpgawars/apio.git@main`. apio provides the open source toolchain needed to build and flash the verilog code.

Note: if using WSL, pass through the device using `usbipd attach --wsl --busid=`. This needs to be re-run after each device re-connection.

Run `dune build` and `dune exec ./Days/Day01a/Day01a_v.exe` replacing the day number as needed. This will generate the `top.v` file needed inside the `verilog_build` folder.

Flashing:
```cmd
cd verilog_build
apio drivers install ftdi
apio upload
```

