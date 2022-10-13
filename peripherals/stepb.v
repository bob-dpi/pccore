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
//  File: stepb.v;   A bipolar stepper controller
//
//      This design has a read/write register for the number of steps to go,
//  a read/write register for step rate (step period actually), a read/write
//  flag to indicate full or half steps, and a write-only register that adds
//  or removes steps from the target step count.
//
//      The hardware outputs go to each of the four windings on the stepper.
//  The lowest numbered pin on the connector is the AIN1 input for winding A
//  and the second pin is the AIN2 input. Pins 3 and 4 are the BIN1 and BIN2
//  inputs for the B winding.  The TB6612 PWM inputs and the STBY input should
//  be tied to 5 volts.  The modes of operation versus the IN pins is depicted
//  in this table.
//           MODE        IN1        IN2
//          Brake        high       high        The power-on default
//          Forward      low        (PWM)
//          Reverse      (PWM)      low
//          Coast        low        low
//
//
//  Outputs are as follows for full and half steps:
//
//  Full Step
//    phac[2:1]    AIN1 AIN2   BIN1 BIN2 
//           0      1    0      1    0
//           1      0    1      1    0
//           2      0    1      0    1
//           3      1    0      0    1
//
//  Half Step
//    phac[2:0]    AIN1 AIN2   BIN1 BIN2 
//           0      1    0      1    0
//           0      0    0      1    0
//           2      0    1      1    0
//           2      0    1      0    0
//           4      0    1      0    1
//           4      0    0      0    1
//           6      1    0      0    1
//           6      1    0      0    0
//
//  Registers are (high byte)
//    Addr=0    12 bit target step count, decremented to zero
//    Addr=2    12 bit value synchronously added to the target, write only
//    Addr=4    5 bits are the setup, low 8 bits are the period
//    Addr=6    holding current PWM value in range of 0 to 100 percent
//
//  The setup register has the following bits
//   Bit 12   on/off     1==on.  All output high for OFF -- brake mode
//   Bit 11   direction  1==abcd, 0=dcba
//   Bit 10   half/full  1==half
//   bit 9,8  00         period clock is 1 microsecond
//            01         period clock is 10 microseconds
//            10         period clock is 100 microseconds
//            11         period clock is 1 millisecond
//
/////////////////////////////////////////////////////////////////////////
module stepb(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
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

    wire   m1clk   =  clocks[`M1CLK];      // utility 1.000 millisecond pulse
    wire   u100clk =  clocks[`U100CLK];    // utility 100.0 microsecond pulse
    wire   u10clk  =  clocks[`U10CLK];     // utility 10.00 microsecond pulse
    wire   u1clk   =  clocks[`U1CLK];      // utility 1.000 microsecond pulse
    wire   ain1;
    wire   ain2;
    wire   bin1;
    wire   bin2;

    assign   pins[0] = ain1;
    assign   pins[1] = ain2;
    assign   pins[2] = bin1;
    assign   pins[3] = bin2;
 
    wire   myaddr;           // ==1 if a correct read/write on our address
    reg    [11:0] target;    // Step target.
    reg    [7:0] period;     // Inter-step period
    reg    [4:0] setup;      // Setup has on/off, direction, half/full steps, and frequency selector
    wire   onoff,dir;        // on/off and direction
    wire   full,half;        // indicators for full or half steps
    reg    [7:0] pdiv;       // period clock divider and holding current PWM counter
    wire   pclk;             // period input clock
    reg    [2:0] phac;       // phase accumulator -- actual stepper position
    reg    [6:0] holding;    // holding current as a 7 bit number

    assign onoff = setup[4]; // on/off bit
    assign dir   = setup[3];
    assign full = onoff & (~setup[2]);
    assign half = onoff & setup[2];
    assign pclk = (setup[1:0] == 0) ? u1clk :
                  (setup[1:0] == 1) ? u10clk :
                  (setup[1:0] == 2) ? u100clk : m1clk ;

    initial
    begin
        target = 0;
        period = 8'hff;
        setup = 0;
        phac = 0;
    end

    always @(posedge CLK_I)
    begin
        if (TGA_I & myaddr & WE_I)  // latch data on a write
        begin
            if (ADR_I[2:0] == 0)
                target[11:8] <= DAT_I[3:0];
            if (ADR_I[2:0] == 1)
                target[7:0] <= DAT_I[7:0];
            if (ADR_I[2:0] == 2)
                target[11:8] <= target[11:8] + DAT_I[3:0];
            if (ADR_I[2:0] == 3)
                target <= target + {4'h0,DAT_I[7:0]};
            if (ADR_I[2:0] == 4)
            begin
                setup <= DAT_I[4:0];
            end
            if (ADR_I[2:0] == 5)
            begin
                period <= DAT_I[7:0];
            end
            if (ADR_I[2:0] == 7)
                holding <= DAT_I[6:0];
        end
        else if ((target != 0) && pclk && (onoff == 1))  // Decrement the period counter
        begin
            if (pdiv == 0)
            begin
                pdiv <= period;
                target <= target - 12'h001;
                if (half)
                    phac <= (dir) ? phac + 3'h1 : phac - 3'h1;
                else
                    phac <= (dir) ? phac + 3'h2 : phac - 3'h2;
            end
            else
                pdiv <= pdiv - 8'h01;
        end
        else if (u1clk && (target == 0))    // apply holding current
        begin
            pdiv <= pdiv - 8'h01;
        end
    end

    // Assign the outputs.  See the full/half tables at the top of this file
    assign ain1 = (onoff == 0) || ((target == 0) && (pdiv[6:0] >= holding)) ||
                  ((full) && ((phac[2:1] == 0) || (phac[2:1] == 3))) ||
                  ((half) && ((phac[2:0] == 0) || (phac[2:0] == 6) || (phac[2:0] == 7)));
    assign ain2 = (onoff == 0) || ((target == 0) && (pdiv[6:0] >= holding)) ||
                  ((full) && ((phac[2:1] == 1) || (phac[2:1] == 2))) ||
                  ((half) && ((phac[2:0] == 2) || (phac[2:0] == 3) || (phac[2:0] == 4)));
    assign bin1 = (onoff == 0) || ((target == 0) && (pdiv[6:0] >= holding)) ||
                  ((full) && ((phac[2:1] == 0) || (phac[2:1] == 1))) ||
                  ((half) && ((phac[2:0] == 0) || (phac[2:0] == 1) || (phac[2:0] == 2)));
    assign bin2 = (onoff == 0) || ((target == 0) && (pdiv[6:0] >= holding)) ||
                  ((full) && ((phac[2:1] == 2) || (phac[2:1] == 3))) ||
                  ((half) && ((phac[2:0] == 4) || (phac[2:0] == 5) || (phac[2:0] == 6)));
 
    assign myaddr = (STB_I) && (ADR_I[7:3] == 0);
    assign DAT_O = (~myaddr || WE_I) ? DAT_I : 
                     (ADR_I[2:0] == 0) ? {4'h0,target[11:8]} :
                     (ADR_I[2:0] == 1) ? target[7:0] :
                     (ADR_I[2:0] == 2) ? 8'h00 :   // Nothing to report for the increment register
                     (ADR_I[2:0] == 3) ? 8'h00 :
                     (ADR_I[2:0] == 4) ? {3'h0,setup} :
                     (ADR_I[2:0] == 5) ? period :
                     (ADR_I[2:0] == 6) ? 8'h00 :
                     (ADR_I[2:0] == 7) ? {1'h0,holding} :
                     8'h00;

    assign onoff = setup[4]; // on/off bit


    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule

