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
// See LICENSE.txt for more information.
// *********************************************************

//////////////////////////////////////////////////////////////////////////
//
//  File: pulse2.v;   Dual channel pulse generator
//
//  Registers: (high byte)
//      Reg 0:  Period in steps of 10 ns.  Maximum count is 1024.
//      Reg 2:  Pulse 1 width in units of 10 ns.
//      Reg 4:  Pulse 2 start in units of 10ns.
//      Reg 6:  Pulse 2 stop time in units of 10 ns.
//
/////////////////////////////////////////////////////////////////////////
module pulse2(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
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

    assign pins[0] = p1p;    // Pulse 1 uninverted
    assign pins[1] = p1n;    // Pulse 1 inverted
    assign pins[2] = p2p;    // Pulse 2 uninverted
    assign pins[3] = p2n;    // Pulse 2 inverted
 
    wire   myaddr;           // ==1 if a correct read/write on our address
    reg    [9:0] period;     // overall period of the pulses
    reg    [9:0] p1width;    // output 1 pulse width
    reg    [9:0] p2start;    // start of output 2 from start of cycle
    reg    [9:0] p2end;      // output 2 pulse goes low at this count
    reg    p1;               // state of output 1
    reg    p2;               // state of output 2
    reg    [9:0] pcount;     // period counter
    wire   n10clk;           // 10 ns clock

    // get the 100 MHz clock
    clk20to100 pulse20to100(CLK_I, n10clk);

    initial
    begin
        period = 10'd1000;
        p1width = 10'd0;    // P1 is off to start
        p2start = 10'd0;    // P2 is off to start
        p2end = 10'd0;
        pcount = 10'd0;
    end

    always @(posedge CLK_I)
    begin
        if (TGA_I & myaddr & WE_I)  // Get configuration from host
        begin
            if (ADR_I[2:0] == 0)
                period[9:8] <= DAT_I[1:0];
            else if (ADR_I[2:0] == 1)
                period[7:0] <= DAT_I[7:0];
            else if (ADR_I[2:0] == 2)
                p1width[9:8] <= DAT_I[1:0];
            else if (ADR_I[2:0] == 3)
                p1width[7:0] <= DAT_I[7:0];
            else if (ADR_I[2:0] == 4)
                p2start[9:8] <= DAT_I[1:0];
            else if (ADR_I[2:0] == 5)
                p2start[7:0] <= DAT_I[7:0];
            else if (ADR_I[2:0] == 6)
                p2end[9:8] <= DAT_I[1:0];
            else if (ADR_I[2:0] == 7)
                p2end[7:0] <= DAT_I[7:0];
        end
    end

    // Counter / timer logic
    always @(posedge n10clk)
    begin
        if ((pcount + 10'd1) == period)
            pcount <= 10'd0;
        else
            pcount <= pcount + 10'd1;

        if (pcount == p1width)
        begin
            p1 <= 1'b0;
            p2 <= 1'b0;
        end
        else if (pcount == p2end)
        begin
            p1 <= 1'b0;
            p2 <= 1'b0;
        end
        else if (pcount == p2start)
        begin
            p1 <= 1'b0;
            p2 <= 1'b1;
        end
        else if (pcount == 10'd0)
        begin
            p1 <= 1'b1;
            p2 <= 1'b0;
        end
    end

    // Assign the outputs.
    assign p1p = p1;
    assign p1n = ~p1;
    assign p2p = p2;
    assign p2n = ~p2;

    assign myaddr = (STB_I) && (ADR_I[7:3] == 0);
    assign DAT_O = DAT_I;

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule


// convert 20 MHz system cloce to 100 MHz.
module clk20to100(CLKIN_IN, CLKFX_OUT);
    input CLKIN_IN;
    output CLKFX_OUT;

    wire CLKFX_BUF;
    assign CLKFX_OUT = CLKFX_BUF;

   DCM_SP #(
      .CLKDV_DIVIDE(2.0),          // Divide by: 1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5
                                   //   7.0,7.5,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0 or 16.0
      .CLKFX_DIVIDE(1),            // Can be any integer from 1 to 32
      .CLKFX_MULTIPLY(5),         // Can be any integer from 2 to 32
      .CLKIN_DIVIDE_BY_2("FALSE"), // TRUE/FALSE to enable CLKIN divide by two feature
      .CLKIN_PERIOD(60.0),         // Specify period of input clock
      .CLKOUT_PHASE_SHIFT("NONE"), // Specify phase shift of NONE, FIXED or VARIABLE
      .CLK_FEEDBACK("NONE"),         // Specify clock feedback of NONE, 1X or 2X
      .DESKEW_ADJUST("SYSTEM_SYNCHRONOUS"), // SOURCE_SYNCHRONOUS, SYSTEM_SYNCHRONOUS or
                                            //   an integer from 0 to 15
      .DFS_FREQUENCY_MODE("HIGH"),  // HIGH or LOW frequency mode for frequency synthesis
      .DLL_FREQUENCY_MODE("HIGH"),  // HIGH or LOW frequency mode for DLL
      .DUTY_CYCLE_CORRECTION("TRUE"), // Duty cycle correction, TRUE or FALSE
      .FACTORY_JF(16'hC080),        // FACTORY JF values
      .PHASE_SHIFT(0),             // Amount of fixed phase shift from -255 to 255
      .STARTUP_WAIT("FALSE")       // Delay configuration DONE until DCM LOCK, TRUE/FALSE
   ) DCM_SP_inst (
      .CLK0(),                     // 0 degree DCM CLK output
      .CLK180(),                   // 180 degree DCM CLK output
      .CLK270(),                   // 270 degree DCM CLK output
      .CLK2X(),                    // 2X DCM CLK output
      .CLK2X180(),                 // 2X, 180 degree DCM CLK out
      .CLK90(),                    // 90 degree DCM CLK output
      .CLKDV(),                    // Divided DCM CLK out (CLKDV_DIVIDE)
      .CLKFX(CLKFX_BUF),           // DCM CLK synthesis out (M/D)
      .CLKFX180(),                 // 180 degree CLK synthesis out
      .LOCKED(),                   // DCM LOCK status output
      .PSDONE(),                   // Dynamic phase adjust done output
      .STATUS(),                   // 8-bit DCM status bits output
      .CLKFB(),                    // DCM clock feedback
      .CLKIN(CLKIN_IN),            // Clock input (from IBUFG, BUFG or DCM)
      .PSCLK(1'b0),                // Dynamic phase adjust clock input
      .PSEN(1'b0),                 // Dynamic phase adjust enable input
      .PSINCDEC(1'b0),             // Dynamic phase adjust increment/decrement
      .RST(1'b0)                   // DCM asynchronous reset input
   );

   // End of DCM_SP_inst instantiation
endmodule

