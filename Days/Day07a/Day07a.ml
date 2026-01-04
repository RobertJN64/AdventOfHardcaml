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

let day07a () =
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
  (* grid has "padding" of 1 col on either side of the simulated section *)
  let reg_grid = Array.init (grid_height) (fun _ ->
    Array.init (grid_width+2) (fun _ -> 
      Variable.reg spec ~width:2
  )) in

  let active_col = Variable.reg spec ~width:grid_dim_bits in
  let active_row = Variable.reg spec ~width:grid_dim_bits in

  let answer_width = 8 in
  let answer = Variable.reg spec ~width:answer_width in

  let count_splits =
    let acc = ref (zero answer_width) in (* mutable ref accumulator *)

    (* iterate over vertical neighbors *)
    for r = 0 to grid_height-2 do
      for c = 1 to grid_width do
        let cell_upper = reg_grid.(r).(c) in
        let cell_lower = reg_grid.(r+1).(c) in

        let should_inc = (cell_upper.value ==:. grid_char_bar) &: (cell_lower.value ==: of_int ~width:2 grid_char_carat) in

        acc := !acc +: mux2 should_inc (one answer_width) (zero answer_width)
      done
    done;

    !acc
  in

  for r = 0 to grid_height-1 do
    for c = 1 to grid_width do
      let name = Printf.sprintf "grid_%d_%d" r c in
      let _ = reg_grid.(r).(c).value -- name in
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
                when_ (rx_byte ==: of_char 'S') [reg_grid.(r).(c) <--. grid_char_S] 
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
            when_ (reg_grid.(r-1).(c).value ==:. grid_char_S) [reg_grid.(r).(c) <--. grid_char_bar]; (* start from S *)
            when_ (reg_grid.(r-1).(c).value ==:. grid_char_bar) [reg_grid.(r).(c) <--. grid_char_bar]; (* | moves down *)
            when_ ((reg_grid.(r).(c-1).value ==:. grid_char_carat) &:
                   (reg_grid.(r-1).(c-1).value ==:. grid_char_bar)
            ) [reg_grid.(r).(c) <--. grid_char_bar]; (* activated ^ splits *)
            when_ ((reg_grid.(r).(c+1).value ==:. grid_char_carat) &:
                   (reg_grid.(r-1).(c+1).value ==:. grid_char_bar)
            ) [reg_grid.(r).(c) <--. grid_char_bar] (* activated ^ splits *)
          ]
      )))) @ [answer <-- count_splits]
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
    
  

