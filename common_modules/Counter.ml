open Hardcaml

module Counter = struct
  module I = struct
    type 'a t = {
      clock : 'a;
      reset : 'a    
    } [@@deriving sexp_of, hardcaml]
  end

  module O = struct
    type 'a t = {
      counter : 'a;
    } [@@deriving sexp_of, hardcaml]
  end

  

  let create ({clock; reset} : _ I.t) =
    let spec = Reg_spec.create ~clock ~reset () in
    let counter_next = Signal.wire 25 in
    let counter = Signal.reg spec counter_next in
    let () = Signal.assign counter_next Signal.(counter +:. 1) in
    { O.counter }
end
