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

/////////////////////////////////////////////////////////////////////////
//
//  File: dptif.v;   Text display interface card
//
//  Registers: 8 bit, read-write
//      Reg 0:  Bits 0-4: keypad status.  0x00 if no key pressed
//              Bits 5-6: not used
//              Bit  7:   rotary encoder button status
//      Reg 1:  Bits 0-3: signed number of rotary pulses.
//              Bits 6-7: not used
//      Reg 2:  Bits 0-4: tone duration in units of 10ms
//              Bits 5-6: note frequency (1454Hz, 726, 484, 363)
//              Bit  7:   set for a slightly louder sound
//      Reg 3:  Bits 0-2: LED control 
//              Bits 4:   Contrast control (has minimal effect)
//      Reg 4:  Bits 0-5: Character FIFO for the text display
//
//
//  HOW THIS WORKS
//      The tif peripheral has five logically distinct sub-peripherals:
//  an interface to a text LCD, a tone generator, 3 LED controllers, a
//  a keypad interface, and a rotary switch interface.  Multiplexing these
//  five peripherals out to the card over four FPGA lines is accomplished
//  by having a 16 bit output shift register and an 8 bit input shift
//  register.
//      Of the 16 output lines, the LEDs get 3, the piezo gets 2, the
//  contrast control get 1, the display gets 10 of which 4 are multiplexed
//  with keypad scanning.  Of the 8 input lines, 5 are used by the keypad
//  and 3 by the rotary encoder.
//
//      
//  The cabling from the Baseboard to the tif has ringing on
//  all of the lines at any transition.  To overcome this we
//  use a 7474.  Ringing on the clk line of a 7474 has no
//  effect on the output if the D input is held constant
//  during the ringing.  The data line (pin2) must not change
//  on either rising or falling edge pin4 and the rising edge
//  of pin6. The Verilog below uses 'bst' to count the 8 bits and
//  'gst' as the state machine controller for the 7474 (and hence
//  the loading and shifting of the I/O registers).
//  
// GST  Pin 6/4/2       State
// #0       0/0/0     Start state
// #1       0/0/0     Set up data value for the RCK/LD- TGA_Is
// #2       1/0/0     Rising edge sets RCK high and LD- low
// #3       0/0/0     Lower clock line that controls RCK/LD flip-flop
// #4       0/0/1     Data is latched.  Now start shifting the bits
// #5       1/0/1     Rising egde of pin4 sets RCK low and LD- high
//                    (repeat 6-10 for each bit)
// #6       1/0/d     Setup the data out value for this bit
//                    (do edge detection for input value during #6)
// #7       1/0/d     Save input value into RAM
// #8       1/1/d     Shift clock goes high, shifting in 'd'.
// #9       1/0/0     Lower clock line to flip-flop controlling shift clocks
// #10      0/0/1     QB (SCK, CLK) goes low
//                    (repeat 6-10 for each bit)
//
/////////////////////////////////////////////////////////////////////////
module dptif(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
    input  CLK_I;            // system clock
    input  WE_I;             // direction of this transfer. Read=0; Write=1
    input  TGA_I;            // ==1 if reg access, ==0 if poll
    input  STB_I;            // ==1 if this peri is being addressed
    input  [7:0] ADR_I;      // address of target register
    output STALL_O;          // ==1 if we need more clk cycles to complete
    output ACK_O;            // ==1 if we claim the above address
    input  [7:0] DAT_I;      // Data INto the peripheral;
    output [7:0] DAT_O;      // Data OUTput from the peripheral, = DAT_I if not us.
    input  [`MXCLK:0] clocks;// Array of clock pulses from 100ns to 1 second
    inout  [3:0] pins;       // FPGA I/O pins

    wire m10clk  =  clocks[`M10CLK];     // utility 10.00 millisecond pulse
    wire u1clk   =  clocks[`U1CLK];      // utility 1.000 microsecond pulse 
 
    wire   pin2 = pins[0];   // Pin2 to the tif card.  Clock control and data.
    wire   pin4 = pins[1];   // Pin4 to the tif card.  Clock control.
    wire   pin6 = pins[2];   // Pin6 to the tif card.  Clock control.
    wire   pin8 = pins[3];   // Serial data from the tif

    // State variables
    reg    [3:0] bst;        // Bit number for current card access
    reg    [3:0] gst;        // global state for xfer from card
    reg    sample;           // used to bring pin8 into our clock domain
    reg    [2:0] ledctrl;    // LED control for User1, User2, and backlight LEDs
    reg    [2:0] scanline;   // state counter to say which keypad column to scan
    wire   [3:0] scancol;    // decoded value (one-hot) of scanline
    reg    [4:0] scancode;   // Which key is pressed.  3 bits of row, 2 bits of column
    reg    dataready;        // new key press or rotary info available
    reg    datatohost;       // send data to host if 10ms edge and data ready
    wire   sendbit;          // bit to send out to the 74595 shift registers
    reg    doscan;           // set to start a keypad scan
    reg    [4:0] duration;   // duration in units of about 80 ms
    reg    [1:0] tone;       // frequency of output tone
    reg    volumn;           // set for higher volumn
    reg    [3:0] freqdiv;    // frequency divider for tone generation
    reg    piezo;            // data to put on the piezo pins
    reg    button;           // The last state of the rotary encoder button
    reg    oldA;             // Last value for the rotary encoder A input
    reg    oldB;             // Last value for the rotary encoder B input
    reg    newA;             // Current value of the A input
    reg    [3:0] quad;       // quadrature count
    reg    contrast;         // One bit for contrast control

    // Character FIFO registers for the text LCD
    wire   [8:0] dout;       // FIFO output lines
    wire   [3:0] faddr;      // FIFO address lines
    wire   fsclk;            // FIFO shift clock
    reg    [3:0] chartmp;    // nibble latch to capture low byte
    tiffifo fifo(dout,faddr,fsclk,{DAT_I[4:0],chartmp[3:0]});
    reg    [3:0] depth;      // Depth of FIFO usage.  
    reg    [1:0] xferst;     // FIFO to display transfer state

    // Addressing and bus interface lines 
    wire   myaddr;           // ==1 if a correct read/write on our address


    initial
    begin
        gst = 0;
        bst = 0;
        scanline = 0;
        scancode = 0;
        dataready = 0;
        doscan = 0;
        duration = 0;
        tone = 0;
        volumn = 0;
        depth = 0;
        xferst = 0;
        button = 1;
        oldA = 0;
        oldB = 0;
        quad = 0;
        contrast = 0;
    end

    always @(posedge CLK_I)
    begin
        sample <= pin8;

        // reading reg 1 clears the dataready flag
        if (TGA_I && ~WE_I && myaddr && (ADR_I[2:0] == 1))
        begin
            dataready <= 0;
            datatohost <= 0;
            quad <= 0;       // Zero the quadrature count after reading it.
        end

        // Address x010 is for the piezo
        else if (TGA_I && WE_I && myaddr && (ADR_I[2:0] == 2)) // addr=010
        begin
            duration <= DAT_I[4:0];
            tone     <= DAT_I[6:5];
            volumn   <= DAT_I[7];
            freqdiv  <= 0;
        end

        // Address x011 is for the LED control
        else if (TGA_I && WE_I && myaddr && (ADR_I[2:0] == 3)) // addr=011
        begin
            ledctrl  <= DAT_I[2:0];
            contrast <= DAT_I[4];
        end

        // Add char to the FIFO queue if queue is not full
        else if (TGA_I && myaddr && WE_I && (ADR_I[2:0] == 4))
        begin
            // The low nibble of the character has the MSB set.  We
            // latch the low nibble then get the high nibble and R/S
            // flag when the MSB is cleared.  This doubles the amount
            // of data on the USB bus but we're kind of stuck with 
            // that since we need 9 bits per character.
            chartmp <= DAT_I[3:0];

            // FIFO shift clock is TGA_Id now if not full (on MSB == 0)
            if ((depth != 15) && (DAT_I[7] == 1))
            begin
                depth <= depth + 4'h1;
                doscan <= 0;
            end
        end

        // else if host is not rd/wr our regs 
        // Is it time for a keypad scan?
        if (m10clk == 1)
        begin
            if (depth == 0)
                doscan <= 1;
            // Tell system to send keypad/quadrature if data is ready
            if (dataready)
                datatohost <= 1;
            // decrement the tone duration if playing a tone
            if (duration != 0)
                duration <= duration - 5'h01;
        end

        if ((m10clk == 1) || (u1clk == 1))
        begin

            // Run state machine for shifting data to/from the 595/165
            // if there are LCD chars to send or if in a keypad scan
            if ((depth != 0) || (doscan == 1) || (duration != 0))
            begin
                if (gst <= 9)
                begin
                    gst <= gst + 4'h1;

                    if ((gst == 6) & (bst[3] == 0))  // valid 165 data, first byte of bst
                    begin
                        // At this point 'sample' has the input value of
                        // 74165-input == 'bst' (7 to 0).  Do input processing here

                        // KEYPAD
                        // Keypad scan bit if bst 4-0.  Check for a press
                        // by looking for a sample value of zero.  And/Or
                        // look for a released key by watching for a sample
                        // of one at the previous pressed scancode.  Note
                        // columns are the output lines and rows are the input.
                        // Ignore the first two scanline values since we are
                        // sort of priming the pump to get the real values.
                        // Sample is zero on a key press.
                        if ((bst[2:0] <= 4) && (doscan == 1) && (scanline >= 2))
                        begin
                            // if no key pressed and now sample = 0, then new key
                            // keypress on column==scanline and row==bst.
                            // Scancode == 0 if no key pressed
                            if ((scancode == 5'h00) && (sample == 0))
                            begin
                                scancode <= { (scanline[1:0] - 2'h2), ~(bst[2:0]) } ;
                                dataready <= 1;                // send to host
                            end
                            else if ((scancode == { (scanline[1:0] - 2'h2), ~(bst[2:0]) }) && (sample == 1))
                            begin  // on row/col of previous close but now it's open
                                scancode <= 5'h00;
                                dataready <= 1;                // send to host
                            end
                        end

                        // ROTARY ENCODER
                        // If bit_state (bst) is >= 5 then the sample line
                        // has the state of the rotary encoder A/B or button
                        // Do button press/release detection and quadrature
                        // decoding here.
                        // The quadrature decoder needs both A and B inputs so
                        // just capture A
                        if (bst[2:0] == 5)
                        begin
                            newA <= sample;
                        end
                        else if (bst[2:0] == 6)
                        begin
                            // Sample is newB and we have newA, oldB, and oldA so we can
                            // do the quadrature decoding.
                            if (((oldA != newA) && (oldA ^ oldB)) ||
                                ((oldB != sample) && (~(oldA ^ oldB))))
                            begin
                                quad <= quad + 4'h1;
                                oldA <= newA;
                                oldB <= sample;
                                dataready <= 1;
                            end
                            else if (((oldA != newA) && (~(oldA ^ oldB))) ||
                                ((oldB != sample) && (oldA ^ oldB)))
                            begin
                                quad <= quad - 4'h1;
                                oldA <= newA;
                                oldB <= sample;
                                dataready <= 1;
                            end
                        end
                        else if ((bst[2:0] == 7) && (dataready == 0) && (button != sample))
                        begin
                            // There is a new state for the rotary encoder button.
                            button <= sample;
                            dataready <= 1;
                        end
                    end
                end
                else
                begin
                    bst <= bst + 4'h1;  // next bit
                    gst <= (bst == 15) ? 4'h0 : 4'h6;
                    if (bst == 15) 
                    begin
                        // At this point we're done sending the last bit
                        // out the shift register and are ready to start
                        // a new sequence of 16 output bits.  Now is the
                        // time to process our various state machines to
                        // see if the output pattern needs to change.
   
                        // Increment to next column if in a keypad scan 
                        if (doscan == 1)
                        begin
                            // 6 states since it takes two states to set
                            // the output and then read the input.
                            scanline <= scanline + 3'h1;
                            if (scanline == 5)        // done with this scan?
                                doscan <= 0;
                        end

                        // If there is data in the FIFO we need to send it out.
                        // There is a state machine that controls this transfer.
                        // In the first state the address lines change.  In the
                        // second state the data becomes valid.  In the third
                        // state we raise the E line, in the fourth we lower
                        // the E line and decrement the FIFO depth.
                        // (no need to worry about the FIFO address -- it is
                        // tied to FIFO depth)
                        if (depth != 0)
                        begin
                            xferst <= xferst + 2'h1;
                            if (xferst == 3)
                            begin
                                depth <= depth - 4'h1;
                            end
                        end

                        // TONE GENERATION
                        if (duration != 0)
                        begin
                            freqdiv <= freqdiv - 4'h1;
                            if (freqdiv == 0)
                            begin
                                piezo <= ~piezo;
                                freqdiv[3:2] <= tone;
                            end
                        end
                    end
                end
            end
        end
    end

    // Select the keypad column to scan (active low)
    assign scancol = 
        (scanline[1:0] == 1) ? 4'b1110 :
        (scanline[1:0] == 0) ? 4'b1101 :
        (scanline[1:0] == 3) ? 4'b1011 :
        (scanline[1:0] == 2) ? 4'b0111 :
                               4'b1111 ;

    // Map the output of the various sub-peripherals to
    // output pins on the two 74595s.
    assign sendbit = 
        (bst ==  0) ? dout[5] :          // Data 5 (pin 12) on the display
        (bst ==  1) ? ((depth == 0) ? scancol[1] : dout[2] ) :  // keypad column 1
        (bst ==  2) ? ((depth == 0) ? scancol[0] : dout[3] ) :  // keypad column 0
        (bst ==  3) ? ((depth == 0) ? scancol[3] : dout[1] ) :  // keypad column 3
        (bst ==  4) ? ((depth == 0) ? scancol[2] : dout[0] ) :  // keypad column 2
        (bst ==  5) ? ((xferst == 3'h2) ? 1'b0 : 1'b1) : // E on the display
        (bst ==  6) ? dout[8] :         // RS on the display
        (bst ==  7) ? contrast :
        (bst ==  8) ? ~ledctrl[2] :     // User LED2
        (bst ==  9) ? ~ledctrl[1] :     // User LED1
        (bst == 10) ? ((duration != 0) ? piezo : 1'b0) :           // piezo output
        (bst == 11) ? (((duration != 0) && (volumn == 1)) ? ~piezo : 1'b0) :// high volume
        (bst == 12) ? ~ledctrl[0] :     // LED backlight on the display
        (bst == 13) ? dout[6] :         // Data 6 (pin 13) on the display
        (bst == 14) ? dout[7] :         // Data 7 (pin 14) on the display
                      dout[4] ;         // Data 4 (pin 11) on the display


    // Route FIFO lines
    assign fsclk = (~CLK_I & TGA_I & myaddr & WE_I & (ADR_I[2:0] == 4)
                   & (DAT_I[7] == 1) & (depth != 15));
    // Zero indexed addresses.  Look at output of cell addr=0 when the depth is 1.
    assign faddr = depth - 4'h1;

    // Assign the outputs.
    assign pin2 = ((gst == 4) || (gst == 5) || (gst == 10) ||     // set RCK on 74165
                   (((gst == 6) || (gst == 7) || (gst == 8)) && sendbit));
    assign pin4 = (gst == 8);
    assign pin6 = ((gst == 2) || (gst == 5) || (gst == 6) || (gst == 7)
                || (gst == 8) || (gst == 9));

    assign myaddr = (STB_I) && (ADR_I[7:3] == 0);
    assign DAT_O = (~myaddr) ? DAT_I :
                    (~TGA_I && myaddr && (datatohost)) ? 8'h02 :  // send up 2 bytes when ready
                    (TGA_I && (ADR_I[2:0] == 0)) ?  { ~button, 2'b00, scancode } :
                    (TGA_I && (ADR_I[2:0] == 1)) ?  {  2'h0, quad } :
                    (TGA_I && (ADR_I[2:0] == 2)) ?  { volumn, tone, duration } :
                    (TGA_I && (ADR_I[2:0] == 3)) ?  { 5'b0000, ledctrl } :
                    8'h00 ; 

    // Loop in-to-out where appropriate
    assign STALL_O = 0;

    // We tell the host the FIFO is full by refusing to accept
    // characters, which we do my refusing to recognize our own address
    assign ACK_O = (myaddr && (ADR_I[2:0] != 4)) |
                   (myaddr && (ADR_I[2:0] == 4) && (depth != 15));

endmodule


   // FIFO implemented with distributed RAM
module tiffifo (dataout,addr,shiftclk,shiftin);
    parameter WIDTH = 9;
    parameter LOGDEPTH = 4;
    output [WIDTH-1:0] dataout;
    input  [LOGDEPTH-1:0] addr;
    input  shiftclk;
    input  [WIDTH-1:0] shiftin;

    reg    [WIDTH-1:0] shftram [(LOGDEPTH**2)-1:0];
    integer i;

    always @(posedge shiftclk)
    begin
        for (i = ((LOGDEPTH**2)-1); i > 0; i = i-1)
            shftram[i] <= shftram[i-1];
        shftram[0] <= shiftin;
    end

    assign dataout = shftram[addr];
endmodule



