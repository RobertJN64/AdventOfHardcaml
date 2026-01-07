open AdventLib
open Hardcaml
open Signal
open Always

module States = struct
    type t =
      | Idle
      | RCV_range_lower
      | RCV_range_upper
      | Insert_ID
      | Sum
      | Done
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

let day05b () =
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
  let next_idx_to_insert = Variable.reg spec ~width:(num_bits_to_represent max_num_ranges) in
  let idx_to_read = Variable.reg spec ~width:(num_bits_to_represent max_num_ranges) in
  let new_low_id = Variable.reg spec ~width:id_bit_width in
  let new_high_id = Variable.reg spec ~width:id_bit_width in

  let answer = Variable.reg spec ~width:id_bit_width in

  let shift_in_digit prev_val = (select (prev_val *: of_int ~width:4 10) (id_bit_width-1) 0) +: uresize (rx_byte -: of_char '0') id_bit_width in

  let curr_low_id  = mux idx_to_read.value (List.map (fun ((low, _high): (Variable.t * Variable.t)) -> low.value ) (Array.to_list range_array)) in
  let curr_high_id = mux idx_to_read.value (List.map (fun ((_low, high): (Variable.t * Variable.t)) -> high.value) (Array.to_list range_array)) in

  let insert_range = List.init (max_num_ranges) (fun r ->
    let selected = next_idx_to_insert.value ==:. r in
    let lo, hi = range_array.(r) in
    when_ selected [lo <-- new_low_id.value; hi <-- new_high_id.value]
  ) in

  let del_range = List.init (max_num_ranges) (fun r ->
    let selected = idx_to_read.value ==:. r in
    let lo, hi = range_array.(r) in
    when_ selected [lo <--. 0; hi <--. 0]
  ) in

  compile [ sm.switch [
    ( Idle, [new_low_id <--. 0; new_high_id <--. 0; idx_to_read <--. 0; sm.set_next RCV_range_lower]);
    ( RCV_range_lower, [when_ rx_strobe [
      if_ (rx_byte ==: of_char '-') [
        sm.set_next RCV_range_upper;
      ] [
        if_ (rx_byte ==: of_char '\n') (* we recieve a newline when we expect lower part of range so we are now rcving ids *)
          [sm.set_next Sum]
          [new_low_id <-- shift_in_digit new_low_id.value]
    ]]]);
    ( RCV_range_upper, [when_ rx_strobe [
      if_ (rx_byte ==: of_char '\n') [
        sm.set_next Insert_ID;
      ] [
        new_high_id <-- shift_in_digit new_high_id.value
    ]]]);
    ( Insert_ID, [
      if_ (idx_to_read.value ==:. max_num_ranges) (
        insert_range @ [
        sm.set_next Idle;
        next_idx_to_insert <-- next_idx_to_insert.value +:. 1;
      ]) [ 
        idx_to_read <-- idx_to_read.value +:. 1;
        when_ ((new_low_id.value >=: curr_low_id) &: (new_high_id.value <=: curr_high_id))
          (del_range @ [new_low_id <-- curr_low_id; new_high_id <-- curr_high_id]);
        when_ ((new_low_id.value <=: curr_low_id) &: (new_high_id.value >=: curr_high_id))
          (del_range);
        when_ ((new_low_id.value <=: curr_low_id) &: (curr_low_id <=: new_high_id.value) &: (new_high_id.value <=: curr_high_id))
          (del_range @ [new_high_id <-- curr_high_id]);
        when_ ((curr_low_id <=: new_low_id.value) &: (new_low_id.value <=: curr_high_id) &: (curr_high_id <=: new_high_id.value))
          (del_range @ [new_low_id <-- curr_low_id]);
      ]
    ]);
    ( Sum, [
      if_ (idx_to_read.value ==:. max_num_ranges) [
        sm.set_next Done;
      ] [
        idx_to_read <-- idx_to_read.value +:. 1;
        when_ (curr_high_id <>:. 0) [
          answer <-- answer.value +: curr_high_id -: curr_low_id +:. 1;
        ]
      ]
    ]);
    (Done, []); (* stay here forever *)
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
      output "LED3" (sm.is Insert_ID);
      output "LED4" (sm.is Done)
    ]
    
  

