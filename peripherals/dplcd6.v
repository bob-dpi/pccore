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
//  File: dplcd6.v;   Six digit 7-segment LCD display (on out24 card)
//
//  Registers: (8 bit)
//      Reg 0:  FIFO with data for the LCD.
//
//
//  HOW THIS WORKS
//      This Verilog code is meant to connect to a DPI OUT24
// peripheral card.  The four BB4 lines are generally used as
// an ESPI interface but instead of an input pin there is an
// extra output pin on the out24 card.  This extra pin lets
// us write/shift out all 24 bits in 8 SCK write cycles.
//
// Each output SCK pulse sets three bits.  The rising edge
// of SCK clocks Pin8 and Pin2 into IC2 and IC3 respectively,
// and the negative edge clocks Pin8 into IC1.  The value at
// Pin2 on the rising edge of Pin6 is routed to all three of
// of the 74595 output latch TGA_I line.
//
// Because of ringing there may be both positive _AND_
// negative edges on all changes of Pin6 or Pin4.  So we set
// the data on these pins before the rising edge on Pin4 or
// Pin6 and we keep it after the falling edge.  Thus each SCK
// pulse has five substates
// Pin 6/4    State
// #0  1/0 SCK stays low.  Change data lines
// #1  1/1 SCK goes high.  No change to data lines
// #2  1/0 SCK stays high. Change data lines
// #3  0/0 SCK goes low,   No change to data lines
// #4  1/0 SCK stays low.  Ringing, so no change to data
//
// The full sequence of writes to send all 24 bits is:
// GS BS	8_6_4_2    Global State (GS), Bit State (BS), and pins
//  0  x	0 0 0 0    Set CS low
//  1  x	0 1 0 0
// For i equal 0 to 7 do
//  2  i	M 1 0 H    Send bit i for high and mid bytes
//  3  i	M 1 1 H
//  4  i	L 1 0 0    Send bit i for low byte (CS=pin2=0)
//  5  i	L 0 0 0
//  6  i	L 1 0 0
// End for i
//  7  x	0 0 0 1    Set CS high to latch outputs
//  8  x	0 1 0 1
//
//
// The above sequence is all that is needed for the out24.  LCDs,
// however, need a repetitive pattern in which the segments are
// alternatively switched on and off with an AC signal.  Further,
// the LCD used in this design has a three way mux on the pins
// to the segments.  To fully drive the LCD requires sequentially
// driving the three sets of multiplexed segments first high and
// then low.
//    To understand the sequence you need to know the pin-out of
// the LCD.    The pin-out of the LCD is shown below.  The high,
// mid, and low bytes correspond to IC3, IC2, and IC1 respectively
// on the out24 schematic.  Both 74595 and segments are labeled
// 'a' to 'g'.  Do no be confused by this in the table below.
//
//	Out24   LCD     COM1    COM25   COM50
//	hb      1       COM1
//	hb      2       COM1
//	hd      3       1e              1f
//	he      4       1g      1d      1a
//	hf      6       2e              2f
//	hh      7       2g      2d      2a
//	mb      9       3e              3f
//	mc      10      3g      3d      3a
//	md      13      4e              4f
//	me      14      4g      4d      4a
//	mg      17      5e              5f
//	mg      18      5g      5d      5a
//	lb      21      6e              6f
//	ld      22      6g      6d      6a
//	lf      24              COM25
//	lf      25              COM25
//	le      26              COM25
//	le      27              COM25
//	lc      28      6c              6b
//	la      31      5c      5dp     5b
//	mf      35      4c      4dp     4b
//	ma      39      3c      3dp     3b
//	hg      43      2c      2dp     2b
//	hc      47      1c      1pd     1b
//	ha      49                      COM50
//	ha      50                      COM50
//
//
// 
// The logic for the above pattern is too complex to implement
// as a single monolithic state machine.  Instead the Verilog
// program uses RAM to store the bit patterns for the six
// writes to the out24.  The RAM is three bits wide (for the
// high, mid, and low bytes on the out24) and is 48 bits deep.
// It is up to the Linux device driver to determine the bit
// pattern that is stored in the FIFO.
// 
/////////////////////////////////////////////////////////////////////////
module dplcd6(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
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

    wire u100clk =  clocks[`U100CLK];    // utility 100.0 microsecond pulse
    assign pins[0] = pin2;   // Data on pin per diagram above
    assign pins[1] = pin4;   // Data on pin per diagram above
    assign pins[2] = pin6;   // Data on pin per diagram above
    assign pins[3] = pin8;   // Data on pin per diagram above



    // State machine and bit counter registers
    reg    [5:0] bst;        // index of bits to send.  0-63
    reg    [3:0] gst;        // global state machine for out24 card SCK

    // Addressing and bus interface lines 
    wire   myaddr;           // ==1 if a correct read/write on our address
    wire   [2:0] rout;       // RAM output lines
    wire   [5:0] raddr;      // RAM address lines
    wire   wen;              // RAM write enable
    dplcdram64x1 ram0(rout[2],raddr,DAT_I[2],CLK_I,wen);   // high byte on the out24 card
    dplcdram64x1 ram1(rout[1],raddr,DAT_I[1],CLK_I,wen);   // mid byte on the out24 card
    dplcdram64x1 ram2(rout[0],raddr,DAT_I[0],CLK_I,wen);   // low byte on the out24 card


    initial
    begin
        bst = 0;
        gst = 0;
    end


    always @(posedge CLK_I)
    begin
        // if not reading/writing from host, and on u100clk edge
        if (~(TGA_I && myaddr && WE_I) && u100clk)
        begin
            if (gst < 6)
                gst <= gst + 4'h1;
            else if (gst == 6)     // done with bit write?
            begin
                bst <= (bst == 47) ? 6'h00 : bst + 6'h01;
                if (bst[2:0] != 7) // do CS if done with all 8 bits
                    gst <= 2;
                else
                    gst <= gst + 4'h1;
            end
            else if (gst == 7)
                gst <= gst + 4'h1;
            else if (gst == 8)     // done with byte write?
            begin
                gst <= 0;
            end
        end
    end


    // assign RAM signals
    assign wen   = (TGA_I & myaddr & WE_I);  // latch data on a write
    assign raddr = (TGA_I & myaddr) ? ADR_I[5:0] : bst ;

    // Assign the outputs.
    assign myaddr = (STB_I) && (ADR_I[7:6] == 0);
    assign DAT_O = (~myaddr) ? DAT_I :
                    (TGA_I) ? {5'h00,rout} : 
                    8'h00 ; 

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O =  myaddr;

    assign pin8 = ((((gst == 2) | (gst == 3)) & rout[1]) |
                   (((gst == 4) | (gst == 5) | (gst == 6)) & rout[0]));
    assign pin6 = (gst == 1) | (gst == 2) | (gst == 3) |
                  (gst == 4) | (gst == 6) | (gst == 8);
    assign pin4 = (gst == 3);
    assign pin2 = (gst == 7) | (gst ==8) | (((gst == 2) | (gst == 3)) & rout[2]);

endmodule


module dplcdram64x1(dout,addr,din,wclk,clken);
    output   dout;
    input    [5:0] addr;
    input    din;
    input    wclk;
    input    clken;

    reg      ram [63:0];

    always@(posedge wclk)
    begin
        if (clken)
            ram[addr] <= din;
    end

    assign dout = ram[addr];

endmodule

