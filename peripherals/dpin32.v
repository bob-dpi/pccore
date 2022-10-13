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
//  File: dpin32.v;   Thirty-two channel digital input
//
//  Registers: 8 bit, read-write
//      Reg 0:  Bit 0 is the value at pin 1 and is read-only.
//              Bit 1 is set to enable interrupt on change and is read-write
//      Reg 1:  As above for pin 2
//      Reg 2:  As above for pin 3
//      Reg 3:  As above for pin 4
//      Reg 4:  As above for pin 5
//      Reg 5:  As above for pin 6
//      Reg 6:  As above for pin 7
//      Reg 7:  As above for pin 8
//      Reg 8:  As above for pin 9
//      Reg 9:  As above for pin 10
//      Reg 10: As above for pin 11
//      Reg 11: As above for pin 12
//      Reg 12: As above for pin 13
//      Reg 13: As above for pin 14
//      Reg 14: As above for pin 15
//      Reg 15: As above for pin 16
//      Reg 16: As above for pin 17
//      Reg 17: As above for pin 18
//      Reg 18: As above for pin 19
//      Reg 19: As above for pin 20
//      Reg 20: As above for pin 21
//      Reg 21: As above for pin 22
//      Reg 22: As above for pin 23
//      Reg 23: As above for pin 24
//      Reg 24: As above for pin 25
//      Reg 25: As above for pin 26
//      Reg 26: As above for pin 27
//      Reg 27: As above for pin 28
//      Reg 28: As above for pin 29
//      Reg 29: As above for pin 30
//      Reg 30: As above for pin 31
//      Reg 31: As above for pin 32
//
//
//  HOW THIS WORKS
//      The in32 card has four 74HC165 parallel-to-serial shift
//  registers.  A 7474 dual D flip-flop is used to synchronize
//  the parallel load and the bit shifts.  The Verilog below
//  uses the 'bst' counter to count the 32 bits and the 'gst'
//  counter for the state machine controlling the 7474 (and
//  hence the loading and shifting).
//
//  The state machine for loading and shifting is fairly simple
//  but will be easier to understand if viewed next to the
//  schematic for the in32.
//      
//  The cabling from the Baseboard to the in32 has ringing on
//  all of the lines at any transition.  To overcome this we
//  use a 7474.  Ringing on the reset or clk line of a 7474 has
//  no effect on the output if the D input is held constant
//  during the ringing.  This is the basis for the state machine.
//  
// GST  Pin 6/4/2    State
// #0       0/0/0     Low clock (pin 6) to the SH/LD~ flipflop
// #1       1/0/0     SH/LD~ goes low (pin6 clocked in a zero), latching the 32 input pins
// #2       0/0/1     Set D input to 1 and lo clock to SH/LD~ flipflop
// #3       1/0/1     SH/LD~ goes hi (pin6 clocked in a one) grab the data
// #4       1/1/1     CLK goes hi (pin 4 clocked in a one) shifting data one bit, check for data change
// #5       0/0/1     CLK goes lo (pin 2 clears FF) write data to RAM
//                    (repeat 3, 4 & 5 for each bit)
//
//  If we detect a change on a watched pin we set a flag to
//  Indicate that a change is pending.  We wait until we've
//  transferred all 32 bits before looking at changepending
//  and setting another flag to request an autosend of the
//  data.  We stop reading the pins while waiting for an
//  autosend up to the host.
//
/////////////////////////////////////////////////////////////////////////
module dpin32(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
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

    wire u10clk  =  clocks[`U10CLK];     // utility 10.00 microsecond pulse 

    assign pins[0] = pin2;   // Pin2 to the in32 card.  Clock control.
    assign pins[1] = pin4;   // Pin4 to the in32 card.  Clock control.
    assign pins[2] = pin6;   // Pin6 to the in32 card.  Clock control.
    wire pin8 = pins[3];   // Serial data from the in32

    // State variables
    reg    [4:0] bst;        // Bit number for current card access
    reg    [3:0] gst;        // global state for xfer from card
    reg    dataready;        // set=1 to wait for an autosend to host
    reg    changepending;    // set=1 while finishing all 32 bits to then set dataready
    reg    sample;           // used to bring pin8 into our clock domain

    // Addressing and bus interface lines 
    wire   myaddr;           // ==1 if a correct read/write on our address
    wire   [1:0] rout;       // RAM output lines
    wire   [4:0] raddr;      // RAM address lines
    wire   [1:0] rin;        // RAM input lines
    wire   wen;              // RAM write enable
    dpram32x2in32 ram(rout,raddr,rin,CLK_I,wen); // Register array in RAM


    initial
    begin
        gst = 0;
        bst = 0;
        dataready = 0;
        changepending = 0;
    end

    always @(posedge CLK_I)
    begin
        // reading reg 31 clears the dataready flag
        if (TGA_I && ~WE_I && myaddr && (ADR_I[4:0] == 31))
        begin
            dataready <= 0;
        end

        // else if host is not rd/wr our regs and we're not waiting for autosend
        else if (~(TGA_I & myaddr & WE_I) && (u10clk == 1) && ~dataready)
        begin
            // was there a change on an input?
            // grab the input on 3, compare to old value on 4, write to RAM on 5
            if (gst == 3)
                sample <= pin8;
            if (rout[1] && (sample != rout[0]) && (gst == 4))
                changepending <= 1;
            if (gst < 5)
                gst <= gst + 4'h1;
            else
            begin
                bst <= bst + 5'h01;  // next bit
                if (bst != 31)   // Done with all bits?
                    gst <= 3;
                else
                begin
                    gst <= 0;
                    if (changepending)
                    begin
                        dataready <= 1;
                        changepending <= 0;
                    end
                end
            end
        end
    end


    // Assign the outputs.
    assign pin2 = ~((gst == 0) || (gst == 1));
    assign pin4 = (gst == 4);
    assign pin6 = ~((gst == 0) || (gst == 2) || (gst == 5));

    // assign RAM signals
    assign wen   = (TGA_I & myaddr & WE_I) ||  // latch data on a write
                   (~dataready && (gst == 5));
    assign raddr = (TGA_I & myaddr) ? ADR_I[4:0] : bst ;
    assign rin[1] = (TGA_I & myaddr & WE_I) ? DAT_I[1] : rout[1];
    assign rin[0] = sample;

    assign myaddr = (STB_I) && (ADR_I[7:5] == 0);
    assign DAT_O = (~myaddr) ? DAT_I :
                     (~TGA_I && myaddr && (dataready)) ? 8'h20 :  // Send 32 bytes if ready
                      (TGA_I) ? {6'h00,rout} : 
                       8'h00 ; 

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule



module dpram32x2in32(dout,addr,din,wclk,wen);
    output   [1:0] dout;
    input    [4:0] addr;
    input    [1:0] din;
    input    wclk;
    input    wen;

    reg      [1:0] ram [31:0];

    always@(posedge wclk)
    begin
        if (wen)
            ram[addr] <= din;
    end

    assign dout = ram[addr];

endmodule



