open Hardcaml

let () = 
  let circuit = Day04b.day04b() in
  Rtl.output ~output_mode:(Rtl.Output_mode.To_file "verilog_build/solution.v") Verilog circuit