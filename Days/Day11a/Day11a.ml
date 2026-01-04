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

let day11a () =
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

  (* maps node_id to (number_of_paths_to_out, [children_ids]) *)
  (* id 0 is null (always 0), id 1 is out (always 1), id 2 is you *)
  let node_array = Array.init (max_node_count) (fun _ ->
    (Variable.reg spec ~width:answer_width, Array.init (max_fanout) (fun _ -> Variable.reg spec ~width:node_id_width))
  ) in
  let null_node, _ = node_array.(0) in
  let out_node, _ = node_array.(1) in
  let you_node, _ = node_array.(2) in

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

        let _, child_nodes = node_array.(p) in

        when_ selected [
          child_nodes.(c) <-- child_node_id.value
        ]
      )
    )
  ) in

  let value_of_node node_id = mux node_id (List.map (fun ((count, _): Variable.t * 'a) -> count.value) (Array.to_list node_array)) in

  let update_nodes = List.init (max_node_count - 2) (fun raw_node_id ->
    let true_node_id = raw_node_id + 2 in
    let count, children = node_array.(true_node_id) in

    (* sum all children *)
    let children_sum =
      Array.fold_left
        (fun acc (child: Variable.t) -> acc +: value_of_node child.value)
        (zero answer_width)
        children
    in

    count <-- children_sum
  ) in

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
      null_node <--. 0;
      out_node <--. 1;
      answer <-- you_node.value;
    ] @ update_nodes
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
    
  

