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
//  File: gpio.v;   Simple 4 bit bidirectional IO
//
//  Registers are
//    Addr=0    Data In/Out
//    Addr=1    Data direction register.  1==output,  default=0 (input)
//    Addr=2    Update on change register.  If set, input change send auto update
//
// NOTES:
//
/////////////////////////////////////////////////////////////////////////
module gpio4(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
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
    inout  [3:0] pins;       // Simple Bidirectional I/O 
 
    wire   myaddr;           // ==1 if a correct read/write on our address
    reg    [3:0] val;        // Output values
    reg    [3:0] dir;        // The data direction register
    reg    [3:0] mask;       // Auto-update mask. 
    reg    marked;           // ==1 if we need to send an auto-update to the host
    reg    [3:0] meta;       // Used to bring the inputs into our clock domain
    reg    [3:0] meta1;      // Used to bring the inputs into our clock domain and for edge detection

    initial
    begin
        val = 0;
        dir = 0;
        mask = 0;
        marked = 0;
    end

    always @(posedge CLK_I)
    begin
        if (TGA_I & myaddr & WE_I)  // latch data on a write
        begin
            if (ADR_I[1:0] == 0)
                val <= DAT_I[3:0];
            if (ADR_I[1:0] == 1)
                dir <= DAT_I[3:0];
            if (ADR_I[1:0] == 2)
                mask <= DAT_I[3:0];
        end

        if (((meta ^ meta1) & mask & ~dir) != 0)   // do edge detection
            marked <= 1;
        else if (TGA_I & myaddr & ~WE_I)  // clear marked register on any read
            marked <= 0;

        // Get the inputs
        meta   <= pins; 
        meta1  <= meta;

    end

    // Assign the outputs.
    assign pins[3] = (dir[3]) ? val[3] : 1'bz;
    assign pins[2] = (dir[2]) ? val[2] : 1'bz;
    assign pins[1] = (dir[1]) ? val[1] : 1'bz;
    assign pins[0] = (dir[0]) ? val[0] : 1'bz;

    assign myaddr = (STB_I) && (ADR_I[7:2] == 0);
    assign DAT_O = (~myaddr) ? DAT_I : 
                    (~TGA_I & marked) ? 8'h01 :   // send up one byte if data available
                     (TGA_I && (ADR_I[1:0] == 0)) ? {4'h0,meta1} :
                     (TGA_I && (ADR_I[1:0] == 1)) ? {4'h0,dir} :
                     (TGA_I && (ADR_I[1:0] == 2)) ? {4'h0,mask} :
                     8'h00;

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule

