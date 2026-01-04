open AdventLib
open Hardcaml
open Signal
open Always

module States = struct
    type t =
      | RCV_range_lower
      | RCV_range_upper
      | RCV_id
      | Check_id
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

let day05a () =
  let clock = input "clock" 1 in
  let reset = input "reset" 1 in
  let rx = input "rx" 1 in

  let spec = Reg_spec.create ~clock ~reset () in

  let udout = UART_Decoder.UART_Decoder.create {clock; reset; rx} in
  let rx_strobe = udout.rx_strobe in
  let rx_byte = udout.rx_byte in

  let sm = State_machine.create (module States) spec in

  let max_num_ranges = 180 in (* update these and constants below if larger input used *)
  let id_bit_width = num_bits_to_represent 999999999999999 in

  let range_array = Array.init (max_num_ranges) (fun _ ->
    (Variable.reg spec ~width:id_bit_width, Variable.reg spec ~width:id_bit_width)
  ) in
  let active_range = Variable.reg spec ~width:(num_bits_to_represent max_num_ranges) in
  let id_to_check = Variable.reg spec ~width:id_bit_width in
  let answer = Variable.reg spec ~width:12 in

  let shift_in_digit prev_val = (select (prev_val *: of_int ~width:4 10) (id_bit_width-1) 0) +: uresize (rx_byte -: of_char '0') id_bit_width in

  let insert_id_lower = List.init (max_num_ranges) (fun r ->
    let selected  = active_range.value ==:. r in
    let lo, _ = range_array.(r) in
    when_ selected [lo <-- id_to_check.value]
  ) in

  let insert_id_upper = List.init (max_num_ranges) (fun r ->
    let selected  = active_range.value ==:. r in
    let _, hi = range_array.(r) in
    when_ selected [hi <-- id_to_check.value]
  ) in

  let id_in_any_range =
    Array.fold_left (fun acc ((lo, hi) : Variable.t * Variable.t) -> 
      acc |: ((id_to_check.value <=: hi.value) &: (id_to_check.value >=: lo.value))) (gnd) range_array
  in

  compile [ sm.switch [
    ( RCV_range_lower, [when_ rx_strobe [
      if_ (rx_byte ==: of_char '-') (
        insert_id_lower @ [
        sm.set_next RCV_range_upper;
        id_to_check <--. 0;
      ]) [
        if_ (rx_byte ==: of_char '\n') (* we recieve a newline when we expect lower part of range so we are now rcving ids *)
          [sm.set_next RCV_id]
          [id_to_check <-- shift_in_digit id_to_check.value]
    ]]]);
    ( RCV_range_upper, [when_ rx_strobe [
      if_ (rx_byte ==: of_char '\n') (
      insert_id_upper @ [
        sm.set_next RCV_range_lower;
        id_to_check <--. 0;
        active_range <-- active_range.value +:. 1
      ]) [
        id_to_check <-- shift_in_digit id_to_check.value
    ]]]);
    ( RCV_id, [ when_ rx_strobe [
      if_ (rx_byte ==: of_char '\n') [
        sm.set_next Check_id;
      ][
        id_to_check <-- shift_in_digit id_to_check.value
    ]]]);
    ( Check_id, [
      sm.set_next RCV_id;
      when_ (id_in_any_range) [answer <-- answer.value +:. 1];
      id_to_check <--. 0;
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
      output "LED1" (sm.is RCV_range_lower);
      output "LED2" (sm.is RCV_range_upper);
      output "LED3" (sm.is RCV_id);
      output "LED4" (sm.is Check_id)
    ]
    
  

