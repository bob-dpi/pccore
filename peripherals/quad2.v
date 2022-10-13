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
//  File: quad2.v;   A dual quadrature decoder
//
//      This quadrature decoder accumulates pulses and sends an update
//  to the host that includes both a signed count and a period in usec.
//
//  The pulses are accumulated in RAM based registers.  So as to not
//  miss any pulses during a host read/clear, the design uses two sets
//  sets of registers and toggles between them on each transmission up
//  to the host.  Counts accumulate in one block while data in the other
//  is waiting to be sent to the host.
//
//     A 16 bit microsecond counter runs in parallel to the counting. 
//  The counter is zeroed at the start of each sampling interval.  Each
//  time a counter is incremented, a snapshot is taken of the usec counter.
//  The most recent snapshot is also sent up at each poll.  This usec
//  count gives the host the ability to compute the number of usec it
//  took to accumulate the number of counts.  A count and the number of
//  usec gives a very accurate frequency even at low counts per poll.
//    Counts and period snapshots are kept in slice RAM to conserve
//  space.  Both are 16 bits so the maximum period is 65ms.
//    Note that the input clock is at SYSCLK and we divide this by
//  four so that each input gets access to the slice RAM address
//  and data lines for two of every four clocks.  The first of
//  the two clocks updates the count and the second updates the
//  period.
//
//
//  Registers
//  0,1:   Input a signed count (high,low)
//  2,3:   usec snapshot of last edge capture by counter
//  4,5:   Input a signed count (high,low)
//  6,7:   usec snapshot of last edge capture by counter
//  8  :   Poll interval in units of 10ms.  0-5, where 0=10ms and 5=60ms, 7=off
//
/////////////////////////////////////////////////////////////////////////
module quad2(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
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

    wire m10clk  =  clocks[`M10CLK];     // utility 10.00 millisecond pulse
    wire u1clk   =  clocks[`U1CLK];      // utility 1.000 microsecond pulse
    wire   a1 = pins[0];     // input 1 on channel a
    wire   a2 = pins[1];     // input 2 on channel a
    wire   b1 = pins[2];     // input 1 on channel b
    wire   b2 = pins[3];     // input 2 on channel b

    // Addressing and bus interface lines 
    wire   myaddr;           // ==1 if a correct read/write on our address
 
    // Count RAM interface lines
    wire   [15:0] rout;      // RAM output lines
    wire   [3:0] raddr;      // RAM address lines
    wire   [15:0] rin;       // RAM input lines
    wire   wen;              // RAM write enable
    ramq216x8count ramH(rout[15:8],raddr,rin[15:8],CLK_I,wen); // Register array in RAM
    ramq216x8count ramL(rout[7:0],raddr,rin[7:0],CLK_I,wen); // Register array in RAM

    // Counter state and signals
    wire   a_inc;            // ==1 to increment A
    wire   a_dec;            // ==1 to decrement A
    wire   b_inc;            // ==1 to increment B
    wire   b_dec;            // ==1 to decrement B
    wire   [15:0] addmux;    // sits in front of an adder and == 1 or ffff
    reg    data_avail;       // Flag to say data is ready to send
    reg    [2:0] pollclk;    // number-1 of poll interval in units of 10ms.  0=10ms
    reg    [2:0] pollcount;  // divides pollclk to get 10, 20, ... 60ms
    reg    [15:0] period;    // 16 bit microsecond counter
    reg    block;            // Which block of registers we are updating
    reg    [1:0] inx;        // Which input we are examining now [1] and count/period [0]
    reg    a1_1,a1_2;
    reg    a2_1,a2_2;
    reg    b1_1,b1_2;
    reg    b2_1,b2_2;

    initial
    begin
        block = 0;
        data_avail = 0;
        period = 0;
        pollclk = 7;         // 0,1,2,3.. for 10ms,20ms,30ms ..60ms,off poll time
        pollcount = 0;
    end

    always @(posedge CLK_I)
    begin
        // Update pollcount, do poll processing
        if (m10clk)
        begin
            if (pollcount == pollclk)
            begin
                pollcount <= 0;
                data_avail <= 1;                // set flag to send data to host
                block <= ~block;                // switch RAM block every poll
                period <= 0;                    // restart period counter
            end
            else
                pollcount <= pollcount + 3'h1;
        end
        else if (u1clk)
            period <= period + 16'h0001;


        // Handle write requests from the host
        if (TGA_I & myaddr & WE_I & ADR_I[3])  // latch data on a write
        begin
            pollclk <= DAT_I[2:0];
        end


        if (TGA_I & myaddr & ~WE_I) // if a read from the host
        begin
            // Clear data_available if we are sending the count up to the host
            data_avail <= 0;
        end
        else
        begin
            // host has priority access to RAM so delay our processing while
            // host is reading RAM.  This won't affect the output since we are
            // delaying processing by one sysclk and the maximum input frequency
            // is one twentieth of sysclk.
            inx <= inx + 2'h1;
            if (inx == 3)  // sample inputs on next sysclk edge
            begin
                // Bring inputs into our clock domain.
                a1_1 <= a1;
                a1_2 <= a1_1;
                a2_1 <= a2;
                a2_2 <= a2_1;
                b1_1 <= b1;
                b1_2 <= b1_1;
                b2_1 <= b2;
                b2_2 <= b2_1;
            end
        end
    end


    // Detect the edges to count
    assign a_inc = ((a1_2 != a1_1) && (a1_2 ^ a2_2)) ||
                    ((a2_2 != a2_1) && (~(a1_2 ^ a2_2)));
    assign a_dec = ((a1_2 != a1_1) && (~(a1_2 ^ a2_2))) ||
                    ((a2_2 != a2_1) && (a1_2 ^ a2_2));
    assign b_inc = ((b1_2 != b1_1) && (b1_2 ^ b2_2)) ||
                    ((b2_2 != b2_1) && (~(b1_2 ^ b2_2)));
    assign b_dec = ((b1_2 != b1_1) && (~(b1_2 ^ b2_2))) ||
                    ((b2_2 != b2_1) && (b1_2 ^ b2_2));


    // addmux is +1 or -1 depending inx, a_inc, and b_inc
    assign addmux = 
                 (((inx == 0) && (a_inc == 1)) || ((inx == 2) && (b_inc == 1))) ? 16'h0001 :
                 16'hffff ;

    // RAM address is block and inx, or !block and register address if a host read
    assign raddr = (TGA_I & myaddr & ~WE_I & (ADR_I[3] == 0)) ? {1'b0, ~block, ADR_I[2:1]} : 
                                                               {1'b0, block, inx} ;

    // Clear RAM register on/after a read
    assign rin = (TGA_I & myaddr & ~WE_I & (ADR_I[7:3] == 0) & (ADR_I[0] == 1)) ? 16'h0000 :
                 ((inx == 0) && (a_inc == 1)) ? (rout + addmux) :
                 ((inx == 0) && (a_dec == 1)) ? (rout + addmux) :
                 ((inx == 1) && (a_inc == 1)) ? period :
                 ((inx == 1) && (a_dec == 1)) ? period :
                 ((inx == 2) && (b_inc == 1)) ? (rout + addmux) :
                 ((inx == 2) && (b_dec == 1)) ? (rout + addmux) :
                 ((inx == 3) && (b_inc == 1)) ? period :
                 ((inx == 3) && (b_dec == 1)) ? period :
                 rout ;
    assign wen   = 1 ;

    assign myaddr = (STB_I) && (ADR_I[7:4] == 0);
    assign DAT_O = (~myaddr) ? DAT_I : 
                    // send 8 bytes per sample.  Pollclk==7 turns off auto-updates
                    (~TGA_I && data_avail && (pollclk != 7)) ? 8'h08 :
                    (TGA_I & (ADR_I[0] == 0)) ? rout[15:8] :
                    (TGA_I & (ADR_I[0] == 1)) ? rout[7:0] :
                    (TGA_I & (ADR_I[3] == 1)) ? {5'h0,pollclk} :
                    8'h00 ;

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule


// Distributed RAM to store counters and shadow value.
module ramq216x8count(dout,addr,din,wclk,wen);
    output   [7:0] dout;
    input    [3:0] addr;
    input    [7:0] din;
    input    wclk;
    input    wen;
    reg      [7:0] ram [15:0];

    always@(posedge wclk)
    begin
        if (wen)
            ram[addr] <= din;
    end

    assign dout = ram[addr];

endmodule

