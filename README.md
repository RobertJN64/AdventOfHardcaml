# Advent of Hardcaml

Hardcaml solutions for Advent of Code 2025, targeted for an iCE40 FPGA.

## Usage

### Simulation Only

Requires: ocaml, dune, and hardcaml

```TODO - this```

### Flashing to FPGA

Requires: python, apio

Setup a python virtual enviroment and install apio with `pip install --force-reinstall -U git+https://github.com/fpgawars/apio.git@main`. apio provides the open source toolchain needed to build and flash the verilog code.

Note: if using WSL, pass through the device using `usbipd attach --wsl --busid=`. This needs to be re-run after each device re-connection.

Flashing:
```cmd
cd verilog_build
apio drivers install ftdi
apio upload
```

