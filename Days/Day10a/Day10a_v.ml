open Hardcaml

let () = 
  let circuit = Day10a.day10a() in
  Rtl.output ~output_mode:(Rtl.Output_mode.To_file "verilog_build/solution.v") Verilog circuit