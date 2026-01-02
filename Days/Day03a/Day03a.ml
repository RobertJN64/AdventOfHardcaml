open AdventLib
open Hardcaml
open Signal
open Always

module States = struct
    type t =
      | Idle
      | First_Digit
      | Second_Digit
      | Done
      | Error
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

let day03a () =
  let clock = input "clock" 1 in
  let reset = input "reset" 1 in
  let rx = input "rx" 1 in

  let spec = Reg_spec.create ~clock ~reset () in

  let udout = UART_Decoder.UART_Decoder.create {clock; reset; rx} in
  let rx_strobe = udout.rx_strobe in
  let rx_byte = udout.rx_byte in

  let sm = State_machine.create (module States) spec in

  let first_digit = Variable.reg spec ~width:4 in
  let second_digit = Variable.reg spec ~width:4 in
  let number_of_inputs = 100 in
  let digit_counter_width = num_bits_to_represent number_of_inputs in
  let digit_counter = Variable.reg spec ~width:digit_counter_width in
  let current_voltage = (first_digit.value *: of_int ~width:4 10) +: uresize second_digit.value 8 in
  let answer_width = 16 in
  let answer = Variable.reg spec ~width:answer_width in
  
  let _cv_val = current_voltage -- "cv_val" in
  
  let rx_digit = select (rx_byte -: of_char '0') 3 0 in

  compile [ sm.switch [
    ( Idle, [
        sm.set_next First_Digit;
        first_digit <-- zero 4;
        second_digit <-- zero 4;
        digit_counter <-- zero digit_counter_width;
    ]);
    ( First_Digit, [
      when_ (digit_counter.value ==: of_int ~width:digit_counter_width number_of_inputs -: one digit_counter_width) (* force to second digit *)
        [sm.set_next Second_Digit];
      when_ rx_strobe [ (* we have not seen a 9 yet*)
        digit_counter <-- digit_counter.value +: one digit_counter_width;
        if_ (rx_digit ==: of_int ~width:4 9)
          [first_digit <-- rx_digit; second_digit <-- zero 4; sm.set_next Second_Digit]
          [if_ (rx_digit >: first_digit.value) (* this is better than anything we have seen *)
            [first_digit <-- rx_digit; second_digit <-- zero 4] (* now we need a new second digit *)
            [when_ (rx_digit >: second_digit.value) (* not a better first digit, but is a better second digit *)
              [second_digit <-- rx_digit]
    ]]]]);
    (Second_Digit, [
      when_ (digit_counter.value ==: of_int ~width:digit_counter_width number_of_inputs) (* force to done *)
        [sm.set_next Done];
      when_ rx_strobe [
        digit_counter <-- digit_counter.value +: one digit_counter_width;
        when_ (rx_digit >: second_digit.value) (* this is better than anything we have seen *)
          [second_digit <-- rx_digit]
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
  let mdd = MultiDigitDisplay.MultiDigitDisplay.create {clock; reset; digits=bin_to_bcd_val} 5 in
  
  Circuit.create_exn
    ~name:"solution"
    [
      output "ss1_A_G" mdd.ss1_A_G.seven_seg_A_G;
      output "ss2_A_G" mdd.ss2_A_G.seven_seg_A_G;
      output "LED1" (sm.is Idle |: sm.is Error);
      output "LED2" (sm.is First_Digit |: sm.is Error);
      output "LED3" (sm.is Second_Digit |: sm.is Error);
      output "LED4" (sm.is Done |: sm.is Error);
    ]
    
  

