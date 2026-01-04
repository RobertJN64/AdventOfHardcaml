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
  delay_serial sim

let send_serial_string sim s =
  String.iter (fun c ->
    send_serial_packet sim (Char.code c);
    Printf.printf "%c%!" c;
  ) s

let send_serial_file sim filename =
  let ic = open_in filename in
  try
    let file_size = in_channel_length ic in
    let content = really_input_string ic file_size in
    close_in ic;
    send_serial_string sim content
  with e ->
    close_in_noerr ic;
    raise e
