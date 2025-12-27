open AdventLib
open Hardcaml
open Signal

let day01a () =
  let sw1 = input "SW1" 1 in
  let sw2 = input "SW2" 1 in
  let sw3 = input "SW3" 1 in
  let sw4 = input "SW4" 1 in
  let value_1 = Signal.concat_msb [ sw4; sw3; sw2; sw1 ] in
  let value_2 = Signal.concat_msb [ sw2; sw3; sw4; sw1 ] in

  let s1_A_G = SS_Display.SS_Display.create {value=value_1} in
  let s2_A_G = SS_Display.SS_Display.create {value=value_2} in
  
  
  Circuit.create_exn
    ~name:"top"
    (
      (List.mapi 
        (fun i name -> output name (Signal.bit s1_A_G.seven_seg_A_G (6 - i)))  (*map the first seven segment display*)
        [ "S1_A"; "S1_B"; "S1_C"; "S1_D"; "S1_E"; "S1_F"; "S1_G" ]
      ) 
      @ 
      (List.mapi 
        (fun i name -> output name (Signal.bit s2_A_G.seven_seg_A_G (6 - i)))  (*map the second seven segment display*)
        [ "S2_A"; "S2_B"; "S2_C"; "S2_D"; "S2_E"; "S2_F"; "S2_G" ]
      )
    )
  

