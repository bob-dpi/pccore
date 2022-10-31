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
//  Reg 0: Switch 0-7.  Read-only, 8 bit.  Auto-send on change.
//  Reg 1: Switch 8-15.  Read-only, 8 bit.  Auto-send on change.
//  Reg 2: Switch 16-20.  Read-only, 8 bit.  The buttons.
//  Reg 3: unused
//  Reg 4: segments for left display
//  Reg 5: segments
//  Reg 6: segments
//  Reg 7: segments for right display
//
//  Reg 64-95: Sixteen 16-bit driver IDs
//
/////////////////////////////////////////////////////////////////////////
module basys3(CLK_O,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,BRDIO,PCPIN);
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
    reg    [15:0] ledreg;    // register the PCPINs to drive the monitor LEDs
    reg    [20:0] swreg1;    // 16 slide switches plus 5 push buttons
    reg    [20:0] swreg2;    // Used for debounce
    reg    [20:0] swreg3;    // Used for debounce
    reg    data_ready;       // Switches changed state . Send to host
    reg    [7:0] segs[3:0];  // Array of segment values
    reg    [1:0] digit;      // Counter to specify displayed digit

    initial
    begin
        ledreg = 0;
        swreg1 = 0;
        swreg2 = 0;
        swreg3 = 0;
        data_ready = 0;
        segs[0] = 8'h40;
        segs[1] = 8'h40;
        segs[2] = 8'h40;
        segs[3] = 8'h40;
        digit = 0;
    end


    // The board clock is already at 100 MHz.  (nice!)
    // Use it to generate the rest of the clocks.
    assign n10clk = BRDIO[`BRD_CLOCK];   // for simulation
    clocks gensysclks(n10clk, CLK_O, clocks);


    // Copy pin values on ports C and D to the LEDs.  
    always @(posedge clocks[`U10CLK])
    begin
        ledreg <= PCPIN[31:16];
    end 


    // Bring the Buttons into our clock domain.
    always @(posedge CLK_O)
    begin

        // clear data_ready register on a read
        if (TGA_I & myaddr & ~WE_I)  // clear marked register on any read
        begin
            data_ready <= 0;
        end

        // latch segment data from host
        else if (TGA_I & myaddr & WE_I & (ADR_I[6:2] == 5'h01))  // latch segment data
        begin
            segs[ADR_I[1:0]] <= DAT_I;
        end

        // edge detection for sending data up to the host
        else if (clocks[`M10CLK])
        begin
            swreg1 <= BRDIO[`BRD_MX_SW:`BRD_SW_0];
            swreg2 <= swreg1;
            swreg3 <= swreg2;

            // edge detection
            if (((swreg1 ^ swreg2) & ~(swreg2 ^ swreg3)) != 21'h0)
            begin
                data_ready <= 1;
            end
        end

        // Switch from one seven segment digit to the next ever millisecond
        else if (clocks[`M1CLK])
        begin
            digit <= digit + 2'h1;
        end
    end
 

    // data out is the button if a read on us, our data ready send command 
    // if a poll from the bus interface, and data_in in all other cases.
    assign myaddr = (STB_I) && (ADR_I[7] == 0);
    assign DAT_O = (~myaddr) ? DAT_I : 
                    (~TGA_I & data_ready) ? 8'h03 :   // send up three bytes if data available
                     (TGA_I && (ADR_I[6] == 0) && (ADR_I[1:0] == 2'h0)) ? swreg1[7:0] :
                     (TGA_I && (ADR_I[6] == 0) && (ADR_I[1:0] == 2'h1)) ? swreg1[15:8] :
                     (TGA_I && (ADR_I[6] == 0) && (ADR_I[1:0] == 2'h2)) ? {3'h0,swreg1[20:16]} :
                     (TGA_I && (ADR_I[6] == 1) && (ADR_I[0] == 0)) ? perid[15:8] :
                     (TGA_I && (ADR_I[6] == 1) && (ADR_I[0] == 1)) ? perid[7:0] :
                     8'h00;

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

    // Connect LED latch to LED pins
    assign BRDIO[`BRD_MX_LED:`BRD_LED_0] = ledreg;

    // Set the segment and digit driver pins
    assign BRDIO[`BRD_SEG_DP:`BRD_SEG_A] = ~segs[digit];
    assign BRDIO[`BRD_DGT_3:`BRD_DGT_0] = (digit == 2'h0) ? 4'b0111 :
                                          (digit == 2'h1) ? 4'b1011 :
                                          (digit == 2'h2) ? 4'b1101 : 4'b1110 ;



endmodule


