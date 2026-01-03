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
    let bit_timer_max = 217 - 1 in (* 25 MHz / 115200 baud *)
    let bit_timer_offset = bit_timer_max/2 in (* half of max to sample in middle of byte*)
    let bit_counter_max = 8 in

    let spec = Reg_spec.create ~clock ~reset () in
    let bit_counter = Variable.reg spec ~width:(num_bits_to_represent bit_counter_max) in (* number of bits rcv in current packet *)
    let _ = bit_counter.value -- "bit_counter" in
    let bit_timer = Variable.reg spec ~width:(num_bits_to_represent bit_timer_max) in (* triggers sampling in the middle of a packet *)
    let _ = bit_timer.value -- "bit_timer" in

    let rx_byte = Variable.reg spec ~width:8 in
    

    let sm = State_machine.create (module States) spec in
    compile [ sm.switch [
      ( Idle, [
        unless rx [sm.set_next Offset_Start; bit_counter <--. 0; bit_timer <--. 0]
        ]);
      ( Offset_Start, [
        if_ (bit_timer.value ==:. bit_timer_offset) (* if the bit timer triggers *)
          [sm.set_next RCV_Bit; bit_timer <--. 0] (* goto RCV_Bit *)
          [bit_timer <-- bit_timer.value +:. 1] (* else, advance the bit timer *)
        ]);
      ( RCV_Bit, [
        if_ (bit_timer.value ==:. bit_timer_max) (* if the bit timer triggers *)
          [bit_timer <--. 0; (* zero out the bit timer, shift in one bit *)
            if_ (bit_counter.value ==:. bit_counter_max) (* if on the final bit *)
              [sm.set_next Done] (* goto Done *)
              [bit_counter <-- bit_counter.value +:. 1; rx_byte <-- rx @: select rx_byte.value 7 1] (* else, advance the bit counter and shift in one bit *)
          ]
          [bit_timer <-- bit_timer.value +:. 1] (* else, advance the bit timer *)
        ]);
      ( Done, [sm.set_next Idle]) (* done state for one cycle to pulse the strobe *)
    ]];

    { O.rx_byte=rx_byte.value; O.rx_strobe=sm.is Done }

end
