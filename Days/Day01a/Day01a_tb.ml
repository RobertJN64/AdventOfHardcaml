open Hardcaml
open Hardcaml_waveterm

let () =
  let circuit = Day01a.day01a () in
  let config = Cyclesim.Config.trace_all in
  let sim = Cyclesim.create ~config circuit in
  let waves, sim = Waveform.create sim in

  let out_chan = open_out "waves.vcd" in
  let writer x = output_string out_chan x in
  let sim = Vcd.wrap writer sim in

  
  let tick () =    
    Cyclesim.cycle sim;
    Cyclesim.cycle sim in

  
  Cyclesim.reset sim;

  for _ = 0 to 10000 do
    tick();
  done;


  (* Display waveform in terminal *)
  let rule = Display_rule.[
    Names {names =[Expert.Port_name.of_string "clock"]; wave_format=Wave_format.Bit; alignment=Text_alignment.Left};
    Names {names =[Expert.Port_name.of_string "reset"]; wave_format=Wave_format.Bit; alignment=Text_alignment.Left};
    Names {names =[Expert.Port_name.of_string "auto_counter"]; wave_format=Wave_format.Int; alignment=Text_alignment.Left};
    Names {names =[Expert.Port_name.of_string "manual_counter"]; wave_format=Wave_format.Int; alignment=Text_alignment.Left}
  ] in
  Waveform.print ~display_rules:rule waves;
  close_out out_chan

