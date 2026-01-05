open AdventLib
open Hardcaml
open Signal
open Always

module States = struct
    type t =
      | RCV_ID_Start
      | RCV_ID_End
      | Check_IDs
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

let day02a () =
  let clock = input "clock" 1 in
  let reset = input "reset" 1 in
  let rx = input "rx" 1 in

  let spec = Reg_spec.create ~clock ~reset () in
  let id_width = num_bits_to_represent 99999999999 in
  let answer_width = num_bits_to_represent 99999999999 in

  let udout = UART_Decoder.UART_Decoder.create {clock; reset; rx} in
  let rx_strobe = udout.rx_strobe in
  let rx_byte = udout.rx_byte in

  let sm = State_machine.create (module States) spec in
  let current_id = Variable.reg spec ~width:id_width in
  let end_id = Variable.reg spec ~width:id_width in
  let answer = Variable.reg spec ~width:answer_width in

  let shift_in_digit prev_val = (select (prev_val *: of_int ~width:4 10) (id_width-1) 0) +: uresize (rx_byte -: of_char '0') id_width in

  let id_bcd = (Binary_to_BCD.Binary_to_BCD.create {binary_val=current_id.value}).bcd_val in

  (* checks if bin_to_bcd contains repeated pattern, ie: 00446446 *)
  let repeated_length len = 
    let first = select id_bcd (len*4-1) 0 in
    let second = select id_bcd (8*len-1) (len*4) in
    if (len*8 == width id_bcd) then (first ==: second) &: (select id_bcd (8*len-1) (8*len-4) <>:. 0)
    else
      let rest = select id_bcd ((width id_bcd)-1) (8*len) in
      (first ==: second) &: (rest ==:. 0) &: (select id_bcd (8*len-1) (8*len-4) <>:. 0) (* the matching section can't start wiht a 0 *)
  in
   
  (* check all length patterns from 1 to id_width/2*)
  let repeated =
    List.init ((width id_bcd)/8) (fun i -> i + 1)
    |> List.fold_left
        (fun acc len -> acc |: repeated_length len)
        gnd
  in

  let _rp_val = repeated -- "rp_val" in
  let _rp_val = id_bcd -- "id_bcd" in


  compile [ sm.switch [
    ( RCV_ID_Start, [when_ rx_strobe [
      if_ (rx_byte ==: of_char '-')
        [sm.set_next RCV_ID_End; end_id <--. 0]
        [current_id <-- shift_in_digit current_id.value]
    ]]);
    ( RCV_ID_End, [when_ rx_strobe [
      if_ ((rx_byte ==: of_char ',') |: (rx_byte ==: of_char '\n')) (* newline detects EOF *)
        [sm.set_next Check_IDs]
        [end_id <-- shift_in_digit end_id.value]
    ]]);
    ( Check_IDs, [
      if_ (current_id.value ==: end_id.value)
        [sm.set_next RCV_ID_Start; current_id <--. 0]
        [current_id <-- current_id.value +:. 1];
      when_ (repeated) [answer <-- answer.value +: current_id.value];
    ]);
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
      output "LED1" (sm.is RCV_ID_Start); (* should only start sending an ID in this state *)
      output "LED2" (sm.is RCV_ID_End);
      output "LED3" (sm.is Check_IDs);
      output "LED4" gnd;
    ]
    
  

