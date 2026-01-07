open AdventLib
open Hardcaml
open Hardcaml_waveterm

let () =
  let circuit = Day05b.day05b () in
  let config = Cyclesim.Config.trace_all in
  let sim = Cyclesim.create ~config circuit in
  let waves, sim = Waveform.create sim in

  let out_chan = open_out "waves.vcd" in
  let sim = Vcd.wrap out_chan sim in
  let answer = match Cyclesim.lookup_reg_by_name sim "answer" with
  | Some node -> node
  | None -> failwith "answer reg not found" in

  let led1 = Cyclesim.out_port sim "LED1" in (* this is 1 when ready to rcv *)
  let led4 = Cyclesim.out_port sim "LED4" in (* this is 1 when done *)

  Cyclesim.reset sim;
  Cyclesim.cycle sim;

  let ic = open_in "Days/Day05b/Day05b_input.txt" in
  Fun.protect
  ~finally:(fun () -> close_in_noerr ic)
  (fun () ->
    let file_size = in_channel_length ic in
    let content = really_input_string ic file_size in

    let id_strs = String.split_on_char '\n' content in

    List.iter
      (fun id_str ->
        while (Bits.to_int (!led1) = 0) && (Bits.to_int (!led4) = 0) do
          Cyclesim.cycle sim
        done;
        SerialTB.send_serial_string sim id_str;
        SerialTB.send_serial_string sim "\n"
      )
      id_strs;
  );
  
  for _ = 0 to 100 do
    Cyclesim.cycle sim;
  done;

  let answer_value = Cyclesim.Reg.to_int answer in

  (* Display waveform in terminal *)
  Waveform.print ~wave_width:1 ~display_width:150 ~display_height:50 waves;

  Printf.printf "Answer = %d\n" answer_value;

  close_out out_chan;

  assert (answer_value = 14); (* update this if input changes *)

