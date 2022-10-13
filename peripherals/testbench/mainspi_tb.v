// *********************************************************
// Copyright (c) 2021 Demand Peripherals, Inc.
//
// This file is licensed separately for private and commercial
// use.  See LICENSE.txt which should have accompanied this file
// for details.  If LICENSE.txt is not available please contact
// support@demandperipherals.com to receive a copy.
//
// In general, you may use, modify, redistribute this code, and
// use any associated patent(s) as long as
// 1) the above copyright is included in all redistributions,
// 2) this notice is included in all source redistributions, and
// 3) this code or resulting binary is not sold as part of a
//    commercial product.  See LICENSE.txt for definitions.
//
// DPI PROVIDES THE SOFTWARE "AS IS," WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING
// WITHOUT LIMITATION ANY WARRANTIES OR CONDITIONS OF TITLE,
// NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR
// PURPOSE.  YOU ARE SOLELY RESPONSIBLE FOR DETERMINING THE
// APPROPRIATENESS OF USING OR REDISTRIBUTING THE SOFTWARE (WHERE
// ALLOWED), AND ASSUME ANY RISKS ASSOCIATED WITH YOUR EXERCISE OF
// PERMISSIONS UNDER THIS AGREEMENT.
//
// This software may be covered by US patent #10,324,889. Rights
// to use these patents is included in the license agreements.
// See LICENSE.txt for more information.
// *********************************************************
`timescale 1ns/1ns

// *********************************************************
// DIRECTIONS:
//    git clone https://github.com/DemandPeripherals/PCCore.git
//    cd PCCore/src
//    vi perilist # make sure the second peripheral is 'spi'
//    make main.v
//    cd testbench
//    make mainspi_tb.xt2
//    gtkwave -a mainspi_tb.gtkw
// *********************************************************

module mainspi_tb();
    localparam PKTSIZE = 20;
    reg   clk;             // 20 MHZ clock input
    wire  tx;
    reg   rx;
    wire  tx_led;
    wire  rx_led;
    wire  err_led;
    wire  [87:0] pcpin;    // Peripheral pins

    integer i;             // test loop counters
    reg     miso;          // data back on the SPI port
    reg   [(10 * PKTSIZE)-1:0] pkt; // up to PKTSIZE bytes in the packet
    

    PCcore main_dut(clk, tx, rx, tx_led, rx_led, err_led, pcpin);

    // generate the clock(s)
    initial  clk = 0;
    always   #25 clk = ~clk;

    assign pcpin[6] = miso;

    // Test the device
    initial
    begin
        $dumpfile ("mainspi_tb.xt2");
        $dumpvars (0, mainspi_tb);

        // Idle is nothing in the receive or transmit fifos
        //  - Set input rxd line to idle state (==1) Tx=pcpin[1]
        rx = 1;
        #1000

        // Load the test characters.  Note start bit and stop bits.
        // Eight byte SPI packet (+1 for size at start)
        pkt[9:0]   = 10'b1110000000;  // c0  slip end
        pkt[19:10] = 10'b1110000000;  // c0  slip end
        pkt[29:20] = 10'b1111110000;  // f8  write, auto inc
        pkt[39:30] = 10'b1111000000;  // e0  peri/slot #0
        pkt[49:40] = 10'b1000000000;  // 00  first reg is 0
        pkt[59:50] = 10'b1000000010;  // 01  write count is 1
        pkt[69:60] = 10'b1000011110;  // 0f  first data
        pkt[79:70] = 10'b1011110110;  // 7b  crc high byte
        pkt[89:80] = 10'b1010011110;  // 4f  crc low byte
        pkt[99:90] = 10'b1110000000;  // c0  slip end
        pkt[109:100] = 10'b1110000000;  // c0  slip end
        pkt[119:110] = 10'b1110000000;  // c0  slip end
        pkt[129:120] = 10'b1111110000;  // f0  write, auto inc
        pkt[139:130] = 10'b1111000010;  // e0  peri/slot #0
        pkt[149:140] = 10'b1000000000;  // 00  first reg is 0
        pkt[159:150] = 10'b1000000010;  // 01  write count is 1
        pkt[169:160] = 10'b1000011110;  // 0f  first data
        pkt[179:170] = 10'b1000011010;  // 0d  crc high byte
        pkt[189:180] = 10'b1111110110;  // fb  crc low byte
        pkt[199:190] = 10'b1110000000;  // c0  slip end

        //pkt[9:0]     = 10'b1110000000;  // c0  slip end
        //pkt[19:10]   = 10'b1110000000;  // c0  slip end
        //pkt[29:20]   = 10'b1111110000;  // f8  fifo write
        //pkt[39:30]   = 10'b1111000010;  // e1  peri/slot #1
        //pkt[49:40]   = 10'b1000000010;  // 01  first reg is 1
        //pkt[59:50]   = 10'b1000010010;  // 09  write count is 9 (total writes)
        //pkt[69:60]   = 10'b1000010000;  // 08  first data  (SPI pkt size)
        //pkt[79:70]   = 10'b1000000100;  // 02  second data
        //pkt[89:80]   = 10'b1000000110;  // 03  third data
        //pkt[99:90]   = 10'b1000001000;  // 04  fourth data
        //pkt[109:100] = 10'b1000001010;  // 05  data
        //pkt[119:110] = 10'b1000001100;  // 06  data
        //pkt[129:120] = 10'b1000001110;  // 07  data
        //pkt[139:130] = 10'b1000010000;  // 08  data
        //pkt[149:140] = 10'b1000010010;  // 09  data
        //pkt[159:150] = 10'b1000001100;  // 06  crc high
        //pkt[169:160] = 10'b1110101110;  // d7  crc low
        //pkt[179:170] = 10'b1110000000;  // c0  slip end (byte # 16)

        #5000  // some time later ...
        //  - Send pkt on rxd
        for (i = 0; i <= (10 * PKTSIZE)-1; i = i+1) 
        begin
            rx = pkt[i];
            miso = ((i % 3) & 1);    // the lsb
            // At 115200, each bit is just less than 8.8 microseconds
            // or 174 50ns clock pulses
            // At 460800, each bit is just less than 2.2 microseconds
            // or 43.4 50ns clock pulses
            $display("bit %02d is %d", i, pkt[i]);
            #200;
            #((44 * 50) - 200);
        end

        for (i = 0; i < 10 ; i = i+1)
        begin
            miso = ((i%3) & 1);    // the lsb
            #200;
            #((44 * 50) - 200);
        end
        #700000
        $finish;
    end
endmodule


module BUFG(I, O);
    input  I;
    output O;

    assign O = I;
endmodule

module DCM_SP(
      output CLK0,                       // 0 degree DCM CLK output
      output CLK180,                     // 180 degree DCM CLK output
      output CLK270,                     // 270 degree DCM CLK output
      output CLK2X,                      // 2X DCM CLK output
      output CLK2X180,                   // 2X, 180 degree DCM CLK out
      output CLK90,                      // 90 degree DCM CLK output
      output CLKDV,                      // Divided DCM CLK out (CLKDV_DIVIDE)
      output CLKFX,                      // DCM CLK synthesis out (M/D)
      output CLKFX180,                   // 180 degree CLK synthesis out
      output LOCKED,                     // DCM LOCK status output
      output PSDONE,                     // Dynamic phase adjust done output
      output STATUS,                     // 8-bit DCM status bits output
      input  CLKFB,                      // DCM clock feedback
      input  CLKIN,                      // Clock input (from IBUFG, BUFG or DCM)
      input  PSCLK,                      // Dynamic phase adjust clock input
      input  PSEN,                       // Dynamic phase adjust enable input
      input  PSINCDEC,                   // Dynamic phase adjust increment/decrement
      input  RST                         // DCM asynchronous reset input
   );

    assign CLKFX = CLKIN;

endmodule


