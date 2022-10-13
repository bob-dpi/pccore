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
//  File: dpout32.v;   32 independent channels of output
//
//  Registers: 8 bit, read-write
//      Reg 0:   Bit 0 is the data out value for pin 7 and is read-write.
//               Bit 1 is the data out value for pin 23 and is read-write.
//      Reg 1:   As above for pins  6 and 22.

//      Reg 2:   As above for pins  5 and 21.
//      Reg 3:   As above for pins  4 and 20.
//      Reg 4:   As above for pins  3 and 19.
//      Reg 5:   As above for pins  2 and 18.
//      Reg 6:   As above for pins  1 and 17.
//      Reg 7:   As above for pins  0 and 16.
//      Reg 8:   As above for pins 15 and 31.
//      Reg 9:   As above for pins 14 and 30.
//      Reg 10:  As above for pins 13 and 29.
//      Reg 11:  As above for pins 12 and 28.
//      Reg 12:  As above for pins 11 and 27.
//      Reg 13:  As above for pins 10 and 26.
//      Reg 14:  As above for pins  9 and 25.
//      Reg 15:  As above for pins  8 and 24.
//
//
//  HOW THIS WORKS
//      The out32 card has four 74LVC595 serial-to-parallel chips, 
//  one cascaded pair for the least significant and one cascaded pair 
//  for the most significant 16-bit word.  A 7474 dual D flip-flop is 
//  used to synchronize the parallel loads and bit shifts.  The Verilog 
//  below uses 'bst' to count the 16 bits of each shift register pair 
//  and 'gst' as the state machine controller for the 7474 (and hence 
//  the loading and shifting).
//
//  The signals from the Baseboard are used as follows:
//    Pin 2: DATA1      -- data to be shifted in for the most significant 16-bit word
//    Pin 4: CLKA       -- used to create shift clock (SCK)
//    Pin 6: CLKB/CLRA- -- used in conjunction with DATA1 to create data latch clock (RCK)
//    Pin 8: DATA2      -- data to be shifted in for the least significant 16-bit word
//      
//  The cabling from the Baseboard to the out32 has ringing on
//  all of the lines at any transition.  To overcome this we
//  use a 7474.  Ringing on the reset or clk line of a 7474 has
//  no effect on the output if the D input is held constant
//  during the ringing.  The data lines (pin2 and pin8) must not 
//  change on either rising or falling edge of pin4 and the rising edge
//  of pin6.   This is the goal of the gst state machine.
//  
// GST  Pin  8/6/4/2    State
// #0        0/0/0/0    Start state sets up DATA1, CLKA, and CLKB lo
// #1        0/1/0/0    Release CLRA-/rising edge of CLKB with DATA1 lo ensures no RCK
// #2       d2/1/0/d1   Setup data -- d1 is next bit of MS word, d2 is next bit of LS word
// #3       d2/1/1/d1   Rising egde of CLKA causes shift clock to go hi, shifting in next data bits
//                      (repeat 0-3 for 16 bits)
// #4        0/0/0/1    Setup DATA1 hi to create RCK
// #5        0/1/0/1    Rising edge of CLKB with DATA1 hi causes RCK to latch data
// #6        0/0/0/0    Release DATA1 and CLKB to setup to release RCK
// #7        0/0/1/0    Rising edge of CLKB with DATA1 low releases RCK
//
/////////////////////////////////////////////////////////////////////////
module dpout32(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
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

    assign pins[0] = pin2;   // Pin2 to the out32 card.  Clock control and MS data.
    assign pins[1] = pin4;   // Pin4 to the out32 card.  Clock control.
    assign pins[2] = pin6;   // Pin6 to the out32 card.  Clock control.
    assign pins[3] = pin8;   // Pin8 to the out32 card.  LS data.

    // State variables
    reg    [3:0] bst;        // Bit number for current card access (0-15)
    reg    [2:0] gst;        // global state for xfer from card (0-5)
    reg    dataready;        // set=1 to wait for an autosend to host
    reg    changepending;    // set=1 while finishing all 16 bits to then set dataready

    // Addressing and bus interface lines 
    wire   myaddr;           // ==1 if a correct read/write on our address
    wire   [1:0] rout;       // RAM output lines
    wire   [1:0] ramedge;    // Edge transition output info
    wire   [3:0] raddr;      // RAM address lines
    wire   [1:0] rin;        // RAM input lines
    wire   wen;              // RAM write enable
    dpout32_16x1 out32_ms(rout[1],raddr,rin[1],clk,wen);   // MS word
    dpout32_16x1 out32_ls(rout[0],raddr,rin[0],clk,wen);   // LS word


    initial
    begin
        gst = 3'h0;
        bst = 4'h0;
        dataready = 0;
        changepending = 0;
    end

    always @(posedge CLK_I)
    begin
        // Start transfer when host writes to the last address
        if (TGA_I && myaddr && WE_I && (ADR_I[3:0] == 15))
        begin
            // start shifting bits
            gst <= 3'h0;
        end

        // if not reading/writing from host
        else if (~(TGA_I && myaddr && WE_I))
        begin
            if (gst < 3'h2)
            begin
                gst <= gst + 3'h1;
            end
            else if (gst == 3'h2)
            begin
                // select the next bits to be shifted
                gst <= gst + 3'h1;                
                bst <= bst + 4'h1;
            end
            else if (gst == 3'h3)
            begin
                // shifting 16 bits (states 0-3) then go to latch states
                gst <= (bst == 15) ? 3'h4 : 3'h0;
            end
            else if (gst < 3'h7)
            begin
                // data latch
                gst <= gst + 3'h1;
            end
            else
            begin
                // wait for another host write
            end
        end
    end

    // assign the outputs
    assign pin4 = (gst == 3'h3);
    assign pin6 = ((gst == 3'h1) || (gst == 3'h2) || (gst == 3'h3) || (gst == 3'h5) || (gst == 3'h7));
    assign pin2 = ((((gst == 3'h2) || (gst == 3'h3)) && rout[1]) || (gst == 3'h4) || (gst == 3'h5));
    assign pin8 = (((gst == 3'h2) || (gst == 3'h3)) && rout[0]);

    // assign RAM signals
    assign myaddr = (STB_I) && (ADR_I[7:4] == 0);
    assign wen = (TGA_I & myaddr & WE_I);
    assign raddr = (TGA_I & myaddr) ? ADR_I[3:0] : bst;
    assign rin[1] = (TGA_I & myaddr & WE_I) ? DAT_I[1] : rout[1];
    assign rin[0] = (TGA_I & myaddr & WE_I) ? DAT_I[0] : rout[0];
    assign DAT_O = (TGA_I & myaddr & ~WE_I) ? {6'h00,rout} : DAT_I; 

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule


module dpout32_16x1(dout,addr,din,wclk,clken);
    output   dout;
    input    [3:0] addr;
    input    din;
    input    wclk;
    input    clken;

    reg      ram [15:0];

    always@(posedge wclk)
    begin
        if (clken)
            ram[addr] <= din;
    end

    assign dout = ram[addr];

endmodule



