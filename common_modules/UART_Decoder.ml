open Hardcaml

module UART_Decoder = struct
  module I = struct
    type 'a t = {
      clk : 'a;
      rst : 'a    
    } [@@deriving sexp_of, hardcaml]
  end

  module O = struct
    type 'a t = {
      counter : 'a;
    } [@@deriving sexp_of, hardcaml]
  end

  

  let create ({clk; rst} : _ I.t) =
    let spec = Reg_spec.create ~clock:clk ~clear:rst () in
    let counter_next = Signal.wire 25 in
    let counter = Signal.reg spec counter_next in
    let () = Signal.assign counter_next Signal.(counter +: (Signal.of_int ~width:25 1)) in
    { O.counter }
end
