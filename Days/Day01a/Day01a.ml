open Hardcaml
open Signal

let () =
  let a = input "a" 2 in
  let b = input "b" 2 in
  let y = a &: b in

  let circuit =
    Circuit.create_exn
      ~name:"and_gate"
      [ output "y" y ]
  in

  Rtl.output ~output_mode:(Rtl.Output_mode.To_file "top.v") Verilog circuit
  
  
