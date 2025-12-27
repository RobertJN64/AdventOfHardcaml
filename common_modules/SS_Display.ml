open Hardcaml

module SS_Display = struct
  module I = struct
    type 'a t = {
      value : 'a;
    } [@@deriving sexp_of, hardcaml]
  end

  module O = struct
    type 'a t = {
      seven_seg_A_G : 'a;
    } [@@deriving sexp_of, hardcaml]
  end

  let choices = [
    Signal.of_int ~width:7 0b0000001;  (* 0 *)
    Signal.of_int ~width:7 0b1001111;  (* 1 *)
    Signal.of_int ~width:7 0b0010010;  (* 2 *)
    Signal.of_int ~width:7 0b0000110;  (* 3 *)
    Signal.of_int ~width:7 0b1001100;  (* 4 *)
    Signal.of_int ~width:7 0b0100100;  (* 5 *)
    Signal.of_int ~width:7 0b0100000;  (* 6 *)
    Signal.of_int ~width:7 0b0001111;  (* 7 *)
    Signal.of_int ~width:7 0b0000000;  (* 8 *)
    Signal.of_int ~width:7 0b0000100;  (* 9 *)
    Signal.of_int ~width:7 0b1111111;  (* 10 blank *)
    Signal.of_int ~width:7 0b1111111;  (* 11 blank *)
    Signal.of_int ~width:7 0b1111111;  (* 12 blank *)
    Signal.of_int ~width:7 0b1111111;  (* 13 blank *)
    Signal.of_int ~width:7 0b1111111;  (* 14 blank *)
    Signal.of_int ~width:7 0b1111110;  (* 15 minus sign *)
  ]
  
  let create (inputs : _ I.t) =
    let seven_seg_A_G = Signal.mux inputs.value choices in
    { O.seven_seg_A_G }
end
