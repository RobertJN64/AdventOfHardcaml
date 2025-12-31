open Hardcaml
open Signal

module Binary_to_BCD = struct
  module I = struct
    type 'a t = {
      binary_val : 'a;
    } [@@deriving sexp_of, hardcaml]
  end

  module O = struct
    type 'a t = {
      bcd_val : 'a;
    } [@@deriving sexp_of, hardcaml]
  end

  let bcd_digits_for_bits bits =
  Int.of_float
    (Float.ceil
       (Float.of_int bits *. (log10 2.0)))

  let create ({binary_val} : _ I.t) =
    let bits = width binary_val in
    let digits = bcd_digits_for_bits bits in

    let bcd_width = digits * 4 in
    let zero_bcd = zero bcd_width in

    (* One iteration of double-dabble *)
    let step bcd bit =
      let adjusted =
        concat_msb (
          List.init digits (fun i ->
            let d = select bcd ((digits - i) * 4 - 1) ((digits - i - 1) * 4) in
            mux2 (d >=:. 5) (d +:. 3) d
          )
        )
      in
      let shifted = (adjusted @: bit) in
      select shifted (bcd_width - 1) 0
    in

    let bcd_val = List.fold_left step zero_bcd (bits_msb binary_val) in
    {O.bcd_val}

end

