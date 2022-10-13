// *********************************************************
// Copyright (c) 2020 Demand Peripherals, Inc.
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
//  File: dproten.v;   A rotary encoder input with an LED output
//
//      This peripheral is intended to be part of a user interface.  The
//  rotary encoder counts and push button event are sent to the host on
//  any change.   Rotary encoder events are accumulated in case more
//  than one occurs during a sample interval.
//
//  up to the host on any change.
//
//  Registers (8 bit):
//  0:   MSB is the button state.  Low 7 bits are quadrature count
//  1:   LED state is the LSB.
//
/////////////////////////////////////////////////////////////////////////
module dproten(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
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

    wire   btn =  pins[0];   // center button
    wire   q1 =  pins[1];    // quadrature input a
    wire   q2 =  pins[2];    // quadrature input b
    assign pins[3] = led;    // LED
 
    // Addressing and bus interface lines 
    wire   myaddr;           // ==1 if a correct read/write on our address
 
    // Counter state and signals
    reg    [6:0] count;      // signed 7 bit count of quadrature transitions
    wire   q_inc;            // ==1 to increment quadrature counter
    wire   q_dec;            // ==1 to decrement quadrature counter
    reg    data_avail;       // Flag to say data is ready to send
    reg    ledst;            // ==1 to turn on the LED
    reg    q1_1,q1_2;
    reg    q2_1,q2_2;
    reg    btnst;
    reg    [2:0] meta;       // bring inputs into our clock domain

    initial
    begin
        ledst = 0;
        data_avail = 0;
    end

    always @(posedge CLK_I)
    begin
        meta <= pins[2:0];   // bring the three inputs into our clock domain

        if (TGA_I & myaddr & WE_I)  // latch data on a write
        begin
            if (ADR_I[0] == 1)
                ledst <= DAT_I[0];
        end
        else if (TGA_I & myaddr & ~WE_I & (ADR_I[0] == 0)) // else if a read from the host
        begin
            // Clear data_available if we are sending the count up to the host
            data_avail <= 0;
            count <= 0;
        end
        else
        begin     // no host activity and so do normal processing
            begin
                // Latch quadrature inputs to do edge detection
                q1_1 <= meta[1];
                q1_2 <= q1_1;
                q2_1 <= meta[2];
                q2_2 <= q2_1;

                // increment or decrement the count if needed
                if (q_inc)
                begin
                    count <= count + 7'h01;
                    data_avail <= 1;
                end
                else if (q_dec)
                begin
                    count <= count - 7'h01;
                    data_avail <= 1;
                end


                // send a button change event if needed
                // we try to debounce a little by only sending once per poll
                else if ((data_avail == 0) && (btnst != meta[0]))
                begin
                    btnst <= meta[0];
                    data_avail <= 1;
                end
            end
        end
    end


    // Detect the edges to count
    assign q_inc = ((q1_2 != q1_1) && (q1_2 ^ q2_2)) ||
                    ((q2_2 != q2_1) && (~(q1_2 ^ q2_2)));
    assign q_dec = ((q1_2 != q1_1) && (~(q1_2 ^ q2_2))) ||
                    ((q2_2 != q2_1) && (q1_2 ^ q2_2));

    // assign bus and I/O lines
    assign led = ledst;

    assign myaddr = (STB_I) && (ADR_I[7:1] == 0);
    assign DAT_O = (~myaddr) ? DAT_I : 
                    (~TGA_I && data_avail) ? 8'h01 :  // Just one byte to send up
                    (TGA_I && (ADR_I[0] == 0)) ? {~btnst,count} : // button is active low
                    (TGA_I && (ADR_I[0] == 1)) ? {7'h00,ledst} :
                    8'h00 ;

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule

