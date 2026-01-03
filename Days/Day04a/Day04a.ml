open AdventLib
open Hardcaml
open Signal
open Always

module States = struct
    type t =
      | Idle
      | Grid_RCV
      | Grid_Sim
      | Done
      | Error
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

let day04a () =
  let clock = input "clock" 1 in
  let reset = input "reset" 1 in
  let rx = input "rx" 1 in

  let spec = Reg_spec.create ~clock ~reset () in

  let udout = UART_Decoder.UART_Decoder.create {clock; reset; rx} in
  let rx_strobe = udout.rx_strobe in
  let rx_byte = udout.rx_byte in

  let sm = State_machine.create (module States) spec in

  let grid_dim = 10 in (* update to match input *)
  let grid_dim_width = num_bits_to_represent (grid_dim + 2) in
  (* grid has "padding" of 1 row around the simulated  section *)
  let reg_grid = Array.init (grid_dim+2) (fun _ ->
    Array.init (grid_dim+2) (fun _ -> 
      Variable.reg spec ~width:1
  )) in

  let active_col = Variable.reg spec ~width:grid_dim_width in
  let active_row = Variable.reg spec ~width:grid_dim_width in

  let answer_width = 16 in

  let grid_sum =
    Array.fold_left
      (fun acc row ->
        Array.fold_left
          (fun acc (cell: Variable.t) ->
            acc +: uresize cell.value answer_width
          )
          acc
          row
      )
      (zero answer_width)
      reg_grid
  in

  let neighbors r c =
  [
    reg_grid.(r-1).(c-1).value;
    reg_grid.(r-1).(c).value;
    reg_grid.(r-1).(c+1).value;
    reg_grid.(r).(c-1).value;
    reg_grid.(r).(c+1).value;
    reg_grid.(r+1).(c-1).value;
    reg_grid.(r+1).(c).value;
    reg_grid.(r+1).(c+1).value;
  ] in

  (* exports to allow testbench to inspect values *)
  let starting_count = Variable.reg spec ~width:answer_width in
  let answer = Variable.reg spec ~width:answer_width in
  let _ = starting_count.value -- "day04-sc_val" in
  let _ = active_col.value -- "day04-ac_val" in
  let _ = active_row.value -- "day04-ar_val" in
  let _ = grid_sum -- "day04-grid_sum" in
  for r = 1 to 10 do
    for c = 1 to 10 do
      let name = Printf.sprintf "grid_%d_%d" r c in
      let _ = reg_grid.(r).(c).value -- name in
      ()
    done
  done;
  
  compile [ sm.switch [
    ( Idle, [
        sm.set_next Grid_RCV;
        active_col <--. 1;
        active_row <--. 1]
    );
    ( Grid_RCV, [when_ rx_strobe [
      if_ (rx_byte ==: of_char '\n') [
        if_ (active_col.value ==:. grid_dim + 1) [
          if_ (active_row.value ==:. grid_dim) [
            starting_count <-- grid_sum;
            sm.set_next Grid_Sim (* reached end of grid *)
          ] [
            active_col <--. 1; (* reached end of row, so update positions *)
            active_row <-- active_row.value +:. 1
          ]]
          [sm.set_next Error] (* reached end of row unexpectedly *)
      ] [ (* place the symbol in the correct register *)
        active_col <-- active_col.value +:. 1;
        when_ (rx_byte ==: of_char '@') (List.concat (
          List.init (grid_dim+2) (fun r ->
            List.init (grid_dim+2) (fun c ->
              let row_match = active_row.value ==:. r in
              let col_match = active_col.value ==:. c in
              let selected  = row_match &: col_match in

              when_ selected [
                reg_grid.(r).(c) <--. 1
              ]
            )
          )
        ))
    ]]]);
    ( Grid_Sim, (List.concat (
      List.init (grid_dim) (fun r ->
        List.init (grid_dim) (fun c ->
          let true_r = r + 1 in
          let true_c = c + 1 in

          (* check the 8 adjacent registers, assign to 0 if >= 4 are 0*)

          let ones_count =
            neighbors true_r true_c
            |> List.map (fun s -> uresize s 4)
            |> List.fold_left ( +: ) (zero 4)
          in

          let next_val =
            mux2 (ones_count <:. 4)
              (gnd)   (* assign 0 *)
              (vdd)   (* assign 1 *) in

          reg_grid.(true_r).(true_c) <-- (reg_grid.(true_r).(true_c).value &: next_val)
      )))) @ [sm.set_next Done] (* remove a single iteration *)
    );
    ( Done, [answer <-- starting_count.value -: grid_sum]);
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
      output "LED4" (sm.is Done |: sm.is Error)
    ]
    
  

