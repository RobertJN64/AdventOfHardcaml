let read_lines filename =
  let ic = open_in filename in
  let rec loop acc =
    try
      loop (input_line ic :: acc)
    with End_of_file ->
      close_in ic;
      List.rev acc
  in
  loop []

let write_lines filename lines =
  let oc = open_out filename in
  List.iter (fun s -> output_string oc s; output_char oc '\n') lines;
  close_out oc

let () =
  let input_file  = "Days/Day06a/Day06a_raw_input.txt" in
  let output_file = "Days/Day06a/Day06a_input.txt" in

  let lines = read_lines input_file in

  (* Pad all lines to equal width *)
  let max_len =
    List.fold_left (fun acc s -> max acc (String.length s)) 0 lines
  in
  let max_len = max_len + 1 in (* forces padding at end of each string *)

  let padded =
    List.map
      (fun s ->
        if String.length s < max_len then
          s ^ String.make (max_len - String.length s) ' '
        else s)
      lines
  in

  (* Build output *)
  let output =
    let acc = ref [] in
    for col = 0 to max_len - 1 do
      let chars = List.map (fun line -> line.[col]) padded in
      if List.exists ((<>) ' ') chars then
        acc := (String.of_seq (List.to_seq chars)) :: !acc
      else
        acc := "S" :: !acc (* add trigger char to start computation *)
    done;
    List.rev !acc
  in

  write_lines output_file output
