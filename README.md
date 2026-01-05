# Advent of Hardcaml

Hardcaml solutions for Advent of Code 2025, targeted for an iCE40 FPGA (the  [nandland-go-board](https://nandland.com/the-go-board/)).
Each solution receives the input text over UART and scrolls the answer across seven segment displays.

## Solution Progress:

| Day | Sim (Part 1) | FPGA (Part 1) | Sim (Part 2) | FPGA (Part 2) |
| --- | ------------ | ------------- | ------------ | ------------- |
| 01  | ✅          | ✅            | ✅          | ✅            |
| 02  |              |               |              |               |
| 03  | ✅          | ✅            | ✅          | ❌ [^1]       |
| 04  | ✅          | ❌ [^1]       | ✅          | ❌ [^1]       |
| 05  | ✅          | ❌ [^1]       |              |               |
| 06  |              |               |              |               |
| 07  | ✅          | ❌ [^1]       | ✅          | ❌ [^1]       |
| 08  |              |               |              |               |
| 09  | ✅          | ❌ [^1]       |              |               |
| 10  |              |               |              |               |
| 11  | ✅          | ❌ [^1]       | ✅          | ❌ [^1]       |
| 12  |              |               | NA           | NA            |

1: Not possible on ice40 due to register size / number of registers needed
[^1]: Not possible on ice40 due to register size / number of registers needed

Note: due to simulation performance limitations, Days 4 and 7 were only tested against a smaller grid.
All other days were tested against the full input, although only subset/sample is included in this repository per AoC rules.

## Setup

```
opam switch 5.3.0
eval $(opam env)
opam install hardcaml.v0.17.1
opam install hardcaml_waveterm
opam install ppx_hardcaml
```

For development: 
```
opam install ocaml-lsp-server ocamlformat
```

## Usage

### Simulation

Requires: ocaml, dune, and hardcaml

Run `dune build` and `dune exec ./Days/Day01a/Day01a_tb.exe` replacing the day number as needed. This will run the Cyclesim testbench. `01a` refers to Day1 part 1, use `01b` to refer to Day1 part 2.

The testbench simulates the actual UART input character by character and checks the answer by reading the internal "answer" register. A sample input is provided and the answer is checked against the correct answer with an assert at the end of the testbench.

To simulate larger inputs, increasing the serial "baud rate" is useful. Change 217 in [SerialTB.ml](common_modules/SerialTB.ml) and [UART_Decoder.ml](common_modules/UART_Decoder.ml) to 10. Sometimes, properties of the input (such as the expected number of characters in a line) are hardcoded into the design. This is noted in the design details below.

Note: inputs are typically required to use `\n` only as a line ending and to end with a `\n` at the end of the file.

The testbenches also dump a waves.vcd file which can be inspected to debug the design.

Note: per-AOC rules, complete puzzle inputs are not included in this repository. Instead, subset of inputs or the sample input in the puzzle description are used instead.

### Flashing to FPGA

Requires: python, apio

Setup a python virtual enviroment and install apio with `pip install --force-reinstall -U git+https://github.com/fpgawars/apio.git@main`. apio provides the open source toolchain needed to build and flash the verilog code.

Note: if using WSL, pass through the device using `usbipd attach --wsl --busid=`. This needs to be re-run after each device re-connection.

Run `dune build` and `dune exec ./Days/Day01a/Day01a_v.exe` replacing the day number as needed. This will generate the `top.v` file needed inside the `verilog_build` folder.

Flashing:
```cmd
cd verilog_build
apio drivers install ftdi // once
apio upload
```

#### Testing:

The FPGA must be reset by pushing the SW1 button.
The input can then be sent over UART at 115200 baud using pyserial or similar.

```python
import serial

with open('tb_input.txt') as f:
    data = f.read()

com = serial.Serial('COM6', baudrate='115200')
com.write(data.encode('utf-8'))
com.close()
```

Note: inputs are typically required to use `\n` only as a line ending and to end with a `\n` at the end of the file.


The resulting answer will then be scrolled across the seven segment displays.


## Solution Details

Each day folder contains the code for the corresponding day, with Day01a indicating Dec 1st, Part 1 and Day01b indicating Dec 1st, Part 2.

Inside the folder is the solution circuit ([Day01a.ml](Days/Day01a/Day01a.ml)), the Hardcaml testbench ([Day01a_tb.ml](Days/Day01a/Day01a_tb.ml)), and a verilog generator file ([Day01a_v.ml](Days/Day01a/Day01a_v.ml)). A sample input for the testbench ([Day01a_input.txt](Days/Day01a/Day01a_input.txt)) is also included, along with the dune build system information.

### Days/Day01a

Uses an FSM to recieve the L/R character and the digits. Digits are "shifted in" by multiplying the previous value by 10 and adding the new digit.
Once a newline is recieved, the dial position is updated by adding or subtracting the rotation amount.
The result is normalized by adding or subtracting 100 until it falls in the range \[0, 100\).
If the result is equal to 0, the answer is incremented.

### Days/Day01b

Similar to the previous day, except the counter is updated based on the following algorithim:

```python
if line.startswith('L'):
    times = int(line[1:])
    if dial_pos == 0:
        count -= 1
    dial_pos -= times
    while dial_pos < 0:
        count += 1
        dial_pos += 100
    if dial_pos == 0:
        count += 1

else:
    times = int(line[1:])
    dial_pos += times
    while dial_pos >= 100:
        count += 1
        dial_pos -= 100
```

### Days/Day03a

The FSM recieves input digit by digit, attempting to fill the first digit with a 9 (or the highest available digit), and moving on to the second digit once 1 digit away from the end or once the first digit has a 9.

### Days/Day03b

A generalized form of the algorithim from the previous day, the digits are filled from left to right, locking digits once too few remain for them to be updated. Digits are replaced when a higher digit is found, which zeroes out all digits to the right.

Example:
```
Pick 3 from input: 566487
Digits: 000
5: (5>0) -> replace first digit
Digits: 500
6: (6>5) -> replace first digit
Digits: 600
6: (6=6), (6>0) -> replace second digit
Digits: 660
4: (4<6), (4<6), (4>0) -> replace third digit
Digits: 664
First digit is locked
8: (8>6) -> replace second digit, zero all digits to the right
Digits: 680
Second digit is locked
7: (7>0) -> replace third digit
Digits: 687
All digits are now locked 
```

This had an elegant recursive hardcaml implementation and really demonstrated the usefulness of a function HDL.

```ocaml
let rec recursive_digit_fill idx = 
    if idx = 0 then if_ gnd [] []
    else
      if_ ((rx_digit >: select digits.value (4*idx-1) (4*idx-4)) &: 
           (digit_counter.value <:. number_of_inputs - idx + 1))
        [digits <-- update_digit idx rx_digit]
        [recursive_digit_fill (idx - 1)]
  in
```

### Days/Day04a and Day04b

The solution actually simulates the entire grid by representing each cell with a register. Practically, this should be inferred as RAM.
The cells are loaded one by one from UART, and then simulated by watching their neighbors. Day04a runs 1 cycle of the simulation, Day04b runs the simulation forever. Once the answer stops decreasing, it is valid. Due to simulation performance limitations a smaller grid is used, the grid
size can be updated in the solution files.

### Days/Day07a

Much like Day04, the grid is loaded one by one from UART, and then each cell is simulated to update based on its neighbors.
The number of splitters with a beam enterting is counted. Due to simulation performance limitations a smaller grid is used,
the grid size can be updated in the solution files.

### Days/Day07b

Similar to 07a, except the number of "timelines" from each beam is tracked on the way down, and the timelines on the bottom row are summed.

## Other Files

### Common Modules
Standardized modules that are not day-specific.

#### Binary_to_BCD.ml
Double-dabble implementation of binary to BCD converter.

#### MultiDigitDisplay.ml
Scrolls BCD digits across 2 seven segment displays.
ie: to display `123` the displays will show blank, `12`, `23`

#### SS_Display.ml
Drives an individual seven segment display from a BCD input to show `0-10`. `11-14` are blank, and `15` shows a `-` sign.

#### UART_Decoder.ml
Decodes an incoming UART data. When an RX falling edge is detected, the design waits for half a bit period, then samples every bit period. No integrity checking (parity / stop bits) are done as error handling wouldn't allow the top level design to do anything other then enter an error state which isn't that helpful for AoC.

The go-board runs at 25 MHz, so a counter value of 217 is used for 115200 baud.

#### SerialTB.ml
Cyclesim testbench functions to drive a UART input. Pairs with the UART_Decoder module.

## verilog_build

`apio.ini` - apio project file

`go-board.pcf` - go-board pin constraint file

`solution.v` - generated by `DayXX_v.ml`

`sync.sv` - synchronizer for the RX input

`top_tb.sv` - testbench for the system verilog code, effectively identical to the `DayXX_tb.ml` tests where character are sent by reading `tb_input.txt`

`top.sv` - top level SystemVerilog code for the FPGA implementation, synchronizes the RX input and unpacks the seven seg outputs




