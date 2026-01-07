open AdventLib
open Hardcaml
open Signal
open Always

module States = struct
    type t =
      | RCV_X_first_pass
      | RCV_Y_first_pass
      | First_pass
      | RCV_X_second_pass
      | RCV_Y_second_pass
      | Second_pass_primary
      | Second_pass_secondary
      | RCV_X_third_pass
      | RCV_Y_third_pass
      | Third_pass
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

let day09b () =
  let clock = input "clock" 1 in
  let reset = input "reset" 1 in
  let rx = input "rx" 1 in

  let spec = Reg_spec.create ~clock ~reset () in
  
  let udout = UART_Decoder.UART_Decoder.create {clock; reset; rx} in
  let rx_strobe = udout.rx_strobe in
  let rx_byte = udout.rx_byte in

  let sm = State_machine.create (module States) spec in

  (* note - this relies on the input having a large horizontal cut-in like my input did - inputs with a vertical cut in would need minor code changes *)
  let coord_bit_width = 18 in (* update these constants to support input *)
  let distance_threshold = 50000 in (* line distance to detect interior corners *)
  let y_center_thresh = 50000 in (* corners should fall on either side of this line *)
  let corner_x = Variable.reg spec ~width:coord_bit_width in
  let upper_corner_y = Variable.reg spec ~width:coord_bit_width in
  let lower_corner_y = Variable.reg spec ~width:coord_bit_width in
  let upper_y_lim = Variable.reg spec ~width:coord_bit_width in
  let lower_y_lim = Variable.reg spec ~width:coord_bit_width in

  let active_x_coord = Variable.reg spec ~width:coord_bit_width in
  let active_y_coord = Variable.reg spec ~width:coord_bit_width in
  let last_x_coord = Variable.reg spec ~width:coord_bit_width in
  let last_y_coord = Variable.reg spec ~width:coord_bit_width in
  let second_point = Variable.reg spec ~width:1 in

  let answer = Variable.reg spec ~width:(coord_bit_width * 2) in

  let abs_signed (x : Signal.t) =
    mux2 (x <+. 0) (zero (width x) -: x) x
  in

  let _ = rx_strobe -- "rx_strobe" in
  let _ = rx_byte -- "rx_byte" in
  let _ = corner_x.value -- "corner_x" in
  let _ = upper_corner_y.value -- "upper_corner_y" in
  let _ = lower_corner_y.value -- "lower_corner_y" in
  let _ = upper_y_lim.value -- "upper_y_lim" in
  let _ = lower_y_lim.value -- "lower_y_lim" in
  let _ = last_x_coord.value -- "last_x_coord" in
  let _ = last_y_coord.value -- "last_y_coord" in
  let _ = active_x_coord.value -- "active_x_coord" in
  let _ = active_y_coord.value -- "active_y_coord" in

  let last_coord_valid = (last_x_coord.value <>:. 0) &: (last_y_coord.value <>:. 0) in
  let distance = abs_signed ((active_x_coord.value -: last_x_coord.value) +: (active_y_coord.value -: last_y_coord.value)) in

  let shift_in_digit prev_val = (select (prev_val *: of_int ~width:4 10) (coord_bit_width-1) 0) +: uresize (rx_byte -: of_char '0') coord_bit_width in

  compile [ sm.switch [
    ( RCV_X_first_pass, [ when_ rx_strobe [
      if_ (rx_byte ==: of_char '\n') [ (* double newline, so moving onto second pass*)
        sm.set_next RCV_X_second_pass;
        last_x_coord <--. 0; last_y_coord <--. 0;
        active_x_coord <--. 0; active_y_coord <--. 0;
        upper_y_lim <--. y_center_thresh * 2;
      ] [
        if_ (rx_byte ==: of_char ',')
          [sm.set_next RCV_Y_first_pass; active_y_coord <--. 0]
          [active_x_coord <-- shift_in_digit active_x_coord.value]
    ]]]);
    ( RCV_Y_first_pass, [ when_ rx_strobe [
        if_ (rx_byte ==: of_char '\n')
          [sm.set_next First_pass]
          [active_y_coord <-- shift_in_digit active_y_coord.value]
    ]]);
    ( First_pass, [
      sm.set_next RCV_X_first_pass; active_x_coord <--. 0;
      last_x_coord <-- active_x_coord.value; last_y_coord <-- active_y_coord.value;
      when_ ((distance >:. distance_threshold) &: (last_coord_valid)) [
        if_ (second_point.value) [
          corner_x <-- last_x_coord.value;
          if_ (active_y_coord.value >:. y_center_thresh) [
            upper_corner_y <-- active_y_coord.value;
          ][
            lower_corner_y <-- active_y_coord.value;
          ]
        ] [
          second_point <--. 1;
          if_ (last_y_coord.value >:. y_center_thresh) [
            upper_corner_y <-- last_y_coord.value;
          ][
            lower_corner_y <-- last_y_coord.value;
          ]
        ]
   ]]);
   ( RCV_X_second_pass, [ when_ rx_strobe [
      if_ (rx_byte ==: of_char '\n') [ (* double newline, so moving onto third pass*)
        sm.set_next RCV_X_third_pass;
        last_x_coord <--. 0; last_y_coord <--. 0;
        active_x_coord <--. 0; active_y_coord <--. 0;
      ] [
        if_ (rx_byte ==: of_char ',')
          [sm.set_next RCV_Y_second_pass; active_y_coord <--. 0]
          [active_x_coord <-- shift_in_digit active_x_coord.value]
    ]]]);
    ( RCV_Y_second_pass, [ when_ rx_strobe [
        if_ (rx_byte ==: of_char '\n')
          [sm.set_next Second_pass_primary]
          [active_y_coord <-- shift_in_digit active_y_coord.value]
    ]]);
    ( Second_pass_primary, [
      sm.set_next Second_pass_secondary;
      when_ (((active_x_coord.value <: corner_x.value) &: (corner_x.value <: last_x_coord.value)) |: 
             ((active_x_coord.value >: corner_x.value) &: (corner_x.value >: last_x_coord.value)) &: last_coord_valid) [
        if_ (active_y_coord.value >:. y_center_thresh) [
          when_ (active_y_coord.value <: upper_y_lim.value) [upper_y_lim <-- active_y_coord.value]
        ] [
          when_ (active_y_coord.value >: lower_y_lim.value) [lower_y_lim <-- active_y_coord.value]
        ];
        if_ (last_y_coord.value >:. y_center_thresh) [
          when_ (last_y_coord.value <: upper_y_lim.value) [upper_y_lim <-- last_y_coord.value]
        ] [
          when_ (last_y_coord.value >: lower_y_lim.value) [lower_y_lim <-- last_y_coord.value]
        ]
    ]]);
    ( Second_pass_secondary, [
      sm.set_next RCV_X_second_pass; active_x_coord <--. 0;
      last_x_coord <-- active_x_coord.value; last_y_coord <-- active_y_coord.value;
      when_ (((active_x_coord.value <: corner_x.value) &: (corner_x.value <: last_x_coord.value)) |: 
             ((active_x_coord.value >: corner_x.value) &: (corner_x.value >: last_x_coord.value)) &: last_coord_valid) [
        if_ (last_y_coord.value >:. y_center_thresh) [
          when_ (last_y_coord.value <: upper_y_lim.value) [upper_y_lim <-- last_y_coord.value]
        ] [
          when_ (last_y_coord.value >: lower_y_lim.value) [lower_y_lim <-- last_y_coord.value]
        ]
    ]]);
    ( RCV_X_third_pass, [ when_ rx_strobe [
      if_ (rx_byte ==: of_char ',')
        [sm.set_next RCV_Y_third_pass; active_y_coord <--. 0]
        [active_x_coord <-- shift_in_digit active_x_coord.value]
    ]]);
    ( RCV_Y_third_pass, [ when_ rx_strobe [
        if_ (rx_byte ==: of_char '\n')
          [sm.set_next Third_pass]
          [active_y_coord <-- shift_in_digit active_y_coord.value]
    ]]);
    ( Third_pass, [
      sm.set_next RCV_X_third_pass; active_x_coord <--. 0;
      if_ (active_y_coord.value >:. y_center_thresh) [
        unless (active_y_coord.value >: upper_y_lim.value) [
          let width = (abs_signed (corner_x.value -: active_x_coord.value)) +:. 1 in
          let height = (abs_signed (upper_corner_y.value -: active_y_coord.value)) +:. 1 in
          let area = width *: height in
          when_ (area >: answer.value) [answer <-- area];
        ]
      ][
        unless (active_y_coord.value <: lower_y_lim.value) [
          let width = (abs_signed (corner_x.value -: active_x_coord.value)) +:. 1 in
          let height = (abs_signed (lower_corner_y.value -: active_y_coord.value)) +:. 1 in
          let area = width *: height in
          when_ (area >: answer.value) [answer <-- area];
        ]
      ];
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
      output "LED1" (sm.is RCV_X_first_pass);
      output "LED2" (sm.is RCV_X_second_pass);
      output "LED3" (sm.is RCV_X_third_pass);
      output "LED4" gnd
    ]
    
  

