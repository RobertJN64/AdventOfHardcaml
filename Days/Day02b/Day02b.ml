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

let day02b () =
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
  let repeated_length len number_of_groups =
    let group i = 
      let hi = (len*4*(i+1) - 1) in
      let lo = (len*4*i) in
      select id_bcd hi lo in

    let group_0 = group 0 in

    (* all groups equal to group 0 *)
    let groups_equal =
      List.init (number_of_groups - 1) (fun i ->
        group_0 ==: group (i + 1)
      )
      |> List.fold_left ( &: ) vdd
    in

    (* rest of the signal above repeated region must be zero *)
    let rest_zero =
      if len*4*number_of_groups = width id_bcd then
        vdd
      else
        let rest = select id_bcd ((width id_bcd) - 1) (len*4*number_of_groups) in
        rest ==:. 0
    in

    (* repeated region must not start with 0 *)
    let leading_nonzero =
      select id_bcd (len*4 - 1) (len*4 - 4) <>:. 0
    in

    groups_equal &: rest_zero &: leading_nonzero
  in
   
  (* check all length patterns *)
  let max_ng = (width id_bcd)/4 in
  let repeated =
    List.init (max_ng-1) (fun i -> i + 2) (* current_ng = 2 .. max_ng *)
    |> List.fold_left
        (fun acc current_ng ->
          let max_len = (width id_bcd) / (4 * current_ng) in
          List.init max_len (fun i -> i + 1) (* len = 1 .. max_len *)
          |> List.fold_left
              (fun acc len ->
                acc |: repeated_length len current_ng
              )
              acc
        )
        gnd
  in

  let _ = repeated -- "rp_val" in
  let _ = id_bcd -- "id_bcd" in


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
    
  

