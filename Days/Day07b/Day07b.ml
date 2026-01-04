open AdventLib
open Hardcaml
open Signal
open Always

module States = struct
    type t =
      | Idle
      | Grid_RCV
      | Grid_Sim
      | Error
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

let day07b () =
  let clock = input "clock" 1 in
  let reset = input "reset" 1 in
  let rx = input "rx" 1 in

  let spec = Reg_spec.create ~clock ~reset () in

  let udout = UART_Decoder.UART_Decoder.create {clock; reset; rx} in
  let rx_strobe = udout.rx_strobe in
  let rx_byte = udout.rx_byte in

  let sm = State_machine.create (module States) spec in
  
  let grid_width = 15 in (* update to match input *)
  let grid_height = 16 in (* update to match input *)
  let grid_dim_bits = num_bits_to_represent (max (grid_width+2) grid_height) in
  let grid_char_dot = 0 in (* 00 = ., 01 = |, 02 = ^, 03 = S *)
  let grid_char_bar = 1 in
  let grid_char_carat = 2 in
  let grid_char_S = 3 in

  let answer_width = 8 in
  (* grid has "padding" of 1 col on either side of the simulated section *)
  let reg_grid = Array.init (grid_height) (fun _ ->
    Array.init (grid_width+2) (fun _ -> 
      Variable.reg spec ~width:2
  )) in
  let timeline_counter_grid = Array.init (grid_height) (fun _ ->
    Array.init (grid_width+2) (fun _ -> 
      Variable.reg spec ~width:answer_width
  )) in

  let active_col = Variable.reg spec ~width:grid_dim_bits in
  let active_row = Variable.reg spec ~width:grid_dim_bits in

  let answer = Variable.reg spec ~width:answer_width in

  let sum_bottom_timelines =
    Array.fold_left
      (fun acc (cell: Variable.t) -> acc +: uresize cell.value answer_width)    
    (zero answer_width)
    timeline_counter_grid.(grid_height-1)
  in

  for r = 0 to grid_height-1 do
    for c = 1 to grid_width do
      let name = Printf.sprintf "grid_%d_%d" r c in
      let _ = reg_grid.(r).(c).value -- name in
      ()
    done
  done;

  for r = 0 to grid_height-1 do
    for c = 1 to grid_width do
      let name = Printf.sprintf "tc_grid_%d_%d" r c in
      let _ = timeline_counter_grid.(r).(c).value -- name in
      ()
    done
  done;

  compile [ sm.switch [
    ( Idle, [
        sm.set_next Grid_RCV;
        active_col <--. 1;
        active_row <--. 0]
    );
    ( Grid_RCV, [when_ rx_strobe [
      if_ (rx_byte ==: of_char '\n') [
        if_ (active_col.value ==:. grid_width + 1) [
          if_ (active_row.value ==:. grid_height - 1) [
            sm.set_next Grid_Sim (* reached end of grid *)
          ] [
            active_col <--. 1; (* reached end of row, so update positions *)
            active_row <-- active_row.value +:. 1
          ]]
          [sm.set_next Error] (* reached end of row unexpectedly *)
      ] ([ (* place the symbol in the correct register *)
        active_col <-- active_col.value +:. 1] @ List.concat (
          List.init (grid_height) (fun r ->
            List.init (grid_width+2) (fun c ->
              let row_match = active_row.value ==:. r in
              let col_match = active_col.value ==:. c in
              let selected  = row_match &: col_match in

              when_ selected [
                when_ (rx_byte ==: of_char '.') [reg_grid.(r).(c) <--. grid_char_dot];
                when_ (rx_byte ==: of_char '|') [reg_grid.(r).(c) <--. grid_char_bar];
                when_ (rx_byte ==: of_char '^') [reg_grid.(r).(c) <--. grid_char_carat];
                when_ (rx_byte ==: of_char 'S') [reg_grid.(r).(c) <--. grid_char_S];
                timeline_counter_grid.(r).(c) <--. 0
              ]
            )
          )
    ))]]);
    ( Grid_Sim, (List.concat (
      List.init (grid_height - 1) (fun raw_r ->
        List.init (grid_width) (fun raw_c ->
          let r = raw_r + 1 in
          let c = raw_c + 1 in

          when_ (reg_grid.(r).(c).value ==:. grid_char_dot) [
            if_ (reg_grid.(r-1).(c).value ==:. grid_char_S) [
              timeline_counter_grid.(r).(c) <--. 1
            ][
              let from_above = timeline_counter_grid.(r-1).(c).value in
              let has_splitter_left = reg_grid.(r).(c-1).value ==:. grid_char_carat in
              let has_splitter_right = reg_grid.(r).(c+1).value ==:. grid_char_carat in
              let from_splitter_left = mux2 has_splitter_left (timeline_counter_grid.(r-1).(c-1).value) (zero answer_width) in
              let from_splitter_right = mux2 has_splitter_right (timeline_counter_grid.(r-1).(c+1).value) (zero answer_width) in
              timeline_counter_grid.(r).(c) <-- from_above +: from_splitter_left +: from_splitter_right
            ]
          ]
      )))) @ [answer <-- sum_bottom_timelines]
    );
    ( Error, []) (* lock here forever - all LEDs are on - this happens if the number_of_inputs var does not match the actual inputs *)
  ]];

  let answer_val = answer.value -- "answer" in (* exposes this register for testbench to check against *)

  let bin_to_bcd = Binary_to_BCD.Binary_to_BCD.create {binary_val=answer_val} in
  let bin_to_bcd_val = bin_to_bcd.bcd_val -- "bcd_out" in
  let mdd = MultiDigitDisplay.MultiDigitDisplay.create {clock; reset; digits=bin_to_bcd_val} in
  
  Circuit.create_exn
    ~name:"solution"
    [
      output "ss1_A_G" mdd.ss1_A_G.seven_seg_A_G;
      output "ss2_A_G" mdd.ss2_A_G.seven_seg_A_G;
      output "LED1" (sm.is Idle |: sm.is Error);
      output "LED2" (sm.is Grid_RCV |: sm.is Error);
      output "LED3" (sm.is Grid_Sim |: sm.is Error);
      output "LED4" (sm.is Error |: sm.is Error)
    ]
    
  

