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
//  File: dpus8.v;   Octal interface to an SRF-04 ultrasonic sensor
//
//  Registers: 8 bit, read-only
//      Reg 0:  read-only, low byte of 12 bit timer
//      Reg 1:  read-only, sensor ID and upper 4 bits of timer
//      Reg 2:  enable register
//
//
//  HOW THIS WORKS
//      The us8 peripheral uses an io8 card to connect to up
//  to eight SRF-04 ultrasonic sensors.  The sensors have one
//  input pin and one output pin.  A 10 us pulse on the input
//  starts a ping.  The echo time of the ping is given as a 
//  pulse width on the output pin.  The echo response starts
//  about 100 us after the end of the start pulse.  We measure
//  the pulse width of the echo reply and do an auto-send of
//  that time up to the host.  To avoid multiple echoes we
//  ping only one sensor at a time and we do the pings at 60
//  millisecond intervals.
//      The 'snst' variable keeps track of the state machine for
//  reading the sensors.  The algorithm looks something like this:
//           EVERY 60 milliseconds
//               Set io8 output high for the sensor's pin
//               Wait 10 us, then set output pin low
//               Wait for the response line to go high
//                   (for up to 40ms)
//               Wait for the response line to go low
//                   (for up to 40ms).  Auto-send this period
//               Increment sensor ID to next enabled sensor
//           }
//
//  SNST    State
//     0    Wait for start of 60 ms
//              then clear timer, go to state 1
//     1    Wait 10 microseconds while sending start pulse 
//              then clear timer and go to state 2
//     2    Wait for input line to go low or 40 ms
//              (report ping time of 0 if a timeout)
//     3    Wait for input line to go high.  (up to 40 ms)
//              then report this time to host
//     4    Wait for mscntr to not be zero and for dataready to be zero
//              then increment snid, go to state 5
//     5    Ready to start next reading.  Find the next enabled sensor.
//              then go to snst==0
//
//
//
//
//      The io8 card has one 74LVC595 serial-to-parallel chip
//  and a 165 parallel-to-serial shift register.
//  A 7474 dual D flip-flop is used to synchronize the parallel
//  load and bit shifts.  The Verilog below uses 'snid' for the
//  sensor ID, 'bst' to count the 8 bits while shifting the data
//  in and out, and 'gst' as the state machine controller for the
//  7474 (and hence the loading and shifting).
//      
//  The cabling from the Baseboard to the us8 has ringing on
//  all of the lines at any transition.  To overcome this we
//  use a 7474.  Ringing on the reset or clk line of a 7474 has
//  no effect on the output if the D input is held constant
//  during the ringing.  The data line (pin2) must not change
//  on either rising or falling edge pin4 and the rising edge
//  of pin6.   This is the goal of the gst state machine.
//  
// GST  Pin 6/4/2       State
// #0       0/0/1     Start state
// #1       0/0/0     Set up data value for the RCK/LD- TGA_Is
// #2       1/0/0     Rising edge sets RCK high and LD- low
// #3       0/0/0     Lower clock line that controls RCK/LD flip-flop
// #4       0/0/1     Data is latched.  Now start shifting the bits
// #5       1/0/1     Rising egde of pin4 sets RCK low and LD- high
//                    (repeat 6-9 for each bit)
// #6       1/0/d     Setup the data out value ('d') for this bit
// #7       1/1/d     Shift clock goes high, shifting in 'd'.
// #8       1/0/1     Lower clock line to flip-flop controlling shift clocks
// #9       0/0/1     QB (SCK, CLK) goes low
//                    (repeat 6-10 for each bit)
//
/////////////////////////////////////////////////////////////////////////
module dpus8(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
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

    wire m10clk  =  clocks[`M10CLK];     // utility 10.00 millisecond pulse
    wire u10clk  =  clocks[`U10CLK];     // utility 10.00 microsecond pulse
    wire n100clk =  clocks[`N100CLK];    // utility 100.0 nanosecond pulse

    wire   pin2 = pins[0];   // Pin2 to the us8 card.  Clock control and data.
    wire   pin4 = pins[1];   // Pin4 to the us8 card.  Clock control.
    wire   pin6 = pins[2];   // Pin6 to the us8 card.  Clock control.
    wire   pin8 = pins[3];   // Serial data from the us8

    // State variables
    reg    [2:0] snst;       // State variable for outer loop of sensors
    reg    [2:0] snid;       // Sensor ID for current pulse.
    reg    [2:0] bst;        // Bit number for shifting bits in/out to card
    reg    [3:0] gst;        // global state for xfer from card
    reg    dataready;        // set=1 to wait for an autosend to host
    reg    sample;           // used to bring pin8 into our clock domain
    reg    [2:0] mscntr;     // Counter for 10 ms pulses
    reg    [11:0] timr;      // timer/counter for 12.8 us and echo times
    reg    gotecho;          // ==1 when and echo is found
    reg    [7:0] enbl;      // Bit is set for enabled sensors


    initial
    begin
        snst = 0;
        snid = 0;
        mscntr = 0;
        gst = 0;
        bst = 0;
        dataready = 0;
        timr = 0;
        enbl = 0;
    end

    always @(posedge CLK_I)
    begin
        sample <= pin8;

        // read of high byte clears the dataready flag
        if (TGA_I && ~WE_I && myaddr && (ADR_I[1:0] == 1))
        begin
            dataready <= 0;
        end
        else if (TGA_I && myaddr && WE_I && (ADR_I[1:0] == 2))  // latch data on a write
        begin
            enbl[7:0] <= DAT_I[7:0];
        end

        // else if host is not reading our regs
        else
        begin
            // Decrement the global 60 ms timer
            if (m10clk == 1)
                mscntr <= (mscntr == 0) ? 3'h5 : (mscntr - 3'h1);

            if (u10clk == 1)
            begin
                //  SNST==0, wait for 60 ms edge
                if (snst == 0)
                begin
                     if (mscntr == 0)
                     begin
                        // clear timer, go to snst state 1
                        timr <= 0;
                        snst <= 1;
                    end
                end 
                //  SNST==1,    Wait for 10 microseconds
                else if (snst == 1)
                begin
                    timr <= timr + 12'h001;
                    // at 100 KHz, timr bit 1 goes high at 10 us
                    if (timr[3])
                    begin
                        snst <= 2;         // go to SNST 2
                    end
                end
                //  SNST==2,    Wait for line from sensor to go high (or 40 ms)
                else if (snst == 2)
                begin
                    if (gotecho)
                    begin
                        timr <= 0;
                        snst <= 3;
                    end
                    else if (timr == 12'hfff)
                    begin
                        // No high pulse.  Missing sensor?
                        dataready <= 1;   // report a zero to host
                        timr <= 0;
                        snst <= 4;        // go find next snid
                    end
                    else
                        timr <= timr + 12'h001;
                end
                // SNST==3 wait for line to go low or for 40 ms
                else if (snst == 3)
                begin
                    if ((~gotecho) | (timr == 12'hfff))
                    begin
                        dataready <= 1;
                        snst <= 4;
                    end
                    else
                        timr <= timr + 12'h001;
                end
                // SNST==4    Wait for mscntr to not be zero and for dataready to be zero
                else if (snst == 4)
                begin
                    if ((mscntr != 0) && ~dataready)
                    begin
                        snid <= snid + 3'h1;
                        snst <= 5;
                    end
                end
                // SNST==5  Ready to start next reading.  Find the next enabled sensor.
                else if (snst == 5)   
                begin
                    if (enbl[snid] == 0)
                        snid <= snid + 3'h1;
                    else
                        snst <= 0;
                end
            end
        end
    end


    // This is the state machine for sending the start pulses
    // out to the io8 card and for looking for a returning echo
    // We only need to send/read data during the start pulse 
    // and during the echo search -- that is, during snst==1
    // and snst==2
    always @(posedge n100clk)
    begin
        // GST is the state variable controlling the bit shift to the io8 registers
        if ((gst == 0) && (snst == 0))
            // wait here for start pulse (snst==1)
            gotecho <= 0;
        else if (gst < 9)
        begin
            gst <= gst + 4'h1;
            if ((gst ==6) && (~bst[2] == snid[2]) && (~bst[1] == snid[1]) && (~bst[0] == snid[0]))
                if ((sample == 1) && (snst == 2))
                    gotecho <= 1;
                else if ((sample == 0) && (snst == 3))
                    gotecho <= 0;
        end
        else
        begin
            gst <= (bst == 7) ? 4'h0 : 4'h6;
            bst <= bst + 3'h1;
        end
    end


    // Assign the outputs.
    assign pin2 = (gst == 0) || (gst == 4) || (gst == 5) || (gst == 8) || (gst == 9) ||
                   (((gst == 6) || (gst == 7) || (gst == 8)) && (bst == snid) && (snst == 1));
    assign pin4 = (gst == 7);
    assign pin6 = (gst == 2) || (gst == 5) || (gst == 6) || (gst == 7) || (gst == 8);

    assign myaddr = (STB_I) && (ADR_I[7:2] == 0);
    assign DAT_O = (~myaddr) ? DAT_I :
                    (~TGA_I && (dataready)) ? 8'h03 :
                    (TGA_I && (ADR_I[1:0] == 0)) ? timr[7:0] : 
                    (TGA_I && (ADR_I[1:0] == 1)) ? {1'b0,snid,timr[11:8]} :
                    (TGA_I && (ADR_I[1:0] == 2)) ? enbl[7:0] :
                    8'h00 ; 

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule


