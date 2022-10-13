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
//  File: servo4.v;   Four channel servo controller
//
//  Registers: (high byte)
//      Reg 0:  Servo channel 0 pulse width with a resolution of 50 ns.
//              The value in the register specifies the 50 ns count at
//              which the pin goes high.  The pin stays high until the
//              count reaches 2.5 milliseconds or a count of 50000 50
//              nanosecond pulses.  Thus to get a pulse width of 1.0 ms
//              you would subtract 1.0 from 2.5 giving how long the low
//              time should be.  The low time would be 1.5 ms or a count
//              of 30000 clock pulses, or a count of 16'h7530.
//      Reg 2:  Servo 1 low pulse width in units of 50 ns.
//      Reg 4:  Servo 2 low pulse width in units of 50 ns.
//      Reg 6:  Servo 3 low pulse width in units of 50 ns.
//
//  Each pulse is from 0 to 2.50 milliseconds.  The cycle time for
//  all four servoes is 20 milliseconds.
//
/////////////////////////////////////////////////////////////////////////
module servo4(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
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

 
    wire   myaddr;           // ==1 if a correct read/write on our address
    wire   [7:0] doutl;      // RAM output lines
    wire   [7:0] douth;      // RAM output lines
    wire   [3:0] raddr;      // RAM address lines
    wire   wclk;             // RAM write clock
    wire   wenl;             // Low RAM write enable
    wire   wenh;             // High RAM write enable
    reg    [2:0] servoid;    // Which servo has the clock
    reg    [15:0] servoclk;  // Comparison clock
    reg    val;              // Latched value of the comparison


    // Register array in RAM
    sv4ram16x8 freqramL(doutl,raddr,DAT_I,wclk,wenl);
    sv4ram16x8 freqramH(douth,raddr,DAT_I,wclk,wenh);


    always @(posedge CLK_I)
    begin
        if (~(TGA_I & myaddr & WE_I))  // Only when the host is not writing our regs
        begin
            if (servoclk[15:0] == 49999)  // 2.500 ms @ 20 MHz
            begin
                val <= 0;
                servoclk <= 0;
                // 8 servos at 2.5 ms each is 20 ms
                servoid <= servoid + 3'h1;
            end
            else
            begin
                // check for a value match
                if ((doutl == servoclk[7:0]) && (douth == servoclk[15:8]))
                    val <= 1;

                servoclk <= servoclk + 16'h0001;   // increment PWM clock
            end
        end
    end


    // Assign the outputs.
    assign pins[3] = (servoid != 3) ? 1'b0 : val ;
    assign pins[2] = (servoid != 2) ? 1'b0 : val ;
    assign pins[1] = (servoid != 1) ? 1'b0 : val ;
    assign pins[0] = (servoid != 0) ? 1'b0 : val ;

    assign wclk  = CLK_I;
    assign wenh  = (TGA_I & myaddr & WE_I & (ADR_I[0] == 0)); // latch data on a write
    assign wenl  = (TGA_I & myaddr & WE_I & (ADR_I[0] == 1)); // latch data on a write
    assign raddr = (TGA_I & myaddr) ? {2'h0,ADR_I[2:1]} : {1'h0,servoid} ;

    assign myaddr = (STB_I) && (ADR_I[7:3] == 0);
    assign DAT_O = (~myaddr) ? DAT_I :
                    (TGA_I & (ADR_I[0] == 0)) ? douth :
                    (TGA_I & (ADR_I[0] == 1)) ? doutl :
                    8'h00 ; 

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule


module sv4ram16x8(dout,addr,din,wclk,wen);
    output [7:0] dout;
    input  [3:0] addr;
    input  [7:0] din;
    input  wclk;
    input  wen;

    reg      [7:0] ram [15:0];

    always@(posedge wclk)
    begin
        if (wen)
            ram[addr] <= din;
    end

    assign dout = ram[addr];

endmodule

