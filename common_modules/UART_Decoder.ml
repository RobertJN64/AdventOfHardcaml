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
    let bit_timer_width = num_bits_to_represent bit_timer_max in
    let bit_counter_max = 8 in
    let bit_counter_width = num_bits_to_represent bit_counter_max in
    let rx_byte_width = 8 in

    let spec = Reg_spec.create ~clock ~reset () in
    let bit_counter = Variable.reg spec ~width:bit_counter_width in (* number of bits rcv in current packet *)
    let _ = bit_counter.value -- "bit_counter" in
    let bit_timer = Variable.reg spec ~width:bit_timer_width in (* triggers sampling in the middle of a packet *)
    let _ = bit_timer.value -- "bit_timer" in

    let rx_byte = Variable.reg spec ~width:rx_byte_width in
    

    let sm = State_machine.create (module States) spec in
    compile [ sm.switch [
      ( Idle, [
        unless rx [sm.set_next Offset_Start; bit_counter <-- zero bit_counter_width; bit_timer <-- zero bit_timer_width]
        ]);
      ( Offset_Start, [
        if_ (bit_timer.value ==: of_int ~width:bit_timer_width bit_timer_offset) (* if the bit timer triggers *)
          [sm.set_next RCV_Bit; bit_timer <-- zero bit_timer_width] (* goto RCV_Bit *)
          [bit_timer <-- bit_timer.value +: one bit_timer_width] (* else, advance the bit timer *)
        ]);
      ( RCV_Bit, [
        if_ (bit_timer.value ==: of_int ~width:bit_timer_width bit_timer_max) (* if the bit timer triggers *)
          [bit_timer <-- zero bit_timer_width; (* zero out the bit timer, shift in one bit *)
            if_ (bit_counter.value ==: of_int ~width:bit_counter_width bit_counter_max) (* if on the final bit *)
              [sm.set_next Done] (* goto Done *)
              [bit_counter <-- bit_counter.value +: one bit_counter_width; rx_byte <-- rx @: select rx_byte.value 7 1] (* else, advance the bit counter and shift in one bit *)
          ]
          [bit_timer <-- bit_timer.value +: one bit_timer_width] (* else, advance the bit timer *)
        ]);
      ( Done, [sm.set_next Idle]) (* done state for one cycle to pulse the strobe *)
    ]];

    { O.rx_byte=rx_byte.value; O.rx_strobe=sm.is Done }

end
