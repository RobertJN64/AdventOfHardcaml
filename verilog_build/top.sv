module top (
    input logic CLK,
    input logic SW1, // used as reset
    input logic RX, // UART in

    // 7 seg
    output logic S1_A, S1_B, S1_C, S1_D, S1_E, S1_F, S1_G,
    output logic S2_A, S2_B, S2_C, S2_D, S2_E, S2_F, S2_G,

    output logic LED1, LED2, LED3, LED4
);
    logic rx_sync;
    sync s(.clock(CLK), .reset(SW1), .rx_async(RX), .rx_sync(rx_sync));

    logic [6:0] ss1_A_G;
    logic [6:0] ss2_A_G;
    assign {S1_A, S1_B, S1_C, S1_D, S1_E, S1_F, S1_G} = ss1_A_G;
    assign {S2_A, S2_B, S2_C, S2_D, S2_E, S2_F, S2_G} = ss2_A_G;
    solution sol(.clock(CLK), .reset(SW1), .rx(rx_sync), .ss1_A_G(ss1_A_G), .ss2_A_G(ss2_A_G),
    .LED1(LED1), .LED2(LED2), .LED3(LED3), .LED4(LED4));

endmodule
