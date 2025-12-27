open Hardcaml
open Signal

let () =
  let a = input "SW1" 1 in
  let b = input "SW2" 1 in
  let y = a &: b in

  let circuit =
    Circuit.create_exn
      ~name:"top"
      [ output "LED1" y ]
  in

  Rtl.output ~output_mode:(Rtl.Output_mode.To_file "verilog_build/top.v") Verilog circuit
  
  
