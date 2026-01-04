open Hardcaml

let () = 
  let circuit = Day05a.day05a() in
  Rtl.output ~output_mode:(Rtl.Output_mode.To_file "verilog_build/solution.v") Verilog circuit