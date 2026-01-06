open AdventLib
open Hardcaml
open Signal
open Always

module States = struct
    type t =
      | RCV_Lights
      | RCV_Buttons
      | Discard
      | Compute
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

let day10a () =
  let clock = input "clock" 1 in
  let reset = input "reset" 1 in
  let rx = input "rx" 1 in

  let spec = Reg_spec.create ~clock ~reset () in

  let max_num_lights = 10 in (* more than 10 lights not currently supported in the string decoding logic *)
  let max_num_buttons = 15 in

  let udout = UART_Decoder.UART_Decoder.create {clock; reset; rx} in
  let rx_strobe = udout.rx_strobe in
  let rx_byte = udout.rx_byte in

  let sm = State_machine.create (module States) spec in
  let pattern = Variable.reg spec ~width:max_num_lights in (* the [.##.] pattern *)
  let buttons = Array.init (max_num_buttons) (fun _ ->
    Variable.reg spec ~width:max_num_lights
  ) in
  let button_toggle_pattern = Variable.reg spec ~width:max_num_buttons in
  let active_button_id = Variable.reg spec ~width:(num_bits_to_represent max_num_buttons) in
  let active_button_pattern = Variable.reg spec ~width:max_num_lights in
  let best_solution = Variable.reg spec ~width:(num_bits_to_represent max_num_buttons) in
  let next_light_flag = Variable.reg spec ~width:max_num_lights in

  let answer = Variable.reg spec ~width:12 in

  let reset_all_button_patterns = List.init (max_num_buttons) (fun idx ->
    buttons.(idx) <--. 0
  ) in

  let set_button_pattern = List.init (max_num_buttons) (fun idx ->
    let selected = active_button_id.value ==:. idx in
    when_ selected [buttons.(idx) <-- active_button_pattern.value]
  ) in

  let get_flag_by_bit selector =
    let flags = Array.init max_num_lights (fun i -> of_int ~width:max_num_lights (1 lsl i)) in
    mux selector (Array.to_list flags)
  in

  let pattern_cost =
    let bits = List.init (width button_toggle_pattern.value) (fun i -> uresize (select button_toggle_pattern.value i i) (num_bits_to_represent max_num_buttons)) in
    List.fold_left (fun acc b -> acc +: b) (zero (num_bits_to_represent max_num_buttons)) bits
  in

  let button_pattern_output = 
    let active_patterns = List.init (max_num_buttons) (fun i -> mux2 (select button_toggle_pattern.value i i) (buttons.(i).value) (zero max_num_lights) ) in
    List.fold_left (fun acc b -> acc ^: b) (zero max_num_lights) active_patterns
  in

  let _ = button_toggle_pattern.value -- "btp_value" in
  let _ = button_pattern_output -- "btp_out" in
  let _ = pattern_cost -- "btp_cost" in
  let _ = pattern.value -- "target" in
  let _ = best_solution.value -- "best" in
  for idx = 0 to max_num_buttons - 1 do
    let name = Printf.sprintf "button_%d" idx in
    let _ = buttons.(idx).value -- name in
    ()
  done;
  
  compile [ sm.switch [
    ( RCV_Lights, [when_ rx_strobe [
      when_ (rx_byte ==: of_char '[') [next_light_flag <--. 1]; (* reset the light flag to bit 0 *)
      unless ((rx_byte ==: of_char '[') |: (rx_byte ==: of_char ']')) [(* throw out these chars*)
        if_ (rx_byte ==: of_char ' ') (
          [sm.set_next RCV_Buttons; active_button_id <--. 0] @ reset_all_button_patterns
        )[
          next_light_flag <-- sll next_light_flag.value 1; (* the next rcv char will shift higher up in the pattern *)
          when_ (rx_byte ==: of_char '#')
            [pattern <-- (pattern.value |: next_light_flag.value)]
    ]]]]);
    ( RCV_Buttons, [when_ rx_strobe [
      if_ (rx_byte ==: of_char '{') [
        sm.set_next Discard
      ] [
        if_ (rx_byte ==: of_char '(') [
          active_button_pattern <--. 0
        ] [
          if_ (rx_byte ==: of_char ')') ([
            active_button_id <-- active_button_id.value +:. 1] @ set_button_pattern
          ) [
            unless ((rx_byte ==: of_char ' ') |:  (rx_byte ==: of_char ',')) [ (* throw out these digits *)
              active_button_pattern <-- (active_button_pattern.value |: (get_flag_by_bit (rx_byte -: of_char '0')))
    ]]]]]]);
    ( Discard, [when_ rx_strobe [
      when_ (rx_byte ==: of_char '}') [sm.set_next Compute; button_toggle_pattern <--. 1; best_solution <--. max_num_buttons]
    ]]);
    ( Compute, [
      if_ (button_toggle_pattern.value ==:. 0) [ (* we have checked all patterns and wrapped back around *)
        answer <-- answer.value +: uresize best_solution.value (width answer.value);
        sm.set_next RCV_Lights; pattern <--. 0
      ] [
        button_toggle_pattern <-- button_toggle_pattern.value +:. 1;
        when_ ((button_pattern_output ==: pattern.value) &: (pattern_cost <: best_solution.value)) [
          best_solution <-- pattern_cost
    ]]]);
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
      output "LED1" (sm.is RCV_Lights);
      output "LED2" (sm.is RCV_Buttons);
      output "LED3" (sm.is Discard);
      output "LED4" (sm.is Compute)
    ]
    
  

