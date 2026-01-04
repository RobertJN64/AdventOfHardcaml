module SMap = Map.Make(String)
module ISet = Set.Make(Int)

let preassigned = [ ("null", 0); ("out", 1); ("you", 2) ]

let parse_line line =
  match String.split_on_char ':' line with
  | [lhs; rhs] ->
      let lhs = String.trim lhs in
      let rhs =
        rhs
        |> String.trim
        |> String.split_on_char ' '
        |> List.filter (fun s -> s <> "")
      in
      (lhs, rhs)
  | _ ->
      failwith ("Bad line: " ^ line)

let read_lines filename =
  let ic = open_in filename in
  let rec loop acc =
    match input_line ic with
    | line -> loop (line :: acc)
    | exception End_of_file ->
        close_in ic;
        List.rev acc
  in
  loop []

let collect_symbols parsed =
  parsed
  |> List.fold_left
       (fun acc (k, vs) -> k :: vs @ acc)
       []
  |> List.sort_uniq String.compare

let assign_ids symbols =
  let used =
    List.fold_left
      (fun s (_, id) -> ISet.add id s)
      ISet.empty
      preassigned
  in
  let rec next_free used n =
    if ISet.mem n used then next_free used (n + 1) else n
  in
  let (_, map) =
    List.fold_left
      (fun (used, map) sym ->
         match List.assoc_opt sym preassigned with
         | Some id ->
             (ISet.add id used, SMap.add sym id map)
         | None ->
             let id = next_free used 1 in
             (ISet.add id used, SMap.add sym id map))
      (used, SMap.empty)
      symbols
  in
  map


let write_output filename parsed id_map =
  let oc = open_out filename in
  let id s = SMap.find s id_map in
  List.iter
    (fun (k, vs) ->
       Printf.fprintf oc "%d:" (id k);
       List.iter (fun v -> Printf.fprintf oc " %d" (id v)) vs;
       output_char oc '\n')
    parsed;
  Printf.fprintf oc "S\n";
  close_out oc


let () =
  let input_file  = "Days/Day11a/Day11a_raw_input.txt" in
  let output_file = "Days/Day11a/Day11a_input.txt" in

  let lines   = read_lines input_file in
  let parsed  = List.map parse_line lines in
  let symbols = collect_symbols parsed in
  let id_map  = assign_ids symbols in

  write_output output_file parsed id_map