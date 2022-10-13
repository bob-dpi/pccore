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

//////////////////////////////////////////////////////////////////////////
//
//  File: ping4.v;   Interface to four Parallax PNG))) ultrasonic sensors
//
//  Registers are read-only and 16 bit
//    Addr=0,1    Echo time
//    Addr=2      Interface number
//    Addr=3      Enabled register
//
//
//   State      0   1    2   | 3      4                   5    0
//   IN/OUT   _____|--|____________|------|------------|________
//   Poll     .....|...................................______|____
//
//   The FPGA drives the PNG))) high for 5 us (state 1) and then holds
//   the line low for 500 us (state 2).  It then switches and starts
//   listening for a rising edge (state 3) coming back from the PNG.
//   When it finds the rising edge it counts the microseconds until 
//   the falling edge (state 4).  With a complete sample, we wait for
//   a poll and then send the sample up the host (state 5)
//
//   The above is repeated for each of the four input lines.  Each
//   good reason we start the cycle on a poll from the busif.  Times
//   for state 2 and 3 should be less than 750 us.  If we're still in
//   state 3 after 1024 us we assume that no sensor is connected and
//   go immediately to state 5 with a reading of zero.
//
/////////////////////////////////////////////////////////////////////////
module ping4(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
    input  CLK_I;            // system clock
    input  WE_I;             // direction of this transfer. Read=0; Write=1
    input  TGA_I;            // ==1 if reg access, ==0 if poll
    input  STB_I;            // ==1 if this peri is being addressed
    input  [7:0] ADR_I;      // address of target register
    output STALL_O;          // ==1 if we need more clk cycles to complete
    output ACK_O;            // ==1 if we claim the above address
    input  [7:0] DAT_I;      // Data INto the peripheral;
    output [7:0] DAT_O;      // Data OUTput from the peripheral, = DAT_I if not us.
    input  [`MXCLK:0] clocks; // Array of clock pulses from 10ns to 1 second
    inout  [3:0] pins;       // FPGA I/O pins

    wire u1clk   =  clocks[`U1CLK];      // utility 1.000 microsecond pulse
    wire m10clk  =  clocks[`M10CLK];     // utility 10.00 millisecond pulse

    wire   myaddr;           // ==1 if a correct read/write on our address
    reg    [1:0] sensor;     // Which sensor is being measured
    reg    [2:0] state;      // Where in the measurement we are
    reg    [14:0] timer;     // Used for all counting of microseconds
    reg    [1:0] deadtimer;  // Creates a short pause between reading to let echos die down
    reg    meta;             // Brings inputs into our clock domain
    reg    meta1;            // Brings inputs into our clock domain and for edge detection
    reg    [3:0] enabled;    // ==1 if sensor is enabled

    initial
    begin
        state = 0;
        sensor = 0;
        enabled = 0;
        deadtimer = 3;
    end

    always @(posedge CLK_I)
    begin
        // Get the input
        meta  <= (sensor == 0) ? pins[0] :
                 (sensor == 1) ? pins[1] :
                 (sensor == 2) ? pins[2] : pins[3];
        meta1 <= meta;


        // Set the enabled bits
        if (TGA_I & myaddr & WE_I)  // latch data on a write
        begin
            if (ADR_I[1:0] == 3)
                enabled <= DAT_I[3:0];
        end


        if (state == 0)  // Waiting to start a measurement, output=0
        begin
            if (((sensor == 0) && (enabled[0] == 0)) ||
                ((sensor == 1) && (enabled[1] == 0)) ||
                ((sensor == 2) && (enabled[2] == 0)) ||
                ((sensor == 3) && (enabled[3] == 0)))
                sensor <= sensor + 2'h1;
            else if (deadtimer == 0)  // start on 30 ms boundary
            begin
                state <= 1;
                timer <= -6;
            end
            else if (m10clk)
                deadtimer <= deadtimer - 2'h1;
        end
        if (state == 1)  // Sending the start pulse to the PNG))), output=1
        begin
            if (u1clk)
            begin
                if (timer == 0)
                begin
                    state <= 2;
                    timer <= -512;
                end
                else
                    timer <= timer + 15'h0001;
            end
        end
        if (state == 2)  // Dead time waiting to switch line direction, output=0
        begin
            if (u1clk)
            begin
                if (timer == 0)
                begin
                    state <= 3;
                    timer <= -512;
                end
                else
                    timer <= timer + 15'h0001;
            end
        end
        if (state == 3)  // Waiting for a low-to-high transition or a timeout, output=Z
        begin
            if ((meta == 1) && (meta1 == 0)) // Got the low-to-high transition
            begin
                state <= 4;
                timer <= 0;
            end
            else if (u1clk)
            begin
                if (timer == 0)  // timeout == no sensor; send a zero response
                begin
                    state <= 5;
                    timer <= 0;
                end
                else
                    timer <= timer + 15'h0001;
            end
        end
        if (state == 4)  // Waiting for the input to go low again
        begin
            if (u1clk)
                timer <= timer + 15'h0001;
            if (meta1 == 0)
                state <= 5;
        end
        if (state == 5)  // Got a measurement. Wait for a poll.
        begin
            if (TGA_I && myaddr)  // Poll.  Go start another reading
            begin
                state <= 0;
                sensor <= sensor + 2'h1;
                deadtimer <= 3;
            end
        end

    end

    // Assign the outputs.
    assign pins[0] = ((enabled[0] == 0) || (sensor != 0)) ? 1'b0 :
                    (state == 1) ?   1'b1    :
                    ((state == 0) || (state == 2)) ? 1'b0 : 1'bz ;
    assign pins[1] = ((enabled[1] == 0) || (sensor != 1)) ? 1'b0 :
                    (state == 1) ?   1'b1    :
                    ((state == 0) || (state == 2)) ? 1'b0 : 1'bz ;
    assign pins[2] = ((enabled[2] == 0) || (sensor != 2)) ? 1'b0 :
                    (state == 1) ?   1'b1    :
                    ((state == 0) || (state == 2)) ? 1'b0 : 1'bz ;
    assign pins[3] = ((enabled[3] == 0) || (sensor != 3)) ? 1'b0 :
                    (state == 1) ?   1'b1    :
                    ((state == 0) || (state == 2)) ? 1'b0 : 1'bz ;

    assign myaddr = (STB_I) && (ADR_I[7:2] == 0);
    assign DAT_O = (~myaddr) ? DAT_I : 
                    (~TGA_I & (state == 5)) ? 8'h03 : // send 3 bytes when a sample is ready
                    (TGA_I && (ADR_I[1:0] == 0)) ? {1'h0,timer[14:8]} :
                    (TGA_I && (ADR_I[1:0] == 1)) ? timer[7:0] :
                    (TGA_I && (ADR_I[1:0] == 2)) ? {6'h00,sensor} :
                    (TGA_I && (ADR_I[1:0] == 3)) ? {4'h0,enabled} :
                    8'h00;

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule

