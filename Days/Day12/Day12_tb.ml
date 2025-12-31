open AdventLib
open Hardcaml
(* open Hardcaml_waveterm *)

let () =
  let circuit = Day12.day12 () in
  let config = Cyclesim.Config.trace_all in
  let sim = Cyclesim.create ~config circuit in
  (* let waves, sim = Waveform.create sim in *)

  (* let out_chan = open_out "waves.vcd" in *)
  (* let sim = Vcd.wrap out_chan sim in *)
  let answer = match Cyclesim.lookup_reg_by_name sim "answer" with
  | Some node -> node
  | None -> failwith "answer reg not found" in

  Cyclesim.reset sim;
  Cyclesim.cycle sim;
  (* SerialTB.send_serial_string sim "40x41: 44 53 34 42 33 43\n"; *)
  SerialTB.send_serial_file sim "Days/Day12/Day12_input.txt";
  let answer_value = Cyclesim.Reg.to_int answer in
  Printf.printf "Answer = %d\n" answer_value;

  for _ = 0 to 10000 do
    Cyclesim.cycle sim;
  done;

  (* Display waveform in terminal *)
  (* let rule = Display_rule.[
    Names {names =[Port_name.of_string "clock"]; wave_format=Some(Wave_format.Bit); alignment=Text_alignment.Left};
    Names {names =[Port_name.of_string "reset"]; wave_format=Some(Wave_format.Bit); alignment=Text_alignment.Left};
    Names {names =[Port_name.of_string "auto_counter"]; wave_format=Some(Wave_format.Int); alignment=Text_alignment.Left};
    Names {names =[Port_name.of_string "manual_counter"]; wave_format=Some(Wave_format.Int); alignment=Text_alignment.Left}
  ] in *)
  (* Waveform.print ~wave_width:1 ~display_width:150 waves;
  
  close_out out_chan *)

