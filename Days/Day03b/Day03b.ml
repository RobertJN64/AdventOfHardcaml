open AdventLib
open Hardcaml
open Signal
open Always

module States = struct
    type t =
      | Idle
      | Process_Digits
      | Done
      | Error
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

let day03b () =
  let clock = input "clock" 1 in
  let reset = input "reset" 1 in
  let rx = input "rx" 1 in

  let spec = Reg_spec.create ~clock ~reset () in

  let udout = UART_Decoder.UART_Decoder.create {clock; reset; rx} in
  let rx_strobe = udout.rx_strobe in
  let rx_byte = udout.rx_byte in

  let sm = State_machine.create (module States) spec in
  let digits_needed = 12 in (* number of batteries to enable *)

  let digits = Variable.reg spec ~width:(4 * digits_needed) in
  let number_of_inputs = 100 in
  let digit_counter = Variable.reg spec ~width:(num_bits_to_represent number_of_inputs) in
  let answer_width = 48 in
  let answer = Variable.reg spec ~width:answer_width in

  
  let rx_digit = select (rx_byte -: of_char '0') 3 0 in

  let update_digit idx value =
    (* hi and lo are functions to only evaluate the select if needed, preventing 0 width errors *)
    let hi () = select digits.value (digits_needed*4-1) (4*idx) in
    let lo () = zero (4*idx-4) in
    if idx = 1 then concat_msb [hi(); value]
    else if idx = digits_needed then concat_msb [value; lo()]
    else concat_msb [hi(); value; lo()]
  in


  (* Update the digits register according to the following rules:
   - only update left digits when enough space remains to the right
   - only update digit when new digit is larger
   - when updating a digit, clear all digits to the right
   - attempt to update all digits starting from the left
   - left digit is idx 12, right digit is idx 1
  *)
  let rec recursive_digit_fill idx = 
    if idx = 0 then if_ gnd [] []
    else
      if_ ((rx_digit >: select digits.value (4*idx-1) (4*idx-4)) &: 
           (digit_counter.value <:. number_of_inputs - idx + 1))
        [digits <-- update_digit idx rx_digit]
        [recursive_digit_fill (idx - 1)]
  in


  (* call with idx from 1 to 12 *)
  let rec recursive_value_calc idx =
    let value = select digits.value (4*idx-1) (4*idx-4) in
    if idx = digits_needed then value
    else recursive_value_calc(idx + 1) *: of_int ~width:4 10 +: uresize value ((digits_needed-idx)*4+4)
  in

  let current_voltage = recursive_value_calc 1 in
  let _cv_val = current_voltage -- "cv_val" in


  compile [ sm.switch [
    ( Idle, [
        sm.set_next Process_Digits;
        digits <--. 0;
        digit_counter <--. 0;
    ]);
    ( Process_Digits, [
      when_ (digit_counter.value ==:. number_of_inputs) (* force to second digit *)
        [sm.set_next Done];
      when_ rx_strobe [ (* we have not seen a 9 yet*)
        digit_counter <-- digit_counter.value +:. 1;
        recursive_digit_fill digits_needed
    ]]);
    (Done, [
      when_ rx_strobe [
        if_ (rx_byte ==: of_char '\n')
          [sm.set_next Idle; answer <-- answer.value +: uresize current_voltage answer_width]
          [sm.set_next Error] (* this should have been the end of the line so we error out *)
      ]
    ]);
    (Error, []) (* lock here forever - all LEDs are on - this happens if the number_of_inputs var does not match the actual inputs *)
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
      output "LED2" (sm.is Process_Digits |: sm.is Error);
      output "LED3" (sm.is Done |: sm.is Error);
      output "LED4" (sm.is Error |: sm.is Error);
    ]
    
  

