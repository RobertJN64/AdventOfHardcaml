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
  
  Cyclesim.reset sim;
  Cyclesim.cycle sim;
  SerialTB.send_serial_packet sim 0x5A;
  SerialTB.send_serial_packet sim 0xBC;

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
  Waveform.print ~wave_width:1 ~display_width:150 waves;
  
  close_out out_chan

