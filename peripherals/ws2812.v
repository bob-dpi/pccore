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
//  File: ws2812.v;  Quad control of ws2812 LEDs 
//
//  Accept up to 256 bytes from the host and shift each bit out
//  using the timing defined for the World Semi ws2812 RGB(W) LED.
//  A zero bit is high for 350 ns and low for 800.  A one bit is
//  high for 700 ns and low for 600.
//
//  Because of the large amount of data and the fairly high
//  output frequency the circuit uses the busy line to apply
//  back pressure to the bus interface.  A 256 byte packet
//  takes about 2.5 ms.  This can limit the USB bandwidth.
//
//  Use the 'no-increment' write command so send multiple bytes
//  of data to the same register.
//
//  Registers are
//    Addr=0    WS2812 data for output 0
//    Addr=1    WS2812 data for output 1
//    Addr=2    WS2812 data for output 2
//    Addr=3    WS2812 data for output 3
//    Addr=4    Config: LSB=invertoutput
//
/////////////////////////////////////////////////////////////////////////
module ws2812(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
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
    reg    [7:0] wsdata;     // ws2813 byte to send
    reg    firstwrite;       // set if this is the first clock of a ws2812 write
                             // firstwrite is needed since an xfer spans many sysclks.
    reg    [2:0] bitcnt;     // counter for which bit we are sending
    reg    [3:0] pulsecnt;   // the number of sysclk to hold the output high or low
    reg    outstate;         // whether we are in the high or low part of an output pulse
    reg    invertoutput;     // invert output to pins fi set
    wire   [3:0] targetwidth;  // one of 7,15,12,or 14 depending bit to send and outstate
    wire   inxfer;           // doing a transfer

    `define ADDRCONFIG (4)
    assign targetwidth = (~wsdata[7] & outstate) ?  4'h6 : // 350 ns (6) for high part of a zero bit
                         (~wsdata[7] & ~outstate) ? 4'hf : // 800 ns (14) for low part of a zero bit
                         (wsdata[7] & outstate) ?   4'hd : // 700 ns (14) for high part of a one bit
                                                    4'hb;  // 600 ns (6) for low part of a one bit

    initial
    begin
        firstwrite = 1;
        invertoutput = 0;
    end

    always @(posedge CLK_I)
    begin
        if (~myaddr)       // if not us ...
        begin
            firstwrite <= 1;          // reset firstwrite
            bitcnt <= 0;
            outstate <= 0;
            pulsecnt <= 0;
        end
        // Handle write requests from the host
        if (TGA_I & myaddr & WE_I & (ADR_I[2:0] == `ADDRCONFIG))  // invertoutput == Addr4
            invertoutput <= DAT_I[0]; 
        else if (TGA_I & WE_I & firstwrite)  // latch on first sysclk of write
        begin
            wsdata <= DAT_I[7:0];
            firstwrite <= 0;          // set flag to run state machine
            outstate <= 1;
        end
        else if (TGA_I & WE_I & ~firstwrite)  // write but not first sysclk
        begin
            // At this point we are holding the busy line high while we shift out
            // the bits in wsdata.  The shift counter is bitcnt, the pulse width
            // counter is pulsecnt, and whether we are in the high or low part of
            // output pulse is set by outstate.

            // The wire targetwidth has the desired high/low count for pulsecnt.
            if (pulsecnt == targetwidth)
            begin
                outstate <= ~outstate;
                pulsecnt <= 0;
                if (~outstate)
                begin
                    // Shift out the next bit and reset the pulse width counter
                    // if we are at the end of the pulse low part of the output.  
                    // Shift up since data is sent MSB first.
                    wsdata <= (wsdata << 1);
                    bitcnt <= bitcnt + 3'h1;
                    if (bitcnt == 7)
                    begin
                        firstwrite <= 1;
                    end
                end
            end
            else
            begin
                // continue waiting for end of pulsecnt
                pulsecnt <= pulsecnt + 4'h1;
            end
        end
    end

    // Assign the outputs.
    // in transfer if not last bit, low output, and final pulsewidth count
    assign inxfer = ~((bitcnt == 7) & (outstate == 0) & (pulsecnt == targetwidth));
    // led data valid if in an transfer.  invert output if set
    assign pins[0] = ((ADR_I[2:0] == 0) & inxfer & outstate) ^ invertoutput;
    assign pins[1] = ((ADR_I[2:0] == 1) & inxfer & outstate) ^ invertoutput;
    assign pins[2] = ((ADR_I[2:0] == 2) & inxfer & outstate) ^ invertoutput;
    assign pins[3] = ((ADR_I[2:0] == 3) & inxfer & outstate) ^ invertoutput;

    // Alternate pin assignments that put all LED data on pin1, (You can
    // connect and LED to pin1 if you want.)  Pin2 is a clock TGA_I that
    // if connected to a D flip-flop can latch the LED data.  This can be
    // really useful if the LEDs are some distance from the FPGA and there
    // might be ringing on the lines.  The D flip-flop is close to the LEDs.
    //assign pins[0] = inxfer & outstate;              // goes to the 7474 D input
    //assign pins[1] = ((pulsecnt == 2) & ~firstwrite);   // goes to the clk input
    //assign pins[2] = ADR_I[0] & inxfer & ~firstwrite;    // 74138 mux input A
    //assign pins[3] = ADR_I[1] & inxfer & ~firstwrite;    // 74138 mux input B


    // Delay while we output the ws2812 data.
    // Busy_out is 0 if not us.  Config writes take one clock cycle
    // so we don't assert STALL_O for them.  We assert busy_out while we
    // are sending data to the LEDs.
    assign STALL_O = (~myaddr) ? 0 : 
                      (ADR_I[2:0] == `ADDRCONFIG) ? 0 : inxfer ;

    assign myaddr = (STB_I) && (ADR_I[7:3] == 0);

    // Loop in-to-out where appropriate
    assign ACK_O = myaddr;
    assign DAT_O = DAT_I;                       // we are a write-only peripheral

endmodule

