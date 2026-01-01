module faulty_uart_edits (
    reset,
    clock,
    rx,
    rx_strobe,
    rx_byte
);

    input logic reset;
    input logic clock;
    input logic rx;
    output logic rx_strobe;
    output logic [7:0] rx_byte;

    logic [7:0] next_rx_byte;
    
    logic [3:0] next_bit_counter;
    logic [3:0] bit_counter;
    
    logic [7:0] next_bit_timer;
    logic [7:0] bit_timer;
    
    logic [1:0] IDLE;
    logic [1:0] RCV_BIT;
    logic [1:0] OFFSET_WAIT;
    logic [1:0] DONE;

    logic [1:0] next_fsm_state;
    logic [1:0] fsm_state;

    assign IDLE = 2'b00;
    assign OFFSET_WAIT = 2'b01;
    assign RCV_BIT = 2'b10;
    assign DONE = 2'b11;
    

    assign next_rx_byte = (fsm_state == RCV_BIT) ? ((bit_timer == 8'd217) ? (bit_counter == 4'd8 ? rx_byte : { rx, rx_byte[7:1] }) : rx_byte) : rx_byte;
    always @(posedge clock or posedge reset) begin
        if (reset)
            rx_byte <= 8'd0;
        else
            rx_byte <= next_rx_byte;
    end

    
    assign next_bit_counter = (fsm_state == IDLE) ? (rx ? bit_counter : 4'd0) : ((fsm_state == RCV_BIT) ? ((bit_timer == 8'd217) ? (bit_counter == 4'd8 ? bit_counter : (bit_counter + 4'd1)) : bit_counter) : bit_counter);
    always @(posedge clock or posedge reset) begin
        if (reset)
            bit_counter <= 4'd0;
        else
            bit_counter <= next_bit_counter;
    end

    assign next_bit_timer = (fsm_state == IDLE) ? (rx ? bit_timer : 8'd0) : ((fsm_state == OFFSET_WAIT) ? ((bit_timer == 8'd109) ? 8'd0 : (bit_timer + 8'd1)) : ((fsm_state == RCV_BIT) ? ((bit_timer == 8'd217) ? 8'd0 : (bit_timer + 8'd1)) : bit_timer));
    always @(posedge clock or posedge reset) begin
        if (reset)
            bit_timer <= 8'd0;
        else
            bit_timer <= next_bit_timer;
    end
    
    assign next_fsm_state = (fsm_state == IDLE) ? (rx ? fsm_state : OFFSET_WAIT) : (fsm_state == OFFSET_WAIT) ? ((bit_timer == 8'd109) ? RCV_BIT : fsm_state) : ((fsm_state == RCV_BIT) ? ((bit_timer == 8'd217) ? ((bit_counter == 4'd8) ? DONE : fsm_state) : fsm_state) : ((fsm_state == DONE) ? IDLE : fsm_state));
    always @(posedge clock or posedge reset) begin
        if (reset)
            fsm_state <= IDLE;
        else
            fsm_state <= next_fsm_state;
    end
    
    assign rx_strobe = DONE == fsm_state;
    

endmodule
