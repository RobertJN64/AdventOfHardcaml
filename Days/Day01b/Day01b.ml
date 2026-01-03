open AdventLib
open Hardcaml
open Signal
open Always

module States = struct
    type t =
      | Idle
      | RCV_Char
      | RCV_Digit
      | Normalize
      | Check_Zero
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

let day01b () =
  let clock = input "clock" 1 in
  let reset = input "reset" 1 in
  let rx = input "rx" 1 in

  let spec = Reg_spec.create ~clock ~reset () in
  let dial_pos_width = 12 in
  let spec_reset_to_50 = Reg_spec.override spec ~reset_to:(of_int ~width:dial_pos_width 50) in
  let dial_pos = Variable.reg spec_reset_to_50 ~width:dial_pos_width in

  let udout = UART_Decoder.UART_Decoder.create {clock; reset; rx} in
  let rx_strobe = udout.rx_strobe in
  let rx_byte = udout.rx_byte in

  let sm = State_machine.create (module States) spec in
  let rotation_amount = Variable.reg spec ~width:dial_pos_width in
  let rotation_dir = Variable.reg spec ~width:1 in
  let answer = Variable.reg spec ~width:16 in

  let shift_in_digit prev_val  = (select (prev_val *: of_int ~width:4 10) (dial_pos_width-1) 0) +: uresize (rx_byte -: of_char '0') dial_pos_width in

  compile [ sm.switch [
    ( Idle, [
        sm.set_next RCV_Char;
        rotation_amount <--. 0;
    ]);
    ( RCV_Char, [when_ rx_strobe [
      sm.set_next RCV_Digit;
      if_ (rx_byte ==: of_char 'R')
        [rotation_dir <--. 0] (* 0 = R = + *)
        [rotation_dir <--. 1] (* 1 = L = - *)
    ]]);
    ( RCV_Digit, [when_ rx_strobe [
      if_ (rx_byte ==: of_char '\n') [
        sm.set_next Normalize;
        if_ rotation_dir.value [ (* left = - *)
          when_ ((dial_pos.value ==:. 0)) [
            answer <-- answer.value -:. 1; (* adjust left turns starting at 0 by -1*)
          ];
          dial_pos <-- dial_pos.value -: rotation_amount.value
        ][ (* right = - *)
          dial_pos <-- dial_pos.value +: rotation_amount.value
      ]][
      rotation_amount <-- shift_in_digit rotation_amount.value
    ]]]);
    ( Normalize, [
      if_ (dial_pos.value >=+. 100) [ (* note: >=+. for signed instead of >=:. *)
          answer <-- answer.value +:. 1;
          dial_pos <-- dial_pos.value -:. 100
        ][
          if_ (dial_pos.value <+. 0) [ (* note: >=+. for signed instead of >=:. *)
            answer <-- answer.value +:. 1;
            dial_pos <-- dial_pos.value +:. 100
          ][
            sm.set_next Check_Zero
    ]]]);
    ( Check_Zero, [
      sm.set_next Idle;
      when_ ((dial_pos.value ==:. 0) &: (rotation_dir.value))
        [answer <-- answer.value +:. 1]
    ])
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
      output "LED1" (sm.is RCV_Char);
      output "LED2" (sm.is RCV_Digit);
      output "LED3" (sm.is Normalize);
      output "LED4" (sm.is Check_Zero)
    ]
    
  

