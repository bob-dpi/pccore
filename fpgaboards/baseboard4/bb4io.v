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
//  File: board.v;   Host access to the FPGA board-specific peripherals.
//
//  This file is part of the glue that ties an FPGA board to the Peripheral
//  Controller bus and peripherals.  It serves the following functions:
//  - Host access to the driver ID list 
//  - Generates clocks from 100 MHz to 1 Hz.
//  - Host access to buttons and LEDs as appropriate
//  - Host access to configuration memory if available
//
//  Note that while called "board.v" in the build system the host peripheral
//  has a name to match the board in use.  This gives the host access to the
//  board-specific features such as buttons and LEDs if they are on the
//  board.
//
//////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////
//
//  Board registers for the Demand Peripherals Baseboard4
//
//  Reg 0: Buttons.  Read-only, 8 bit.  Auto-send on change. Sends both
//         the LED value and the button values.
//  Reg 64-95: Sixteen 16-bit driver IDs
//
/////////////////////////////////////////////////////////////////////////
module bb4io(CLK_O,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,BRDIO,PCPIN);
    output CLK_O;            // system clock
    input  WE_I;             // direction of this transfer. Read=0; Write=1
    input  TGA_I;            // ==1 if reg access, ==0 if poll
    input  STB_I;            // ==1 if this peri is being addressed
    input  [7:0] ADR_I;      // address of target register
    output STALL_O;          // ==1 if we need more clk cycles to complete
    output ACK_O;            // ==1 if we claim the above address
    input  [7:0] DAT_I;      // Data INto the peripheral;
    output [7:0] DAT_O;      // Data OUTput from the peripheral, = DAT_I if not us.
    output [`MXCLK:0] clocks; // Array of clock pulses from 10ns to 1 second
    inout  [`BRD_MX_IO:0]  BRDIO;     // Board IO 
    inout  [`MX_PCPIN:0]   PCPIN;     // Peripheral Controller Pins (for Pmods)
 
    wire   myaddr;           // ==1 if a correct read/write on our address
    reg    [2:0] btn0;       // bring buttons into our clock domain
    reg    [2:0] btn1;       // bring buttons into our clock domain
    reg    data_ready;       // ==1 if we have new data to send up to the host
    wire   [15:0] perid;     // ID of peripheral in core specified by ADR_I 
    perilist periids(ADR_I[4:1], perid);
    wire   n10clk;           // ten nanosecond clock

    initial
    begin
        btn0 = 3'b000;
        btn1 = 3'b000;
        data_ready = 0;
    end


    // Generate the 100 MHz clock from the board clock input Use a PLL
    // to try to get it to 100 MHz (actual=102.3), and use the 100 MHz
    // clock to derive all the other clock frequencies
    `ifdef SYNTHESIS   // if synthesizing design for FPGA
        ck100mhz boardclkto100(BRDIO[`BRD_CLOCK], n10clk);
    `else
        assign n10clk = BRDIO[`BRD_CLOCK];   // for simulation
    `endif
    clocks gensysclks(n10clk, CLK_O, clocks);


    // Bring the Buttons into our clock domain.
    always @(posedge CLK_O)
    begin
        btn0 <= BRDIO[`BRD_MX_BTN:`BRD_BTN_0];
        btn1 <= btn0;

        // clear data_ready register on a read
        if (TGA_I & myaddr & ~WE_I)  // clear marked register on any read
            data_ready <= 0;

        // edge detection for sending data up to the host
        else if (btn1 != btn0)
        begin
            data_ready <= 1;
        end
    end
 

    // data out is the button if a read on us, our data ready send command 
    // if a poll from the bus interface, and data_in in all other cases.
    assign myaddr = (STB_I) && (ADR_I[7] == 0);
    assign DAT_O = (~myaddr) ? DAT_I : 
                    (~TGA_I & data_ready) ? 8'h01 :   // send up one byte if data available
                     (TGA_I && (ADR_I[6] == 0)) ? {5'h00,btn1} :
                     (TGA_I && (ADR_I[6] == 1) && (ADR_I[0] == 0)) ? perid[15:8] :
                     (TGA_I && (ADR_I[6] == 1) && (ADR_I[0] == 1)) ? perid[7:0] :
                     8'h00;

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

    // Connect LED latch to LED pins
    assign BRDIO[`BRD_MX_LED:`BRD_LED_0] = PCPIN[7:0];


endmodule



//////////////////////////////////////////////////////////////////////////
//
// ck100mhz() generates a 100 MHz clock given the 12 MHz board clock as input
//
module ck100mhz(CLKIN_IN, CLKFX_OUT);
    input CLKIN_IN;
    output CLKFX_OUT;
 
    wire CLKFX_BUF;
    assign CLKFX_OUT = CLKFX_BUF;

   DCM_SP #(
      .CLKDV_DIVIDE(2.0),          // Divide by: 1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5
                                   //   7.0,7.5,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0 or 16.0
      .CLKFX_DIVIDE(2),            // Can be any integer from 1 to 32
      .CLKFX_MULTIPLY(16),         // Can be any integer from 2 to 32
      .CLKIN_DIVIDE_BY_2("FALSE"), // TRUE/FALSE to enable CLKIN divide by two feature
      .CLKIN_PERIOD(60.0),         // Specify period of input clock
      .CLKOUT_PHASE_SHIFT("NONE"), // Specify phase shift of NONE, FIXED or VARIABLE
      .CLK_FEEDBACK("1X"),         // Specify clock feedback of NONE, 1X or 2X
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


