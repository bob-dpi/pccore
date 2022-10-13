// *********************************************************
// Copyright (c) 2022 Demand Peripherals, Inc.
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
// sr04_tb.v : Testbench for the sr04 peripheral with parallel trigger
//
//  Registers are
//    Addr=0/1    Echo time of sensor 1 in microseconds
//    Addr=2/3    Echo time of sensor 2 in microseconds
//    Addr=4/5    Echo time of sensor 3 in microseconds
//    Addr=6/7    Echo time of sensor 4 in microseconds
//    Addr=8/9    Echo time of sensor 5 in microseconds
//    Addr=10/11  Echo time of sensor 6 in microseconds
//    Addr=12/13  Echo time of sensor 7 in microseconds
//    Addr=14     Poll interval in units of 10 ms, 0==off
//
//  The test procedure is as follows:
//  - Set the poll interval to 40ms
//  - Raise all inputs after 500us
//  - Lower inputs after 10,11,12,13,14,15, and 16 ms
//  - Verify that data ready flag goes high
//  - Read all 14 echo time registers and verify times
 
`timescale 1ns/1ns


module sr04_tb;
    reg    CLK_I;            // system clock
    reg    WE_I;             // direction of this transfer. Read=0; Write=1
    reg    TGA_I;            // ==1 if reg access, ==0 if poll
    reg    STB_I;            // ==1 if this peri is being addressed
    reg    [7:0] ADR_I;      // address of target register
    wire   STALL_O;          // ==1 if we need more clk cycles to complete
    wire   ACK_O;            // ==1 if we claim the above address
    reg    [7:0] DAT_I;      // Data INto the peripheral;
    wire   [7:0] DAT_O;      // Data OUTput from the peripheral, = DAT_I if not us.
    reg    [7:0] clocks;     // Array of clock pulses from 100ns to 1 second
    wire   [7:0] pins;       // Pins to HC04 modules.  Strobe is LSB
    reg    [6:0] echo;       // echo inputs from the SR04 sensors
 

    // Add the device under test
    sr04 sr04_dut(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);

    initial echo = 0;
    assign pins[7:1] = echo[6:0];

    // generate the clock(s)
    initial  CLK_I = 1;
    always   #25 CLK_I = ~CLK_I;
    initial  clocks = 8'h00;
    always   begin #50 clocks[`N100CLK] = 1;  #50 clocks[`N100CLK] = 0; end
    always   begin #950 clocks[`U1CLK] = 1;  #50 clocks[`U1CLK] = 0; end
    always   begin #9950 clocks[`U10CLK] = 1;  #50 clocks[`U10CLK] = 0; end
    always   begin #99950 clocks[`U100CLK] = 1;  #50 clocks[`U100CLK] = 0; end
    always   begin #999950 clocks[`M1CLK] = 1;  #50 clocks[`M1CLK] = 0; end
    always   begin #9999950 clocks[`M10CLK] = 1;  #50 clocks[`M10CLK] = 0; end
    always   begin #99999950 clocks[`M100CLK] = 1;  #50 clocks[`M100CLK] = 0; end
    always   begin #999999950 clocks[`S1CLK] = 1;  #50 clocks[`S1CLK] = 0; end


    // Test the device
    initial
    begin
        $display($time);
        $dumpfile ("sr04_tb.xt2");
        $dumpvars (0, sr04_tb);
        //  - Set bus lines and FPGA pins to default state
        WE_I = 0; TGA_I = 0; STB_I = 0; ADR_I = 0; DAT_I = 0;


        #1000    // some time later
        //  - Set the poll interval to 40ms
        WE_I = 1; TGA_I = 1; STB_I = 1; ADR_I = 14; DAT_I = 4;
        #50
        WE_I = 0; TGA_I = 0; STB_I = 0; ADR_I = 0; DAT_I = 0;
        #100

        //  - Wait 10.1 ms for start of sampling
        #10100000

        //  - Clear the pending host send request
        WE_I = 0; TGA_I = 1; STB_I = 1; ADR_I = 0; DAT_I = 0;
        #50
        WE_I = 0; TGA_I = 0; STB_I = 0; ADR_I = 0; DAT_I = 0;

        //  - Trigger is done, now raise echo inputs
        echo[6:0] = 7'h7f;
        //  - Lower inputs after 10,11,12,13,14,15, and 16 ms
        #10000000 echo[0] = 1'b0;
        #1000000  echo[1] = 1'b0;
        #1000000  echo[2] = 1'b0;
        #1000000  echo[3] = 1'b0;
        #1000000  echo[4] = 1'b0;
        #1000000  echo[5] = 1'b0;
        #1000000  echo[6] = 1'b0;
        $display("inputs done at t=", $time);

        // Delay until start of next period and read the counter values
        #23898900
        WE_I = 0; TGA_I = 1; STB_I = 1; ADR_I = 0; DAT_I = 0;
        #100
        WE_I = 0; TGA_I = 1; STB_I = 1; ADR_I = 1; DAT_I = 0;
        #100
        WE_I = 0; TGA_I = 1; STB_I = 1; ADR_I = 2; DAT_I = 0;
        #100
        WE_I = 0; TGA_I = 1; STB_I = 1; ADR_I = 3; DAT_I = 0;
        #100
        WE_I = 0; TGA_I = 1; STB_I = 1; ADR_I = 4; DAT_I = 0;
        #100
        WE_I = 0; TGA_I = 1; STB_I = 1; ADR_I = 5; DAT_I = 0;
        #100
        WE_I = 0; TGA_I = 1; STB_I = 1; ADR_I = 6; DAT_I = 0;
        #100
        WE_I = 0; TGA_I = 1; STB_I = 1; ADR_I = 7; DAT_I = 0;
        #100
        WE_I = 0; TGA_I = 1; STB_I = 1; ADR_I = 8; DAT_I = 0;
        #100
        WE_I = 0; TGA_I = 1; STB_I = 1; ADR_I = 9; DAT_I = 0;
        #100
        WE_I = 0; TGA_I = 1; STB_I = 1; ADR_I = 10; DAT_I = 0;
        #100
        WE_I = 0; TGA_I = 1; STB_I = 1; ADR_I = 11; DAT_I = 0;
        #100
        WE_I = 0; TGA_I = 1; STB_I = 1; ADR_I = 12; DAT_I = 0;
        #100
        WE_I = 0; TGA_I = 1; STB_I = 1; ADR_I = 13; DAT_I = 0;
        #100
        WE_I = 0; TGA_I = 0; STB_I = 0; ADR_I = 0; DAT_I = 0;
        #100

        #20000000
        //  - Set the poll interval to 0ms to disable
        WE_I = 1; TGA_I = 1; STB_I = 1; ADR_I = 14; DAT_I = 0;
        #50
        WE_I = 0; TGA_I = 0; STB_I = 0; ADR_I = 0; DAT_I = 0;
        #50

        #10000000


        $finish;
    end
endmodule



