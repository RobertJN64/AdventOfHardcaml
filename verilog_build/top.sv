module top (
    input logic CLK,
    input logic SW1, // used as reset
    input logic RX, // UART in

    // 7 seg
    output logic S1_A, S1_B, S1_C, S1_D, S1_E, S1_F, S1_G,
    output logic S2_A, S2_B, S2_C, S2_D, S2_E, S2_F, S2_G
);

    logic [6:0] ss1_A_G;
    logic [6:0] ss2_A_G;
    assign ss1_A_G = {S1_A, S1_B, S1_C, S1_D, S1_E, S1_F, S1_G};
    assign ss2_A_G = {S2_A, S2_B, S2_C, S2_D, S2_E, S2_F, S2_G};
    solution sol(.clock(CLK), .reset(SW1), .RX(RX), .ss1_A_G(ss1_A_G), .ss2_A_G(ss2_A_G));

endmodule
