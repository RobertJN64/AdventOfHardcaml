open AdventLib
open Hardcaml
open Signal

let day01a () =
  let clock = input "clock" 1 in
  let reset = input "reset" 1 in
  let rx = input "rx" 1 in
  let value_1 = (Counter.Counter.create {clock; reset}).counter -- "auto_counter" in
  let value_2 = Signal.concat_msb [ rx; rx; rx; rx ] -- "manual_counter" in

  let s1_A_G = SS_Display.SS_Display.create {value=(Signal.select value_1 24 21)} in
  let s2_A_G = SS_Display.SS_Display.create {value=value_2} in
  
  Circuit.create_exn
    ~name:"solution"
    [
      output "ss1_A_G" s1_A_G.seven_seg_A_G;
      output "ss2_A_G" s2_A_G.seven_seg_A_G;
    ]
    
  

