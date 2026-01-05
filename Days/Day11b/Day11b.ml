open AdventLib
open Hardcaml
open Signal
open Always

module States = struct
    type t =
      | RCV_node
      | RCV_child
      | Compute_Paths
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

let day11b () =
  let clock = input "clock" 1 in
  let reset = input "reset" 1 in
  let rx = input "rx" 1 in

  let spec = Reg_spec.create ~clock ~reset () in

  let udout = UART_Decoder.UART_Decoder.create {clock; reset; rx} in
  let rx_strobe = udout.rx_strobe in
  let rx_byte = udout.rx_byte in

  let sm = State_machine.create (module States) spec in

  let answer_width = 12 in
  let max_node_count = 15 in (* update these and constants below if larger input used *)
  let max_fanout = 7 in
  let node_id_width = num_bits_to_represent max_node_count in

  (* maps node_id to (paths_to_out, paths_to_out_with_dac, paths_to_out_with_fft, paths_to_out_with_both, [children_ids]) *)
  (* id 0 is null (always 0), id 1 is out (always 1), id 2 is you *)
  let node_array = Array.init (max_node_count) (fun _ ->
    (Variable.reg spec ~width:answer_width, 
     Variable.reg spec ~width:answer_width, 
     Variable.reg spec ~width:answer_width, 
     Variable.reg spec ~width:answer_width, 
     Array.init (max_fanout) (fun _ -> Variable.reg spec ~width:node_id_width))
  ) in
  (* node_array.(0) contains the null nodes, but they default to 0 anyway... *)
  let null_a, null_b, null_c, null_d, _ = node_array.(0) in
  let out_node, null_e, null_f, null_g, _ = node_array.(1) in
  let dac, dac_with_dac, dac_with_fft, dac_with_both, dac_children = node_array.(2) in
  let fft, fft_with_dac, fft_with_fft, fft_with_both, fft_children = node_array.(3) in
  let _, _, _, svr_node, _ = node_array.(4) in (* we care about paths that go through dac and fft *)

  let parent_node_id = Variable.reg spec ~width:node_id_width in
  let child_node_id = Variable.reg spec ~width:node_id_width in
  let fanout_counter = Variable.reg spec ~width:(num_bits_to_represent max_fanout) in
  let answer = Variable.reg spec ~width:answer_width in

  let shift_in_digit prev_val = (select (prev_val *: of_int ~width:4 10) (node_id_width-1) 0) +: uresize (rx_byte -: of_char '0') node_id_width in

  let set_child_id = List.concat (
    List.init (max_node_count) (fun p ->
      List.init (max_fanout) (fun c ->
        let parent_match = parent_node_id.value ==:. p in
        let child_match = fanout_counter.value ==:. c in
        let selected  = parent_match &: child_match in

        let _, _, _, _, child_nodes = node_array.(p) in

        when_ selected [
          child_nodes.(c) <-- child_node_id.value
        ]
      )
    )
  ) in

  let value_of_node (select: (Variable.t -> Variable.t -> Variable.t -> Variable.t -> Variable.t)) node_id =
    mux node_id
      (Array.to_list node_array
      |> List.map (fun (a, b, c, d, _) ->
            (select a b c d).value))
  in

  let value_of_node_out = value_of_node (fun a _ _ _ -> a) in
  let value_of_node_dac = value_of_node (fun _ b _ _ -> b) in
  let value_of_node_fft = value_of_node (fun _ _ c _ -> c) in
  let value_of_node_both = value_of_node (fun _ _ _ d -> d) in

  let children_sum children value_of_node =
      Array.fold_left
        (fun acc (child: Variable.t) -> acc +: value_of_node child.value)
        (zero answer_width)
        children
    in

  let update_nodes = List.concat(List.init (max_node_count - 4) (fun raw_node_id ->
    let true_node_id = raw_node_id + 4 in
    let count_out, count_dac, count_fft, count_both, children = node_array.(true_node_id) in 

    [count_out  <-- children_sum children value_of_node_out;
     count_dac  <-- children_sum children value_of_node_dac;
     count_fft  <-- children_sum children value_of_node_fft;
     count_both <-- children_sum children value_of_node_both;]
  )) in

  (* this is where the with_fft and with_dac transitions happen - we also have to asssign to all the null nodes... *)
  let update_special_nodes = [
    dac <--. 0;
    dac_with_dac <-- children_sum dac_children value_of_node_out;
    dac_with_fft <--. 0;
    dac_with_both <-- children_sum dac_children value_of_node_fft;
    fft <--. 0;
    fft_with_dac <--. 0;
    fft_with_fft <-- children_sum fft_children value_of_node_out;
    fft_with_both <-- children_sum fft_children value_of_node_dac;
    null_a <--. 0; null_b <--. 0; null_c <--. 0; null_d <--. 0; null_e <--. 0; null_f <--. 0; null_g <--. 0
  ] in


  compile [ sm.switch [
    ( RCV_node, [when_ rx_strobe [
      if_ (rx_byte ==: of_char 'S') [ (* trigger to start processing inputs *)
        sm.set_next Compute_Paths
      ][
        unless (rx_byte ==: of_char ':') [ (* throw out the : *)
          if_ (rx_byte ==: of_char ' ') [
            sm.set_next RCV_child;
            child_node_id <--. 0;
            fanout_counter <--. 0
          ] [
            parent_node_id <-- shift_in_digit parent_node_id.value
    ]]]]]);
    ( RCV_child, [when_ rx_strobe [
      if_ (rx_byte ==: of_char '\n') ( (* finished a child and entire line *)
        set_child_id @ [
        sm.set_next RCV_node;
        parent_node_id <--. 0
      ])[
        if_ (rx_byte ==: of_char ' ') ( (* finished a child, but not the entire line *)
          set_child_id @ [ 
          child_node_id <--. 0;
          fanout_counter <-- fanout_counter.value +:. 1
        ])[
          child_node_id <-- shift_in_digit child_node_id.value
      ]]]]);
    ( Compute_Paths, ([
      out_node <--. 1;
      answer <-- svr_node.value;
    ] @ update_nodes @ update_special_nodes
    ))
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
      output "LED1" (sm.is RCV_node);
      output "LED2" (sm.is RCV_child);
      output "LED3" (sm.is Compute_Paths);
      output "LED4" gnd
    ]
    
  

