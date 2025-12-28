open AdventLib
open Hardcaml
open Signal

let day01a () =
  let clock = input "clock" 1 in
  let reset = input "reset" 1 in
  let rx = input "rx" 1 in

  let udout = UART_Decoder.UART_Decoder.create {clock; reset; rx} in
  let active_byte = udout.rx_byte -- "serial_byte" in

  let s1_A_G = SS_Display.SS_Display.create {value=(select active_byte 7 4)} in
  let s2_A_G = SS_Display.SS_Display.create {value=(select active_byte 3 0)} in

  
  Circuit.create_exn
    ~name:"solution"
    [
      output "ss1_A_G" s1_A_G.seven_seg_A_G;
      output "ss2_A_G" s2_A_G.seven_seg_A_G;
    ]
    
  

