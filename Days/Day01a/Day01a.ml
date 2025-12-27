open AdventLib
open Hardcaml
open Signal

let () =
  let sw1 = input "SW1" 1 in
  let sw2 = input "SW2" 1 in
  let sw3 = input "SW3" 1 in
  let sw4 = input "SW4" 1 in
  let value = Signal.concat_msb [ sw4; sw3; sw2; sw1 ] in

  let seven_seg_A_G = SS_Display.SS_Display.create {value} in
  let circuit =
    Circuit.create_exn
      ~name:"top"
      [ 
        output "S1_A" (Signal.bit seven_seg_A_G.seven_seg_A_G 6);
        output "S1_B" (Signal.bit seven_seg_A_G.seven_seg_A_G 5);
        output "S1_C" (Signal.bit seven_seg_A_G.seven_seg_A_G 4);
        output "S1_D" (Signal.bit seven_seg_A_G.seven_seg_A_G 3);
        output "S1_E" (Signal.bit seven_seg_A_G.seven_seg_A_G 2);
        output "S1_F" (Signal.bit seven_seg_A_G.seven_seg_A_G 1);
        output "S1_G" (Signal.bit seven_seg_A_G.seven_seg_A_G 0);
      ]
  in

  Rtl.output ~output_mode:(Rtl.Output_mode.To_file "verilog_build/top.v") Verilog circuit
  