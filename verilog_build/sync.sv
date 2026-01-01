module sync (
    input  logic clock,
    input  logic reset,
    input  logic rx_async,
    output logic rx_sync
);

    // Two flip-flop synchronizer
    logic middle;
    
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            middle <= 1'b1;
            rx_sync <= 1'b1;
        end
        else begin
            middle <= rx_async;
            rx_sync <= middle;
        end
    end

endmodule