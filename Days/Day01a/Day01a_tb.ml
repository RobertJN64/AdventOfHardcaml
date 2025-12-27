open Hardcaml
open Hardcaml_waveterm


let () =
  let circuit = Day01a.day01a () in
  let config = Cyclesim.Config.trace_all in
  let sim = Cyclesim.create ~config circuit in
  let waves, sim = Waveform.create sim in

  let sw1 = Cyclesim.in_port sim "SW1" in
  let sw2 = Cyclesim.in_port sim "SW2" in
  let sw3 = Cyclesim.in_port sim "SW3" in
  let sw4 = Cyclesim.in_port sim "SW4" in
  let value2 = Cyclesim.internal_port sim "value2" in
  
  let set in1 in2 in3 in4 =
    sw1 := Bits.of_int ~width:1 in1;
    sw2 := Bits.of_int ~width:1 in2;
    sw3 := Bits.of_int ~width:1 in3;
    sw4 := Bits.of_int ~width:1 in4;
    Cyclesim.cycle sim;
    Printf.printf "%s\n" (Bits.to_string !value2);
  in

  (* Try several input combinations *)
  set 0 0 0 0;
  set 1 0 0 0;
  set 0 1 0 0;
  set 1 1 1 1;

  (* Display waveform in terminal *)
  let rule = Display_rule.[
    Names {names =[Expert.Port_name.of_string "value2"]; wave_format=Wave_format.Bit; alignment=Text_alignment.Left};
    Names {names =[Expert.Port_name.of_string "SW1"]; wave_format=Wave_format.Bit; alignment=Text_alignment.Left}
  ] in
  Waveform.print ~display_rules:rule waves
