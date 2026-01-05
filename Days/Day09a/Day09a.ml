open AdventLib
open Hardcaml
open Signal
open Always

module States = struct
    type t =
      | RCV_X
      | RCV_Y
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

let day09a () =
  let clock = input "clock" 1 in
  let reset = input "reset" 1 in
  let rx = input "rx" 1 in

  let spec = Reg_spec.create ~clock ~reset () in

  let udout = UART_Decoder.UART_Decoder.create {clock; reset; rx} in
  let rx_strobe = udout.rx_strobe in
  let rx_byte = udout.rx_byte in

  let sm = State_machine.create (module States) spec in
  
  let coord_bit_width = 18 in (* update these constants to support input *)
  let max_number_of_coords = 500 in
  let idx_bit_width = (num_bits_to_represent max_number_of_coords) + 1 in

  let coord_counter = Variable.reg spec ~width:idx_bit_width in
  let active_coord = Variable.reg spec ~width:coord_bit_width in
  let a_idx = Variable.reg spec ~width:idx_bit_width in
  let b_idx = Variable.reg spec ~width:idx_bit_width in
  let answer = Variable.reg spec ~width:(coord_bit_width * 2) in

  let coord_array = Array.init (max_number_of_coords) (fun _ ->
    (Variable.reg spec ~width:coord_bit_width, Variable.reg spec ~width:coord_bit_width)
  ) in

  let shift_in_digit prev_val = (select (prev_val *: of_int ~width:4 10) (coord_bit_width-1) 0) +: uresize (rx_byte -: of_char '0') coord_bit_width in

  let coord_a_x = mux a_idx.value (List.map (fun ((x, _y): Variable.t * Variable.t) -> x.value) (Array.to_list coord_array)) -- "cax" in
  let coord_a_y = mux a_idx.value (List.map (fun ((_x, y): Variable.t * Variable.t) -> y.value) (Array.to_list coord_array)) -- "cay" in
  let coord_b_x = mux b_idx.value (List.map (fun ((x, _y): Variable.t * Variable.t) -> x.value) (Array.to_list coord_array)) -- "cbx" in
  let coord_b_y = mux b_idx.value (List.map (fun ((_x, y): Variable.t * Variable.t) -> y.value) (Array.to_list coord_array)) -- "cby" in

  let abs_signed (x : Signal.t) =
    mux2 (x <+. 0) (zero (width x) -: x) x
  in

  (* constantly compute the best area from the available coords *)
  let area = ((abs_signed (coord_a_x -: coord_b_x)) +:. 1) *: ((abs_signed (coord_a_y -: coord_b_y)) +:. 1) in

  compile [
    if_ ((a_idx.value ==: coord_counter.value) |: (a_idx.value ==: coord_counter.value -:. 1)) [
      a_idx <--. 0
    ] [
      if_ ((b_idx.value ==: coord_counter.value) |: (b_idx.value ==: coord_counter.value -:. 1)) [
        b_idx <--. 0;
        a_idx <-- a_idx.value +:. 1
      ] [
        b_idx <-- b_idx.value +:. 1
      ]
    ]
  ];

  compile [
    when_ (area >: answer.value) [
      answer <-- area;
    ]
  ];

  let set_x_coord = List.init (max_number_of_coords) (fun idx ->
    let selected  = coord_counter.value ==:. idx in
    let x, _y = coord_array.(idx) in
    when_ selected [x <-- active_coord.value]
  ) in

  let set_y_coord = List.init (max_number_of_coords) (fun idx ->
    let selected  = coord_counter.value ==:. idx in
    let _x, y = coord_array.(idx) in
    when_ selected [y <-- active_coord.value]
  ) in

  compile [ sm.switch [
    ( RCV_X, [ when_ rx_strobe [
        if_ (rx_byte ==: of_char ',')
          ([sm.set_next RCV_Y; active_coord <--. 0] @ set_x_coord)
          [active_coord <-- shift_in_digit active_coord.value]
   ]]);
    ( RCV_Y, [ when_ rx_strobe [
        if_ (rx_byte ==: of_char '\n')
          ([sm.set_next RCV_X; active_coord <--. 0; coord_counter <-- coord_counter.value +:. 1] @ set_y_coord)
          [active_coord <-- shift_in_digit active_coord.value]
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
      output "LED1" (sm.is RCV_X);
      output "LED2" (sm.is RCV_Y);
      output "LED3" gnd;
      output "LED4" gnd;
    ]
    
  

