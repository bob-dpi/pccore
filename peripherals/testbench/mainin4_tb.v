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


// *********************************************************
// DIRECTIONS:
//    git clone https://github.com/DemandPeripherals/PCCore.git
//    cd PCCore/src
//    vi perilist # make sure the first peripheral is 'in4'
//    cd testbench
//    make mainin4_tb.xt2
//    gtkwave -a mainin4_tb.gtkw
//
// This file tests in4 and the 'send on change' feature.
// *********************************************************
`timescale 1ns/1ns


module mainin4_tb();
    localparam PKTSIZE = 10;
    reg   ck100mhz;                   // 100 MHz clock from PLL or testbench
    inout  [`BRD_MX_IO:0]  BRDIO;     // Board IO 
    inout  [`MX_PCPIN:0]   PCPIN;     // Peripheral Controller Pins (for Pmods)
    wire  tx;
    reg   rx;
    wire  tx_led;
    wire  rx_led;
    wire  err_led;

    reg   [3:0] inpins;    // Values at in4 input pins
    integer i,j,k;         // test loop counters
    reg   [(8 * PKTSIZE)-1:0] pkt; // up to PKTSIZE bytes in the packet
 

    pccore main_dut(BRDIO, PCPIN);
    assign BRDIO[`BRD_CLOCK] = ck100mhz;
    assign BRDIO[`BRD_RX] = rx;
    assign tx = BRDIO[`BRD_TX];
    assign PCPIN[3:0] = inpins;       // assign inputs


    // generate the clock(s)
    initial  ck100mhz = 0;
    always   #5 ck100mhz = ~ck100mhz;


    // Test the device
    initial
    begin
        $dumpfile ("mainin4_tb.xt2");
        $dumpvars (0, mainin4_tb);

        // Idle is nothing in the receive or transmit fifos
        //  - Set input rxd line to idle state (==1) 
        rx = 1;
        // Set inputs all high
        inpins = 4'hf;

        #1000

        // Load the test characters.  Note start bit and stop bits.
        // This writes two bytes to reg 0 in slot 2
        pkt[7:0]   = 8'hc0;  // c0  slip end
        pkt[15:8]  = 8'hc0;  // c0  slip end
        pkt[23:16] = 8'hf8;  // f8  write, no auto inc
        pkt[31:24] = 8'he0;  // e0  peri/slot #0
        pkt[39:32] = 8'h01;  // 01  "interrupt" register
        pkt[47:40] = 8'h01;  // 01  write count is 1
        pkt[55:48] = 8'h0f;  // 0f  all bits active for change
        pkt[63:56] = 8'h4c;  // 4c  high crc
        pkt[71:64] = 8'h7f;  // 7f  low crc
        pkt[79:72] = 8'hc0;  // c0  slip end

        #5000  // some time later ...
        //  - Send pkt on rxd
        for (i = 0; i <= PKTSIZE; i = i+1) 
        begin
            rx = 1'b0;               // start bit
            // At 115200, each bit is just less than 8.8 microseconds
            // or 868 10ns clock pulses
            // At 460800, each bit is just less than 2.2 microseconds
            // or 217 10ns clock pulses
            #200;
            #((868 * 10) - 200);
            for (j = 0; j < 8; j = j+1)
            begin
                rx = pkt[(i * 8) + j];  // data bit
                #200;
                #((868 * 10) - 200);
            end
            rx = 1'b1;               // stop bit
            #200;
            #((868 * 10) - 200);
        end

        #30000
        for (k = 0; k <= 4; k = k+1) 
        begin
            inpins[0] = 1'b0;
            inpins[1] = 1'b0;
            inpins[2] = 1'b1;
            inpins[3] = 1'b1;
            #200000;
            inpins[0] = 1'b1;
            inpins[1] = 1'b1;
            inpins[2] = 1'b0;
            inpins[3] = 1'b0;
            #200000;
        end

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


module RAMB16_S9 (
        output  [7:0] DO,       // 8-bit Data Output
        output  DOP,            // 1-bit parity Output
        input   [10:0] ADDR,    // 11-bit Address Input
        input   CLK,            // Clock
        input   [7:0] DI,       // 8-bit Data Input
        input   DIP,            // 1-bit parity Input
        input   EN,             // RAM Enable Input
        input   SSR,            // Synchronous Set/Reset Input
        input   WE              // Write Enable Input
    );

    assign DO = 7'h55;
    assign DOP = 1'd1;
 
endmodule

