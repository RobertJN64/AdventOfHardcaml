open Hardcaml
open Signal

module UART_Decoder = struct
  module I = struct
    type 'a t = {
      clock : 'a;
      reset : 'a;
      rx    : 'a;
    } [@@deriving sexp_of, hardcaml]
  end

  module O = struct
    type 'a t = {
      rx_byte   : 'a;
      rx_strobe : 'a;
    } [@@deriving sexp_of, hardcaml]
  end

  module States = struct
    type t =
      | Idle
      | Offset_Start
      | RCV_Bit
      | Done
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

  let create ({clock; reset; rx} : _ I.t) =
    let open Always in
    let spec = Reg_spec.create ~clock ~reset () in
    let bit_counter = Variable.reg spec ~width:4 in
    let _ = bit_counter.value -- "bit_counter" in
    

    let sm = State_machine.create (module States) spec in
    compile [ sm.switch [
      ( Idle, [
        unless rx [sm.set_next Offset_Start; bit_counter <-- zero 4]
        ]);
      ( Offset_Start, [sm.set_next RCV_Bit]);
      ( RCV_Bit, [if_ (bit_counter.value ==: Signal.of_int ~width:4 8)
          [sm.set_next Done]
          [bit_counter <-- bit_counter.value +: Signal.one 4]
        ]);
      ( Done, [sm.set_next Done])
    ]];

    let _rx = rx in
    
    let counter_next = Signal.wire 25 in
    let counter = Signal.reg spec counter_next in
    let () = Signal.assign counter_next Signal.(counter +: (Signal.of_int ~width:25 1)) in
    { O.rx_byte=counter; O.rx_strobe=sm.is Done }

end
