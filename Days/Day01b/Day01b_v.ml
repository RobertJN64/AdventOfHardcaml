open Hardcaml

let () = 
  let circuit = Day01b.day01b() in
  Rtl.output ~output_mode:(Rtl.Output_mode.To_file "verilog_build/solution.v") Verilog circuit