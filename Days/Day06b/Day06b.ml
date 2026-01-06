open AdventLib
open Hardcaml
open Signal
open Always

module States = struct
    type t =
      | Idle
      | RCV_Digit
      | Mul
      | Add
      | Finish
      | Wait_For_Newline
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

let day06b () =
  let clock = input "clock" 1 in
  let reset = input "reset" 1 in
  let rx = input "rx" 1 in

  let spec = Reg_spec.create ~clock ~reset () in

  let udout = UART_Decoder.UART_Decoder.create {clock; reset; rx} in
  let rx_strobe = udout.rx_strobe in
  let rx_byte = udout.rx_byte in

  let sm = State_machine.create (module States) spec in
  let answer_width = num_bits_to_represent 20000000000000 in
  let accumulator_width = num_bits_to_represent 9999 in

  let max_number_of_numbers = 7 in
  let number_counter = Variable.reg spec ~width:(num_bits_to_represent max_number_of_numbers) in
  let current_acc = Variable.reg spec ~width:accumulator_width in
  let current_sum_product = Variable.reg spec ~width:answer_width in
  let acc_array = Array.init (max_number_of_numbers) (fun _ ->
    Variable.reg spec ~width:accumulator_width
  ) in 

  let reset_all_accs = List.init (max_number_of_numbers) (fun idx ->
    acc_array.(idx) <--. 0
  ) in

  let set_acc = List.init (max_number_of_numbers) (fun idx ->
    let selected = number_counter.value ==:. idx in
    when_ selected [acc_array.(idx) <-- current_acc.value]
  ) in

  let selected_acc_value = 
    mux number_counter.value (List.map (fun (acc: Variable.t) -> acc.value) (Array.to_list acc_array))
  in

  let _ = current_sum_product.value -- "csp_value" in
  let _ = number_counter.value -- "num_counter_val" in
  for idx = 0 to max_number_of_numbers - 1 do
    let name = Printf.sprintf "acc_%d" idx in
    let _ = acc_array.(idx).value -- name in
    ()
  done;
 

  let answer = Variable.reg spec ~width:answer_width in

  let shift_in_digit prev_val = (select (prev_val *: of_int ~width:4 10) (accumulator_width-1) 0) +: uresize (rx_byte -: of_char '0') accumulator_width in

  compile [ sm.switch [
    ( Idle, reset_all_accs @ [ current_acc <--. 0; sm.set_next RCV_Digit; number_counter <--. 0]);
    ( RCV_Digit, [when_ rx_strobe [
      unless (rx_byte ==: of_char ' ') [
        if_ (rx_byte ==: of_char '+') (
          set_acc @ [
          current_sum_product <--. 0;
          sm.set_next Add;
        ]) [
          if_ (rx_byte ==: of_char '*') (
            set_acc @ [
            current_sum_product <--. 1; (* mul identity is 1 *)
            sm.set_next Mul;
          ]) [
            if_ (rx_byte ==: of_char '\n') (
              set_acc @ [
              number_counter <-- number_counter.value +:. 1;
              current_acc <--. 0;
            ]) [
              current_acc <-- shift_in_digit current_acc.value
    ]]]]]]);
    ( Add, [
      current_sum_product <-- current_sum_product.value +: uresize selected_acc_value answer_width;
      if_ (number_counter.value ==:. 0) [
        sm.set_next Finish;
      ] [
        number_counter <-- number_counter.value -:. 1;
    ]]);
    ( Mul, [
      current_sum_product <-- uresize (current_sum_product.value *: selected_acc_value) answer_width;
      if_ (number_counter.value ==:. 0) [
        sm.set_next Finish;
      ] [        
        number_counter <-- number_counter.value -:. 1;
    ]]);
    ( Finish, [
      answer <-- answer.value +: current_sum_product.value;
      sm.set_next Wait_For_Newline;
    ]);
    ( Wait_For_Newline, [when_ rx_strobe [ (* this discards the newline after the + or * *)
      when_ (rx_byte ==: of_char '\n') [sm.set_next Idle]
    ]]);
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
      output "LED1" (sm.is Idle);
      output "LED2" (sm.is RCV_Digit);
      output "LED3" (sm.is Add);
      output "LED4" (sm.is Mul)
    ]
    
  

