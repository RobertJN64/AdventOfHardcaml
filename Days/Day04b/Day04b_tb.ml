open AdventLib
open Hardcaml
open Hardcaml_waveterm

let () =
  let circuit = Day04b.day04b () in
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
  SerialTB.send_serial_file sim "Days/Day04a/Day04a_input.txt";

  for _ = 0 to 1000 do (* run for a little longer to ensure we finish simulating *)
    Cyclesim.cycle sim;
  done;

  let answer_value = Cyclesim.Reg.to_int answer in
  
  (* Display waveform in terminal *)
  Waveform.print ~wave_width:1 ~display_width:150 ~display_height:50 waves;

  for r = 1 to 10 do
    for c = 1 to 10 do
      let name = Printf.sprintf "grid_%d_%d" r c in
      let grid_cell = match Cyclesim.lookup_reg_by_name sim name with
      | Some node -> node
      | None -> failwith "answer reg not found" in
      let grid_cell_value = Cyclesim.Reg.to_int grid_cell in
      if grid_cell_value == 1 then Printf.printf "@" else Printf.printf "."
    done;
    Printf.printf "\n"
  done;
  Printf.printf "\n";

  Printf.printf "Answer = %d\n" answer_value;

  assert (answer_value = 43); (* update this if input changes *)
  
  close_out out_chan

