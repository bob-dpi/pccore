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
//  File: dc2.v;   A dual H-bridge motor controller
//
//  The FPGA peripheral provides direction, PWM speed control, and both brake
//  and coast for two motors using four FPGA pins. The motors are numbered
//  0 and 1 and the two motor lines are called A and B.  The lowest numbered
//  pin on the connector is the A line for motor 0 and the second pin is the
//  B line. Pins 3 and 4 are the A and B lines for motor number 1.  The modes
//  of operation are as follows:
//           MODE        B          A
//      (0) Coast        low        low
//      (1) Reverse      low        (PWM)
//      (2) Forward      (PWM)      low
//      (3) Brake        high       high        The power-on default
//
//  This PWM motor controller uses a 10-bit "period" counter that counts from
//  up from 1 up to (period -1).  This (1...N-1) lets the PWM output have both
//  0 and 100 percent PWM pulse widths.  The count rate is selected by the
//  "clksel" field which is the high three bits of register 0.  The period is
//  split between the low 2 bits of register 0 and all 8 bits of register 1.
//
//  The clock source is selected by the upper 3 bits of register 0:
//      0:  Off
//      1:  20 MHz
//      2:  10 MHz
//      3:  5 MHz
//      4:  1 MHz
//      5:  500 KHz
//      6:  100 KHz
//      7:  50 KHz
//
//  Register 2/3 uses the high two bits for motor 0 mode and the low ten
//  bits for the "on" count for the PWM output on 0.  Smaller values of on
//  count turn the output on sooner and so cause the motor to turn faster.
//
//  The motor 1 output goes high at the start of the cycle.  The motor 1 
//  turn off count is in the low ten bits of register 4.  The high two bits
//  of register 4 is the motor 1 mode.  Full motor off is when the off count
//  equals zero.  Full motor on is when the count equals the period.
//
//  A note of explanation: So motor 0 is on from the _end_ of the period to
//  a time specified in registers 2/3, and motor 1 is on from the _start_ the
//  period.  This seems counter intuitive but serves a purpose.  It serves to
//  minimize the time that _both_ motors are on and this can reduce I2R losses
//  in the cables and battery.  This is subtle but can slightly extend the
//  battery charge.
//
//  Register 6 is the watchdog control register.  The idea of the watchdog is
//  that if enabled (bit 7 == 1) the low four bits are decremented once every
//  100 millisecond.  If the watchdog count reaches zero both PWM outputs are
//  turned off.  A four bit counter gives a minimum update rate of about once
//  every 1.5 seconds.  Just rewriting the same value into the speed or mode
//  registers is enough to reset the watchdog counter.
//
/////////////////////////////////////////////////////////////////////////

`define COAST     2'b00
`define REVERSE   2'b01
`define FORWARD   2'b10
`define BRAKE     2'b11

`define PWMON     2'b01 
`define PWMOFF    2'b10
`define DEADTIME  2'b11



module dc2(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
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
    wire u100clk =  clocks[`U100CLK];    // utility 100.0 microsecond pulse on global clock line
    wire u10clk  =  clocks[`U10CLK];     // utility 10.00 microsecond pulse on global clock line
    wire u1clk   =  clocks[`U1CLK];      // utility 1.000 microsecond pulse on global clock line
    wire n100clk =  clocks[`N100CLK];    // utility 100.0 nanosecond pulse on global clock line

    assign pins[0] = ain1;   // TB6612 AIN1 input
    assign pins[1] = ain2;   // TB6612 AIN2 input
    assign pins[2] = bin1;   // TB6612 BIN1 input
    assign pins[3] = bin2;   // TB6612 BIN2 input

    wire   myaddr;           // ==1 if a correct read/write on our address
    reg    [2:0] freq;       // Selects source of input clock
    reg    [9:0] period;     // PWM period in units of the clock selected above
    reg    [9:0] aon;        // A goes off at ZERO and on at AON
    reg    [1:0] modea;      // coast, reverse, forward, brake (0,1,2,3) A side
    reg    [9:0] boff;       // B goes off at this count
    reg    [1:0] modeb;      // coast, reverse, forward, brake (0,1,2,3) B side
    reg    [3:0] dogcnt;     // watchdog timeout in milliseconds
    reg    [1:0] offstate;   // go to brake, reverse, or coast in PWM off time
    reg    dogon;            // ==1 if watchdog is enabled
    reg    [9:0] count;      // Count upon which all comparisons are done
    reg    [1:0] astate;     // on, off, or deadtime
    reg    [1:0] bstate;     // on, off, or deadtime
    wire   dogstop;          // ==1 if watchdog expired
    wire   pclk;             // period input clock
    wire   lclk;             // Prescale clock
    reg    lreg;             // Prescale clock divided by two



    // Generate the clock source for the main counter
    assign lclk = (freq[2:1] == 0) ? CLK_I :
                  (freq[2:1] == 1) ? n100clk :
                  (freq[2:1] == 2) ? u1clk : u10clk;
    assign pclk = (freq[0] == 1) ? (lreg & lclk) : lclk ;


    initial
    begin
        freq = 0;         // clock is off to start
        period = 0;
        aon = 10'h3ff;
        modea = 3;        // default is to brake
        offstate = `DEADTIME;
        boff = 0;
        modeb = 3;        // default is to brake
        count = 0;
        dogon = 0;
        dogcnt = 0;
    end


    always @(posedge CLK_I)
    begin
        // Handle write requests from the host
        if (TGA_I & myaddr & WE_I)  // latch data on a write
        begin
            if (ADR_I[2:0] == 0)       // clock select and period
            begin
                freq <= DAT_I[7:5];
                offstate <= DAT_I[3:2];
                period[9:8] <= DAT_I[1:0];
            end
            if (ADR_I[2:0] == 1)       // period
            begin
                period[7:0] <= DAT_I[7:0];
            end
            if (ADR_I[2:0] == 2)       // A direction and off count
            begin
                modea <= DAT_I[7:6];
                aon[9:8] <= DAT_I[1:0];
            end
            if (ADR_I[2:0] == 3)       // A off count
            begin
                aon[7:0] <= DAT_I[7:0];
            end
            if (ADR_I[2:0] == 4)       // B off count and direction
            begin
                modeb <= DAT_I[7:6];
                boff[9:8] <= DAT_I[1:0];
            end
            if (ADR_I[2:0] == 5)       // B off count
            begin
                boff[7:0] <= DAT_I[7:0];
            end
            if (ADR_I[2:0] == 6)       // Watchdog enable
            begin
                dogon <= DAT_I[7];
            end
            if (ADR_I[2:0] == 7)       // Watchdog count
            begin
                dogcnt <= DAT_I[3:0];
            end
        end

        // Get the half rate clock
        if (lclk)
            lreg <= ~lreg;


        // Handle the PWM on and off edges
        if (pclk || (freq == 1))
        begin
            // Do the period clock
            if (count == period)
                count <= 1;
            else
                count <= count + 10'h001;

            // Check for turn on, else check for turn off
            if (count > aon)
                astate <= `PWMON;
            else if (count == aon)
                astate <= `DEADTIME;
            else if (count > 1)
                astate <= `PWMOFF;
            else
                astate <= `DEADTIME;

            if (count <= boff)
                bstate <= `PWMON;
            else if (count == boff + 1)
                bstate <= `DEADTIME;
            else if (count == period)
                bstate <= `DEADTIME;
            else
                bstate <= `PWMOFF;
        end

        // Handle the watchdog timer
        if (dogon && m100clk && (dogcnt != 0))
            dogcnt <= dogcnt - 4'h1;

    end


    // Assign the outputs.
    // The mapping of state to output pin:
    // Dir      State     Pins 2 1
    // Forward: ON             0 1
    // Forward: DEAD           0 0
    // Forward: OFF-COAST      0 0
    // Forward: OFF-REVRS      1 0
    // Forward: OFF-BRAKE      1 1
    // Forward: DEAD           0 0
    // Reverse: ON             1 0
    // Reverse: DEAD           0 0
    // Reverse: OFF-COAST      0 0
    // Reverse: OFF-REVRS      0 1
    // Reverse: OFF-BRAKE      1 1
    // Reverse: DEAD           0 0

    assign dogstop = (dogon && (dogcnt == 0));  // ==1 if watchdog expired
    assign ain1 = dogstop | (modea == `BRAKE) |
                  ((modea == `FORWARD) && (astate == `PWMON)) |
                  ((modea == `FORWARD) && (astate == `PWMOFF) && (offstate == `BRAKE)) |
                  ((modea == `REVERSE) && (astate == `PWMOFF) && (offstate == `REVERSE)) |
                  ((modea == `REVERSE) && (astate == `PWMOFF) && (offstate == `BRAKE));
    assign ain2 = dogstop | (modea == `BRAKE) |
                  ((modea == `FORWARD) && (astate == `PWMOFF) && (offstate == `REVERSE)) |
                  ((modea == `FORWARD) && (astate == `PWMOFF) && (offstate == `BRAKE)) |
                  ((modea == `REVERSE) && (astate == `PWMON)) |
                  ((modea == `REVERSE) && (astate == `PWMOFF) && (offstate == `BRAKE));
    assign bin1 = dogstop | (modeb == `BRAKE) |
                  ((modeb == `FORWARD) && (bstate == `PWMON)) |
                  ((modeb == `FORWARD) && (bstate == `PWMOFF) && (offstate == `BRAKE)) |
                  ((modeb == `REVERSE) && (bstate == `PWMOFF) && (offstate == `REVERSE)) |
                  ((modeb == `REVERSE) && (bstate == `PWMOFF) && (offstate == `BRAKE));
    assign bin2 = dogstop | (modeb == `BRAKE) |
                  ((modeb == `FORWARD) && (bstate == `PWMOFF) && (offstate == `REVERSE)) |
                  ((modeb == `FORWARD) && (bstate == `PWMOFF) && (offstate == `BRAKE)) |
                  ((modeb == `REVERSE) && (bstate == `PWMON)) |
                  ((modeb == `REVERSE) && (bstate == `PWMOFF) && (offstate == `BRAKE));

 
    assign myaddr = (STB_I) && (ADR_I[7:3] == 0);
    assign DAT_O = (~myaddr  || WE_I) ? DAT_I : 
                     (ADR_I[2:0] == 0) ? {freq, 3'h0, period[9:8]} :
                     (ADR_I[2:0] == 1) ? period[7:0] :
                     (ADR_I[2:0] == 2) ? {modea, 4'h0, aon[9:8]} :
                     (ADR_I[2:0] == 3) ? aon[7:0] :
                     (ADR_I[2:0] == 4) ? {modeb, 4'h0, boff[9:8]} :
                     (ADR_I[2:0] == 5) ? boff[7:0] :
                     (ADR_I[2:0] == 6) ? {dogon, 7'h00} : 
                     (ADR_I[2:0] == 7) ? {4'h0, dogcnt} :
                     8'h00;

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule

