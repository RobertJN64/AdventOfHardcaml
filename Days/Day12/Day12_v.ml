open Hardcaml

let () = 
  let circuit = Day12.day12() in
  Rtl.output ~output_mode:(Rtl.Output_mode.To_file "verilog_build/solution.v") Verilog circuit