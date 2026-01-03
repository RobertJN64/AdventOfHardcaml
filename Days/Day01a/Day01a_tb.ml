open AdventLib
open Hardcaml
open Hardcaml_waveterm

let () =
  let circuit = Day01a.day01a () in
  let config = Cyclesim.Config.trace_all in
  let sim = Cyclesim.create ~config circuit in
  let waves, sim = Waveform.create sim in

  let out_chan = open_out "waves.vcd" in
  let sim = Vcd.wrap out_chan sim in
  let answer = match Cyclesim.lookup_reg_by_name sim "answer" with
  | Some node -> node
  | None -> failwith "answer reg not found" in

  Cyclesim.reset sim;
  Cyclesim.cycle sim;
  SerialTB.send_serial_file sim "Days/Day01a/Day01a_input.txt";
  let answer_value = Cyclesim.Reg.to_int answer in
  
  for _ = 0 to 10000 do
    Cyclesim.cycle sim;
  done;

  (* Display waveform in terminal *)
  Waveform.print ~wave_width:1 ~display_width:150 ~display_height:50 waves;

  Printf.printf "Answer = %d\n" answer_value;

  assert (answer_value = 3); (* update this if input changes *)

  close_out out_chan

