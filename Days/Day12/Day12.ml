open AdventLib
open Hardcaml
open Signal
open Always

module States = struct
    type t =
      | Idle
      | Width_RCV
      | Height_RCV
      | Count_RCV
      | Process_Counter
      | Process_Result
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

let day12 () =
  let clock = input "clock" 1 in
  let reset = input "reset" 1 in
  let rx = input "rx" 1 in

  let spec = Reg_spec.create ~clock ~reset () in

  let udout = UART_Decoder.UART_Decoder.create {clock; reset; rx} in
  let rx_strobe = udout.rx_strobe in
  let rx_byte = udout.rx_byte in

  let sm = State_machine.create (module States) spec in
  let grid_dim_bit_width = 8 in
  let grid_area_bit_width = 2 * grid_dim_bit_width in
  let grid_width = Variable.reg spec ~width:grid_dim_bit_width in
  let grid_height = Variable.reg spec ~width:grid_dim_bit_width in
  let active_counter = Variable.reg spec ~width:grid_dim_bit_width in
  let answer = Variable.reg spec ~width:10 in
  let counter_sum = Variable.reg spec ~width:grid_area_bit_width in
  let grid_area = grid_width.value *: grid_height.value in

  (* only works if grid_dim_bit_width matches size of new_digit*)
  let shift_in_digit prev_val new_digit = (select (prev_val *: of_int ~width:grid_dim_bit_width 10) (grid_dim_bit_width-1) 0) +: (new_digit -: of_char '0') in
  

  compile [ sm.switch [
    ( Idle, [
        sm.set_next Width_RCV;
        grid_width <-- zero grid_dim_bit_width;
        grid_height <-- zero grid_dim_bit_width;
        active_counter <-- zero grid_dim_bit_width;
        counter_sum <-- zero grid_area_bit_width
    ]);
    ( Width_RCV, [when_ rx_strobe [
      if_ (rx_byte ==: of_char 'x')
        [sm.set_next Height_RCV]
        [grid_width <-- shift_in_digit grid_width.value rx_byte]
    ]]);
    ( Height_RCV, [when_ rx_strobe [
      if_ (rx_byte ==: of_char ':')
        [sm.set_next Count_RCV]
        [grid_height <-- shift_in_digit grid_height.value rx_byte]
    ]]);
    ( Count_RCV, [when_ rx_strobe [
      if_ (rx_byte ==: of_char ' ')
        [sm.set_next Process_Counter]
        [if_ (rx_byte ==: of_char '\n')
          [sm.set_next Process_Result]
          [active_counter <-- shift_in_digit active_counter.value rx_byte]
        ]
    ]]);
    (Process_Counter, [
        counter_sum <-- counter_sum.value +: uresize active_counter.value grid_area_bit_width;
        active_counter <-- zero grid_dim_bit_width;
        sm.set_next Count_RCV
    ]);
    (Process_Result, [
      when_ (select ((counter_sum.value +: uresize active_counter.value grid_area_bit_width) *: of_int ~width:grid_area_bit_width 8) (grid_area_bit_width - 1) 0 <: grid_area)
        [answer <-- answer.value +: one 10];
        sm.set_next Idle
    ])
  ]];

  let answer_val = answer.value -- "answer" in (* exposes this register for testbench to check against *)

  let bin_to_bcd = Binary_to_BCD.Binary_to_BCD.create {binary_val=answer_val} in
  let bin_to_bcd_val = bin_to_bcd.bcd_val -- "bcd_out" in
  let mdd = MultiDigitDisplay.MultiDigitDisplay.create {clock; reset; digits=bin_to_bcd_val} 4 in
  
  Circuit.create_exn
    ~name:"solution"
    [
      output "ss1_A_G" mdd.ss1_A_G.seven_seg_A_G;
      output "ss2_A_G" mdd.ss2_A_G.seven_seg_A_G;
      output "LED1" (sm.is Idle);
      output "LED2" (sm.is Width_RCV);
      output "LED3" (sm.is Height_RCV);
      output "LED4" (sm.is Count_RCV)
    ]
    
  

