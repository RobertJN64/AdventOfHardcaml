open Hardcaml
open Signal

module MultiDigitDisplay = struct
  module I = struct
    type 'a t = {
      clock  : 'a;
      reset  : 'a;
      digits : 'a;
    } [@@deriving sexp_of, hardcaml]
  end

  module O = struct
    type 'a t = {
      ss1_A_G : 'a;
      ss2_A_G : 'a;
    } [@@deriving sexp_of, hardcaml]
  end
  
  let create ({clock; reset; digits} : _ I.t) =
    let open Always in
    let num_of_digits = width digits / 4 in
    let timer_width = 25 in 

    let spec = Reg_spec.create ~clock ~reset () in
    let timer_next = wire timer_width in
    let timer = reg spec timer_next in
    let () = assign timer_next (timer +:. 1) in

    let digit_counter = Variable.reg spec ~width:(num_bits_to_represent num_of_digits) in (* number of bits rcv in current packet *)
    let _ = digit_counter.value -- "mdd_state" in
    let _ = timer -- "mdd_timer" in

    compile [
      when_ (timer ==:. 0)
        [if_ (digit_counter.value ==:. num_of_digits-1)
          [digit_counter <--. 0]
          [digit_counter <-- digit_counter.value +:. 1]
        ]
    ];

    let slices = List.init (num_of_digits-1) (fun i ->
        let hi = (num_of_digits - i) * 4 - 1 in
        let lo = hi - 7 in
        select digits hi lo
      ) in

    let active_byte = mux digit_counter.value (of_int ~width:8 0xAA :: slices) in

    let ss1_A_G = SS_Display.SS_Display.create {value=(select active_byte 7 4)} in
    let ss2_A_G = SS_Display.SS_Display.create {value=(select active_byte 3 0)} in
    { O.ss1_A_G; O.ss2_A_G }
end
