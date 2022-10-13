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
//  File: tonegen.v;   Simple tone generation with volume control
//
//  Tonegen is a simple, square-wave tone generator that has fairly good
//  frequency control and fairly good volume control.
//
//  It uses a 24 phase accumulator that runs at 100 KHz and has a frequency
//  accuracy of one part in about ten thousand.  
//  It can control the duration of a note in milliseconds with a minimum of
//  1 millisecond and a maximum of 4095.
//  It controls volumn by PWM controlling each of its four output lines.
//  The DAC is assumed to be a nonlinear 2R-R resistor network.  (This is
//  in contrast to the usual linear R-2R resistor network.)
//
//  Registers:
//      0:  duration in milliseconds, low byte
//      1:  duration in milliseconds, high 4 bits
//      2:  low byte of 24 bit phase offset
//      3:  mid byte of 24 bit phase offset0 MHz
//      4:  high byte of 24 bit phase offset MHz
//      5:  low 4 bits are PWM for LSB output, upper 4 bits control pin1
//      6:  high 4 bits are PWM for MSB output, lower 4 bits control pin2
//
/////////////////////////////////////////////////////////////////////////
module tonegen(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
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


    // Addressing and bus interface lines 
    wire   myaddr;           // ==1 if a correct read/write on our address

    // Tone generator registers
    reg    [23:0] phacc;     // 24 bit phase accumulator. MSB is at target frequency
    reg    [23:0] phoff;     // 24 bit phase offset per 100KHz clock.  Set by host
    reg    [11:0]  durat;    // Duration of note in milliseconds.  Set by host
    reg    [3:0]  pwmin0;    // Target PWM value for Pin0, the LSB.
    reg    [3:0]  pwmin1;    // Target PWM value for Pin1
    reg    [3:0]  pwmin2;    // Target PWM value for Pin2
    reg    [3:0]  pwmin3;    // Target PWM value for Pin3, the MSB.
    reg    [3:0]  pwmcount;  // Counter for PWM.  Free running at 100 KHz.


    initial
    begin
        phacc = 0;
        durat = 0;
        pwmcount = 0;
    end


    always @(posedge CLK_I)
    begin
        // Latch input values from host
        if (TGA_I && WE_I && myaddr && (ADR_I[2:0] == 0))
            durat[7:0] <= DAT_I[7:0];
        else if (TGA_I && WE_I && myaddr && (ADR_I[2:0] == 1))
            durat[11:8] <= DAT_I[3:0];
        else if (TGA_I && WE_I && myaddr && (ADR_I[2:0] == 2))
            phoff[7:0] <= DAT_I[7:0];
        else if (TGA_I && WE_I && myaddr && (ADR_I[2:0] == 3))
            phoff[15:8] <= DAT_I[7:0];
        else if (TGA_I && WE_I && myaddr && (ADR_I[2:0] == 4))
            phoff[23:16] <= DAT_I[7:0];
        else if (TGA_I && WE_I && myaddr && (ADR_I[2:0] == 5))
        begin
            pwmin0 <= DAT_I[3:0];
            pwmin1 <= DAT_I[7:4];
        end
        else if (TGA_I && WE_I && myaddr && (ADR_I[2:0] == 6))
        begin
            pwmin2 <= DAT_I[3:0];
            pwmin3 <= DAT_I[7:4];
        end

        else if (m1clk)
        begin
            // Do duration count.  Write to durat is shared with host.
            if (durat != 0)
                durat <= durat - 12'h001;
        end

        // The PWM clock is free running at 1MHz
        if (u1clk)
        begin
            pwmcount <= pwmcount + 4'h1;
        end

        // Do phase accumulation at 100 KHz
        if (u10clk)
        begin
            phacc <= phacc + phoff;
        end
    end


    // Assign the outputs.
    assign pins[0] = (durat != 0) & phacc[23] & (pwmin0 != 0) & (pwmin0 >= pwmcount);
    assign pins[1] = (durat != 0) & phacc[23] & (pwmin1 != 0) & (pwmin1 >= pwmcount);
    assign pins[2] = (durat != 0) & phacc[23] & (pwmin2 != 0) & (pwmin2 >= pwmcount);
    assign pins[3] = (durat != 0) & phacc[23] & (pwmin3 != 0) & (pwmin3 >= pwmcount);


    assign myaddr = (STB_I) && (ADR_I[7:6] == 0);
    assign DAT_O = (~myaddr) ? DAT_I :
                    8'h00 ; 

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule


