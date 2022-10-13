// *********************************************************
// Copyright (c) 2020-2022 Demand Peripherals, Inc.
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
// *********************************************************

//////////////////////////////////////////////////////////////////////////
//
//  File: pwmin4.v;   Four channel generic PWM input
//
//  Registers: (16 bit)
//      Reg 0:  Interval 0 duration in clk counts              (16 bits)
//      Reg 2:  Input values at the start of the interval (4 bits)
//      Reg 4:  Interval 1 duration in clk counts              (16 bits)
//      Reg 6:  Input values at the start of the interval (4 bits)
//      Reg 8:  Interval 2 duration in clk counts              (16 bits)
//      Reg 10: Input values at the start of the interval (4 bits)
//      Reg 12: Interval 3 duration in clk counts              (16 bits)
//      Reg 14: Input values at the start of the interval (4 bits)
//      Reg 16: Interval 4 duration in clk counts              (16 bits)
//      Reg 18: Input values at the start of the interval (4 bits)
//      Reg 20: Interval 5 duration in clk counts              (16 bits)
//      Reg 22: Input values at the start of the interval (4 bits)
//      Reg 24: Interval 6 duration in clk counts              (16 bits)
//      Reg 26: Input values at the start of the interval (4 bits)
//      Reg 28: Interval 7 duration in clk counts              (16 bits)
//      Reg 30: Input values at the start of the interval (4 bits)
//      Reg 32: Interval 8 duration in clk counts              (16 bits)
//      Reg 34: Input values at the start of the interval (4 bits)
//      Reg 36: Interval 9 duration in clk counts              (16 bits)
//      Reg 38: Input values at the start of the interval (4 bits)
//      Reg 40: Interval 10 duration in clk counts             (16 bits)
//      Reg 42: Input values at the start of the interval (4 bits)
//      Reg 44: Interval 11 duration in clk counts             (16 bits)
//      Reg 46: Input values at the start of the interval (4 bits)
//      Reg 48: Clk source in the lower 4 bits, then the number of intervals
//              in use, and the start output values in the next 4 bits
//
//  The clock source is selected by the lower 4 bits of register 48:
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
//  HOW THIS WORKS
//      The registers store which inputs changed at the start of an interval
//  and the duration in clock counts of the interval.  At the end of a cycle
//  the values are sent up to the host and a new cycle is started.  A new
//  cycles starts on the first input transition after sending up to the host.
//  This state machine has three states: waiting for first transition, taking
//  measurements, and waiting to sent to host.
//      The transition out of "taking measurements" can occur on either of
//  two events: all inputs have made at least three transitions (so we get
//  both high and low durations), or if there has been no transitions at all
//  while the interval counter counted from 0 to 65535.  We don't want a
//  busy input to fill up the interval registers so we use a counter to
//  count the transitions for each input.  An input is ignored after it has
//  made three transitions.
//
/////////////////////////////////////////////////////////////////////////

`define STIDLE      2'h0
`define STSAMPLING  2'h1
`define STDATREADY  2'h2
`define STHOSTSEND  2'h3

module pwmin4(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
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

    wire m100clk =  clocks[`M100CLK];    // utility 100.0 millisecond pulse on global clock line
    wire m10clk  =  clocks[`M10CLK];     // utility 10.00 millisecond pulse on global clock line
    wire m1clk   =  clocks[`M1CLK];      // utility 1.000 millisecond pulse on global clock line
    wire u100clk =  clocks[`U100CLK];    // utility 100.0 microsecond pulse on global clock line
    wire u10clk  =  clocks[`U10CLK];     // utility 10.00 microsecond pulse on global clock line
    wire u1clk   =  clocks[`U1CLK];      // utility 1.000 microsecond pulse on global clock line
    wire n100clk =  clocks[`N100CLK];    // utility 100.0 nanosecond pulse on global clock line

    wire [3:0] pwm = pins[3:0]; // PWM input signals


    // PWM lines
    reg    [15:0] main;      // Main PWM comparison clock
    wire   lclk;             // Prescale clock
    reg    lreg;             // Prescale clock divided by two
    reg    [3:0] freq;       // Input frequency selector
    reg    [3:0] old;        // Input values being brought into our clock domain
    reg    [3:0] new;        // Input values being brought into our clock domain
    reg    [3:0] first;      // Pin values at start of sampling
    reg    [3:0] edgcount;   // Count of transitions in the current cycle
    reg    [1:0] state;      // 
    reg    [1:0] ec0;        // Transition counter
    reg    [1:0] ec1;        // Transition counter
    reg    [1:0] ec2;        // Transition counter
    reg    [1:0] ec3;        // Transition counter
    wire   validedge;        // An edge to be recorded
    wire   sampleclock;      // derived clock to sample inputs

    // Addressing and bus interface lines 
    wire   myaddr;           // ==1 if a correct read/write on our address
    wire   [15:0] dout;      // RAM output lines
    wire   [3:0] ramedge;    // Edge transition output info
    wire   [3:0] raddr;      // RAM address lines
    wire   ramwen;           // RAM write enable
    pwmram16x16 timeregram(dout,raddr,main,CLK_I,ramwen); // Register array in RAM
    pwmram16x4 edgeregram(ramedge,raddr,new,CLK_I,ramwen);


    // Generate the clock source for the main counter
    assign lclk = (freq[3:1] == 0) ? 1'h0 :
                  (freq[3:1] == 1) ? n100clk :
                  (freq[3:1] == 2) ? u1clk :
                  (freq[3:1] == 3) ? u10clk :
                  (freq[3:1] == 4) ? u100clk :
                  (freq[3:1] == 5) ? m1clk :
                  (freq[3:1] == 6) ? m10clk : m100clk; 
    assign sampleclock = ((state == `STSAMPLING) && ((freq == 1) ||
                   ((freq[0] == 0) && (lclk == 1)) ||
                   ((freq[0] == 1) && (lreg == 1) && (lclk == 1))));


    // We consider at most 3 edges for each input
    assign validedge = (((old[0] != new[0]) && (ec0 != 3)) ||
                        ((old[1] != new[1]) && (ec1 != 3)) ||
                        ((old[2] != new[2]) && (ec2 != 3)) ||
                        ((old[3] != new[3]) && (ec3 != 3)));


    // Init all counters and state to zero
    initial
    begin
        state = `STSAMPLING;  // start ready to sample
        freq = 0 ;           // no clock running to start
        main = 0;
        ec0 = 0;
        ec1 = 0;
        ec2 = 0;
        ec3 = 0;
        old = 0;
        new = 0;
    end


    always @(posedge CLK_I)
    begin
        // Get the half rate clock
        if (lclk)
            lreg <= ~lreg;

        // Reset all state information when the host reads or writes config
        if (TGA_I && myaddr && (ADR_I[5:0] == 48))
        begin
            // latch clock source if a write
            if (WE_I)
            begin
                freq <= DAT_I[3:0];
            end

            // start/restart sampling on any host access
            state <= `STSAMPLING;  // start sampling
            edgcount <= 0;
            ec0 <= 0;
            ec1 <= 0;
            ec2 <= 0;
            ec3 <= 0;
            old <= pwm;          // no edges at start of sampling
            new <= pwm;          // no edges at start of sampling
            first <= pwm;
        end

        // Else do input processing on a sampling clock edge
        else if (sampleclock)
        begin
            // Get old versus new to do edge detection
            new <= pwm;
            old <= new;

            // Do state machine processing
            if (validedge)
            begin
                edgcount <= edgcount + 4'h1;
                main <= 16'h0000;

                // count edges per input line
                if ((old[3] != new[3]) && (ec3 != 2'h3))
                    ec3 <= ec3 + 2'h1;
                if ((old[2] != new[2]) && (ec2 != 2'h3))
                    ec2 <= ec2 + 2'h1;
                if ((old[1] != new[1]) && (ec1 != 2'h3))
                    ec1 <= ec1 + 2'h1;
                if ((old[0] != new[0]) && (ec0 != 2'h3))
                    ec0 <= ec0 + 2'h1;
            end
            else if ((ec0 == 2'h3) && (ec1 == 2'h3) && (ec2 == 2'h3) && (ec3 ==2'h3))
            begin
                state <= `STDATREADY;  // data ready for host
            end
            else
            begin
                main <= main + 16'h0001;
                if (main == 16'hffff)
                    state <= `STDATREADY;  // data ready for host on timeout
            end
        end
        if ((state == `STDATREADY) && (m10clk))
            state <= `STHOSTSEND;
    end


    // Assign the outputs.
    // enable ram only in state STSAMPLING and on valid changing edge.
    assign ramwen  = ((state == `STSAMPLING) && (sampleclock) && (validedge));
    assign raddr = (TGA_I & myaddr) ? ADR_I[5:2] : edgcount ;
    assign myaddr = (STB_I);
    assign DAT_O = (~myaddr) ? DAT_I :
                    (~TGA_I && (state == `STHOSTSEND)) ? 8'h31 :
                    (TGA_I && (ADR_I[5:0] == 6'd48)) ? {edgcount,freq} :
                    (TGA_I && (ADR_I[1:0] == 2'b00)) ? dout[15:8] : 
                    (TGA_I && (ADR_I[1:0] == 2'b01)) ? dout[7:0] : 
                    (TGA_I && (ADR_I[1:0] == 2'b10)) ? {first,ramedge} : 
                    8'h0 ; 

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule


module pwmram16x16(dout,addr,din,wclk,wen);
    output   [15:0] dout;
    input    [3:0] addr;
    input    [15:0] din;
    input    wclk;
    input    wen;

    reg      [15:0] ram [15:0];

    always@(posedge wclk)
    begin
        if (wen)
            ram[addr] <= din;
    end

    assign dout = ram[addr];

endmodule


module pwmram16x4(dout,addr,din,wclk,wen);
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


