`timescale 1ns / 10ps
/* verilator coverage_off */

module top_tb ();
  localparam CLK_PERIOD = 40ns;
  localparam SERIAL_BIT_PERIOD = 8680ns;  // 115200
  localparam CHECK_DELAY = 1ns;

  initial begin
    $dumpvars(0, top_tb);
  end

  string test_name;
  logic  CLK;
  logic SW1;
  logic RX;
  logic S1_A, S1_B, S1_C, S1_D, S1_E, S1_F, S1_G;
  logic S2_A, S2_B, S2_C, S2_D, S2_E, S2_F, S2_G;
  logic LED1, LED2, LED3, LED4;

  top DUT (.*);

  // clockgen
  always begin
    CLK = 0;
    #(CLK_PERIOD / 2.0);
    CLK = 1;
    #(CLK_PERIOD / 2.0);
  end

  task send_serial_packet(input logic [7:0] data);
    RX = 1'b0;
    #(SERIAL_BIT_PERIOD);
    for (int i = 0; i < 8; i++) begin
      RX = data[i];
      #(SERIAL_BIT_PERIOD);
    end
    RX = 1'b1;
    #(SERIAL_BIT_PERIOD);
  endtask

  task send_serial_file(input string filename);
    int fd;
    int c;
    fd = $fopen(filename, "r");
    if (fd == 0) begin
      $display("ERROR: Could not open file %s", filename);
      $finish;
    end
    while (!$feof(fd)) begin
      c = $fgetc(fd);  // read one character as integer
      if (c != -1) begin
        send_serial_packet(c[7:0]);
      end
    end
    $fclose(fd);
  endtask


  task reset_DUT();
    SW1 = 1'b1;
    #(CLK_PERIOD * 2);
    SW1 = 1'b0;
    #(CLK_PERIOD * 2);
  endtask

  initial begin
    test_name = "Power on reset";
    RX = 1'b1;
    reset_DUT();

    send_serial_file("tb_input.txt");

    #(CLK_PERIOD * 1000);

    $display("Answer %d\n", DUT.sol.answer);

    $finish;
  end

endmodule