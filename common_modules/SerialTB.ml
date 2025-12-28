open Hardcaml

(* Utility functions for sending serial packets in testbenches *)

let serial_bit_cycles = 217 (* 25 MHz / 115200 baud *)

let delay_serial sim =
  for _ = 1 to serial_bit_cycles do
    Cyclesim.cycle sim;
  done

let send_serial_packet sim byte =
  let rx = Cyclesim.in_port sim "rx" in
  let bits = List.init 8 (fun i -> (byte lsr i) land 1) in
  rx := Bits.of_int ~width:1 0;
  delay_serial sim;
  List.iter (fun b ->
    rx := Bits.of_int ~width:1 b;
    delay_serial sim;
  ) bits;
  rx := Bits.of_int ~width:1 1;
  delay_serial sim;