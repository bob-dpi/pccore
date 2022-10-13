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
//  File: pgen16.v;   Four bit, 16 state pattern generator
//
//  The pgen16 is a small pattern generator.  The generator goes through
//  16 steps where each step is exactly 256 counts long.  Within a step
//  the outputs are set to that step's value when the count equals that
//  step's trigger count.
//      Note that the total period is always 4096 counts long.
//
//  Registers:
//      Registers 0 to 31 are formed into 16 pairs.  The lower register,
//      0,2,4, ... are the 8 bits of the trigger counter.  The higher
//      numbered registers, 1,3,5,... are the values to latch for the
//      outputs when the trigger count is reached in that step.
//      
//      Reg 32: Clk source in the lower 4 bits
//
//  The clock source is selected by the lower 4 bits of register 32:
//      0:  Off
//      1:  20 MHz
//      2:  10 MHz
//      3:  5 MHz
//      4:  1 MHz
//      5:  500 KHz
//      6:  100 KHz
//      7:  50 KHz
//      8:  10 KHz
//      9   5 KHz
//     10   1 KHz
//     11:  500 Hz
//     12:  100 Hz
//     13:  50 Hz
//     14:  10 Hz
//     15:  5 Hz
//
/////////////////////////////////////////////////////////////////////////
module pgen16(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
    input  CLK_I;            // system clock
    input  WE_I;             // direction of this transfer. Read=0; Write=1
    input  TGA_I;            // ==1 if reg access, ==0 if poll
    input  STB_I;            // ==1 if this peri is being addressed
    input  [7:0] ADR_I;      // address of target register
    output STALL_O;          // ==1 if we need more clk cycles to complete
    output ACK_O;            // ==1 if we claim the above address
    input  [7:0] DAT_I ;     // Data INto the peripheral;
    output [7:0] DAT_O ;    // Data OUTput from the peripheral, = DAT_I if not us.
    input  [`MXCLK:0] clocks; // Array of clock pulses from 10ns to 1 second
    inout  [3:0] pins;       // FPGA I/O pins

    wire m100clk =  clocks[`M100CLK];    // utility 100.0 millisecond pulse on global clock line
    wire m10clk  =  clocks[`M10CLK];     // utility 10.00 millisecond pulse on global clock line
    wire m1clk   =  clocks[`M1CLK];      // utility 1.000 millisecond pulse on global clock line
    wire u100clk =  clocks[`U100CLK];    // utility 100.0 microsecond pulse on global clock line
    wire u10clk  =  clocks[`U10CLK];     // utility 10.00 microsecond pulse on global clock line
    wire u1clk   =  clocks[`U1CLK];      // utility 1.000 microsecond pulse on global clock line
    wire n100clk =  clocks[`N100CLK];    // utility 100.0 nanosecond pulse on global clock line

    wire   [3:0] pattern;
    assign pins = pattern;   // output pattern


    // Addressing and bus interface lines 
    wire   myaddr;           // ==1 if a correct read/write on our address
    wire   [7:0] doutl;      // RAM output lines
    wire   [3:0] douth;      // RAM output lines
    wire   [3:0] raddr;      // RAM address lines
    wire   timewenl;         // Timer RAM write enable low
    wire   timewenh;         // Timer RAM write enable high
    ram16x8out4 lowtime(doutl,raddr,DAT_I,CLK_I,timewenl);
    ram16x4out4 hitimbits(douth,raddr,DAT_I[3:0],CLK_I,timewenh);


    // Pattern generation timer and state
    reg    [7:0] main;       // Main timer comparison clock
    wire   lclk;             // Prescale clock
    reg    lreg;             // Prescale clock divided by two
    reg    [3:0] freq;       // Input frequency selector
    reg    [3:0] state;      // Sequencer that counts 0 to 7
    reg    [3:0] patlatch;   // Latched values of the outputs


    // Generate the clock source for the main counter
    assign lclk = (freq[3:1] == 0) ? 1'b0 :
                  (freq[3:1] == 1) ? n100clk :
                  (freq[3:1] == 2) ? u1clk :
                  (freq[3:1] == 3) ? u10clk :
                  (freq[3:1] == 4) ? u100clk :
                  (freq[3:1] == 5) ? m1clk :
                  (freq[3:1] == 6) ? m10clk :
                  (freq[3:1] == 7) ? m100clk : 1'b0;


    initial
    begin
        state = 0;
        freq = 0;        // no clock running to start
    end


    always @(posedge CLK_I)
    begin
        // Get the half rate clock
        if (lclk)
            lreg <= ~lreg;


        // latch clock selector into flip-flops
        if (TGA_I && WE_I && myaddr && (ADR_I[5] == 1))
        begin
            freq <= DAT_I[3:0];
        end

        if (~(TGA_I & myaddr & WE_I))  // Only when the host is not writing our regs
        begin
            if ((freq == 1) ||
                 ((freq[0] == 0) && (lclk == 1)) ||
                 ((freq[0] == 1) && (lreg == 1) && (lclk == 1)))
            begin
                main <= main + 8'h01;
                if (main == 8'hff)
                begin
                    state <= state + 4'h1;
                end
                if (main == doutl)
                begin
                    patlatch <= douth;  // latch outputs on clock match
                end
            end
        end
    end


    // Assign the outputs.
    assign pattern[0] = patlatch[0];
    assign pattern[1] = patlatch[1];
    assign pattern[2] = patlatch[2];
    assign pattern[3] = patlatch[3];

    assign mywrite = (TGA_I && myaddr && WE_I); // latch data on a write
    assign timewenl  = (mywrite && (ADR_I[5] == 0) && (ADR_I[0] == 0));
    assign timewenh  = (mywrite && (ADR_I[5] == 0) && (ADR_I[0] == 1));
    assign raddr = (TGA_I & myaddr) ? ADR_I[4:1] : state ;

    assign myaddr = (STB_I) && (ADR_I[7:6] == 0);
    assign DAT_O = (~myaddr) ? DAT_I :
                    (TGA_I && (ADR_I[5] == 1)) ? {4'h0,freq} :
                    (TGA_I && (ADR_I[0] == 0)) ? doutl : 
                    (TGA_I && (ADR_I[0] == 1)) ? {4'h0,douth} : 
                    8'h00 ; 

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule


module ram16x8out4(dout,addr,din,wclk,wen);
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


module ram16x4out4(dout,addr,din,wclk,wen);
    output   [3:0] dout;
    input    [3:0] addr;
    input    [3:0] din;
    input    wclk;
    input    wen;

    reg      [3:0] ram [15:0];

    always@(posedge wclk)
    begin
        if (wen)
            ram[addr] <= din;
    end

    assign dout = ram[addr];

endmodule


