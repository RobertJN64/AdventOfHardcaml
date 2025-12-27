open Hardcaml

let () =
  let circuit = Day01a.day01a() in
  let sim = Cyclesim.create circuit in

  let sw1 = Cyclesim.in_port sim "SW1" in
  let sw2 = Cyclesim.in_port sim "SW2" in
  let sw3 = Cyclesim.in_port sim "SW3" in
  let sw4 = Cyclesim.in_port sim "SW4" in
  
  let set in1 in2 in3 in4 =
    sw1 := Bits.of_int ~width:1 in1;
    sw2 := Bits.of_int ~width:1 in2;
    sw3 := Bits.of_int ~width:1 in3;
    sw4 := Bits.of_int ~width:1 in4;
    Cyclesim.cycle sim
  in
  
  (* Try several input combinations *)
  set 0 0 0 0;
  set 1 0 0 0;
  set 0 1 0 0;
  set 1 1 1 1;

  (* Print outputs *)
  List.iter
    (fun name ->
      Printf.printf "%s = %s\n"
        name
        (Bits.to_string !(Cyclesim.out_port sim name)))
    [
      "S1_A"; "S1_B"; "S1_C"; "S1_D"; "S1_E"; "S1_F"; "S1_G";
      "S2_A"; "S2_B"; "S2_C"; "S2_D"; "S2_E"; "S2_F"; "S2_G";
    ]
