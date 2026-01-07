open Hardcaml

let () = 
  let circuit = Day05b.day05b() in
  Rtl.output ~output_mode:(Rtl.Output_mode.To_file "verilog_build/solution.v") Verilog circuit