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

/////////////////////////////////////////////////////////////////////////
// ftdi_tb.v : Testbench for the FTDI host interface
//
//
`define SLIP_END             8'd192
`define SLIP_ESC             8'd219
`define INPKT_END            8'd220
`define INPKT_ESC            8'd221
`timescale 1ns/1ns


module dpcore_tb();
    reg   clk;             // 20 MHZ clock input
    reg   u100clk;
    reg   BNTN1;           // Baseboard2 button #1
    reg   BNTN2;           // Baseboard2 button #2
    reg   BNTN3;           // Baseboard2 button #3
    wire  [7:0] LED;       // Red LEDs on the Baseboard2
    reg   RXF_;            // Data available if low
    wire  RD_;             // Get data from bus when low
    reg   TXE_;            // Able to send new data if low
    wire  WR;              // Write data on positive edge
    inout [7:0] USBD;      // USB data bus
    reg   [7:0] phydata_in; // what we get from the host

    DPcore dpcore_dut(clk, u100clk, BNTN1, BNTN2, BNTN3, LED, RXF_, RD_, TXE_,
      WR, USBD);

    // generate the clock(s)
    initial  clk = 0;
    always   #25 clk = ~clk;
    initial  u100clk = 0;
    always   #50 u100clk = ~u100clk;

    // Do tri-state bus for FT245 data bus.
    assign USBD = ((RD_ == 0) && (WR == 0)) ? phydata_in : 8'hz;

    // Test the device
    initial
    begin
        $dumpfile ("dpcore_tb.xt2");
        $dumpvars (0, dpcore_tb);

        // Idle is nothing in the receive or transmit fifos
        RXF_ = 1; TXE_ = 0;

        #500  // some time later ...
        RXF_ = 0;            // data from the host
        phydata_in = 8'hc0;  // `SLIP_END;
        #550                 // 11 cycles to read the host byte
        phydata_in = 8'hf8;  // write 
        #550
        phydata_in = 8'he0;  // peripheral #0
        #550
        phydata_in = 8'h01;  // register 1
        #550
        phydata_in = 8'h01;  // write 1 byte
        #550
        phydata_in = 8'h55;  // value to write to LEDs
        #1550
        phydata_in = 8'hc0;  // `SLIP_END;
        #850
        RXF_ = 1;            // data from the host done

        #20000

        $finish;
    end
endmodule

