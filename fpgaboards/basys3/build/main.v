//////////////////////////////////////////////////////
//
//  File: protomain.v;
//  Description: This is the top module of the Peripheral
//     control program, PCcore.
// 
/////////////////////////////////////////////////////

// *********************************************************
// Copyright (c) 2020 Demand Peripherals, Inc.
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
// *********************************************************


module pccore(BRDIO, PCPIN);
    inout  [`BRD_MX_IO:0]  BRDIO;     // Board IO 
    inout  [`MX_PCPIN:0]   PCPIN;     // Peripheral Controller Pins (for Pmods)


//////////////////////////////////////////////////////////////////////////
//
//  Instantiate the modules/hardware for this design

    // Define the wires to/from the bus controller #0
    wire CLK_O;                  // the global system clock
    wire [`MXCLK:0] bc0clocks;   // utility clock pulse from 10ns to 1 second

    // Define the wires to the host serial interface
    wire hi0m10clk;              // pulse every 10 ms
    wire [7:0] hi0ohihfdata;     // data byte into the FPGA bus interface
    wire hi0ohihfrxf_;           // data ready strobe to the FPGA bus interface
    wire hi0ihifhrd_;            // the bus interface acknowledges the new byte
    wire hi0ishfhwr;             // pulse to write data to txd output buffer
    wire hi0buffull;             // ==1 if output FIFO can not take more characters
    wire [7:0] hi0ihifhdata;     // Data into the txd FIFO

    // Define wires for the physical host serial interface
    wire hi0tx;                  // serial data to the host
    wire hi0rx;                  // serial data from the host
    wire hi0tx_led;              // Tx activity LED
    wire hi0rx_led;              // Rx activity LED
    wire hi0err_led;             // output buffer overflow

    // Define the wires to SLIP encoder #0
    wire [7:0] sl0islhfdata;     // Data in from the host serial interface
    wire sl0islhfrxf_;           // Receiver full (not) at hshf port  (ready_)
    wire sl0oslhfrd_;            // Read the new data, latch on rising edge (ack_)
    wire [7:0] sl0oslhfdata;     // Data out to the bus interface
    wire sl0oslhfrxf_;           // Receiver full (not) at bihf port
    wire sl0islhfrd_;            // Read the new data, latched on rising edge
    wire sl0oslhfpkt;            // ==1 if in a packet.  Rising edge == new pkt
    wire [7:0] sl0oslfhdata;     // Data out to the host serial interface
    wire sl0islfhtxe_;           // Transmitter empty (not) at hsfh port
    wire sl0oslfhwr;             // Write the new data, latch on clk rising edge
    wire [7:0] sl0islfhdata;     // Data in from the bus interface
    wire sl0oslfhtxe_;           // Transmitter empty (not) at bifh port
    wire sl0islfhwr;             // Take the new data, latched on clk rising edge
    wire sl0islfhpkt;            // ==1 if in a packet.  Rising edge == new pkt

    // Define the wire to the CRC encoder/decoder
    wire [7:0] cr0icrhfdata;     // Data in from SLIP decoder
    wire cr0icrhfrxf_;           // Receiver full (not) at crhf port.  Data valid
    wire cr0ocrhfrd_;            // Read the new data, latch on clk rising edge
    wire cr0icrhfpkt;            // Slip has a packet for us
    wire [7:0] cr0ocrhfdata;     // Data out to the bus interface
    wire cr0ocrhfrxf_;           // Receiver full (not) at bihf port
    wire cr0icrhfrd_;            // Read the new data, latched on clk rising edge
    wire cr0ocrhfpkt;            // ==1 if in a packet.  Rising edge == new pkt
    wire [7:0] cr0ocrfhdata;     // Data out to the SLIP encoder
    wire cr0icrfhtxe_;           // Transmitter empty (not) 
    wire cr0ocrfhwr;             // Write the new data, latch on clk rising edge
    wire cr0ocrfhpkt;            // We have a packet for SLIP
    wire [7:0] cr0icrfhdata;     // Data in from the bus interface
    wire cr0ocrfhtxe_;           // Transmitter empty (not)
    wire cr0icrfhwr;             // Take the new data, latched on clk rising edge
    wire cr0icrfhpkt;            // ==1 if in a packet.  Rising edge == new pkt

    // Lines to and from the bus interface
    wire [7:0] bi0ibihfdata;     // Data from the physical interface
    wire bi0ibihfrxf_;           // Data available if low
    wire bi0obihfrd_;            // Get data from bus when low
    wire bi0ibihfpkt;            // High if we're receiving a packet
    wire [7:0] bi0obifhdata;     // Data toward the physical interface
    wire bi0ibifhtxe_;           // Able to send new data if low
    wire bi0obifhwr;             // Write data on positive edge
    wire bi0obofhpkt;            // High when we want to send a packet
    wire bi0ibifhen_;            // CRC is busy when high.  Do not poll peri's when high
    wire [11:0] bi0addr;         // address of target peripheral/register
    wire [7:0] bi0datout;        // Data OUT to the peripherals
    wire WE_O;                   // direction of this transfer. Read=0; Write=1
    wire TGA_O;                  // ==1 if reg access, ==0 if poll
    wire STALL_I;                // ==1 if target peripheral needs more clock cycles
    wire bi0u100clk;             // ==1 to mark start of a poll cycle
    wire ACK_I;                  // ==1 if target peripheral claims the address
    wire [7:0] bi0datin;         // Data INto the bus interface;

    wire [7:0] ADR_O;            // register addressed within a peripheral

//////////////////////////////////////////////////////////////////////////
//
//  Instantiate the modules/hardware for this design

    // Serial host interface
    hostinterface hi0(CLK_O, hi0m10clk, BRDIO,
            hi0ohihfdata, hi0ohihfrxf_,hi0ihifhrd_,hi0ishfhwr,hi0buffull,hi0ihifhdata);
    //hostinterface hi0(CLK_O, hi0m10clk, hi0tx,hi0rx, hi0tx_led, hi0rx_led, 
            //hi0ohihfdata, hi0ohihfrxf_,hi0ihifhrd_,hi0ishfhwr,hi0buffull,hi0ihifhdata);
    assign hi0m10clk = bc0clocks[`M10CLK];   // 10 ms clock
    assign hi0ihifhrd_ = sl0oslhfrd_;
    assign hi0ihifhdata = sl0oslfhdata;
    assign hi0ishfhwr = sl0oslfhwr;

    // SLIP encoder/decoder sits between the host interface and the bus interface
    slip sl0(CLK_O, sl0islhfdata, sl0islhfrxf_, sl0oslhfrd_, sl0oslhfdata, sl0oslhfrxf_,
            sl0islhfrd_, sl0oslhfpkt, sl0oslfhdata, sl0islfhtxe_, sl0oslfhwr, sl0islfhdata,
            sl0oslfhtxe_, sl0islfhwr, sl0islfhpkt);
    assign sl0islhfdata = hi0ohihfdata;
    assign sl0islhfrxf_ = hi0ohihfrxf_;
    assign sl0islfhtxe_ = hi0buffull;
    assign sl0islfhdata = cr0ocrfhdata;
    assign sl0islfhwr   = cr0ocrfhwr;
    assign sl0islfhpkt  = cr0ocrfhpkt;
    assign sl0islhfrd_  = cr0ocrhfrd_;

    // Lines to the CRC generator/checker
    crc cr0(CLK_O, cr0icrhfdata, cr0icrhfrxf_, cr0ocrhfrd_, cr0icrhfpkt, cr0ocrhfdata,
            cr0ocrhfrxf_, cr0icrhfrd_, cr0ocrhfpkt, cr0ocrfhdata, cr0icrfhtxe_, cr0ocrfhwr,
            cr0ocrfhpkt, cr0icrfhdata, cr0ocrfhtxe_, cr0icrfhwr, cr0icrfhpkt);
    assign cr0icrhfdata = sl0oslhfdata;
    assign cr0icrhfrxf_ = sl0oslhfrxf_;
    assign cr0icrhfrd_  = bi0obihfrd_;
    assign cr0icrhfpkt  = sl0oslhfpkt;
    assign cr0icrfhtxe_ = sl0oslfhtxe_;
    assign cr0icrfhdata = bi0obifhdata;
    assign cr0icrfhwr   = bi0obifhwr;
    assign cr0icrfhpkt  = bi0obifhpkt;

    // Lines to and from bus interface #0
    busif bi0(CLK_O, bi0ibihfdata, bi0ibihfrxf_, bi0obihfrd_, bi0ibihfpkt,
            bi0obifhdata, bi0ibifhtxe_, bi0obifhwr, bi0obifhpkt, bi0ibifhen_, bi0addr,
            bi0datout, WE_O, TGA_O, STALL_I, bi0u100clk, ACK_I,
            bi0datin);
    assign bi0ibihfdata = cr0ocrhfdata;
    assign bi0ibihfrxf_ = cr0ocrhfrxf_;
    assign bi0ibihfpkt  = cr0ocrhfpkt;
    assign bi0ibifhtxe_ = cr0ocrfhtxe_;
    assign bi0ibifhen_   = cr0ocrfhpkt;
    assign bi0u100clk = bc0clocks[`U100CLK];
    assign ADR_O = bi0addr[7:0];


// Slot: 0   basys3
    wire p00STB_O;        // ==1 if this peri is being addressed
    wire p00STALL_O;      // ==1 if we need more clk cycles
    wire p00ACK_O;        // ==1 for peri to acknowledge transfer
    wire [7:0] p00DAT_I;  // Data INto the peripheral;
    wire [7:0] p00DAT_O;  // Data OUTput from the peripheral, = DAT_I if not us.
    basys3 p00(CLK_O,WE_O,TGA_O,p00STB_O,ADR_O[7:0],p00STALL_O,p00ACK_O,p00DAT_I,p00DAT_O,bc0clocks,BRDIO,PCPIN);
    assign p00STB_O = (bi0addr[11:8] == 0) ? 1'b1 : 1'b0;

// Slot: 1   dpadc12
    wire p01STB_O;        // ==1 if this peri is being addressed
    wire p01STALL_O;      // ==1 if we need more clk cycles
    wire p01ACK_O;        // ==1 for peri to acknowledge transfer
    wire [7:0] p01DAT_I;  // Data INto the peripheral;
    wire [7:0] p01DAT_O;  // Data OUTput from the peripheral, = DAT_I if not us.
    tri [3:0] p01pins;
    dpadc12 p01(CLK_O,WE_O,TGA_O,p01STB_O,ADR_O[7:0],p01STALL_O,p01ACK_O,p01DAT_I,p01DAT_O,bc0clocks,p01pins);
    assign PCPIN[0] = p01pins[0];
    assign PCPIN[1] = p01pins[1];
    assign PCPIN[2] = p01pins[2];
    assign p01pins[3] = PCPIN[ 3];
    assign p01STB_O = (bi0addr[11:8] == 1) ? 1'b1 : 1'b0;

// Slot: 2   dpei2c
    wire p02STB_O;        // ==1 if this peri is being addressed
    wire p02STALL_O;      // ==1 if we need more clk cycles
    wire p02ACK_O;        // ==1 for peri to acknowledge transfer
    wire [7:0] p02DAT_I;  // Data INto the peripheral;
    wire [7:0] p02DAT_O;  // Data OUTput from the peripheral, = DAT_I if not us.
    tri [3:0] p02pins;
    dpei2c p02(CLK_O,WE_O,TGA_O,p02STB_O,ADR_O[7:0],p02STALL_O,p02ACK_O,p02DAT_I,p02DAT_O,bc0clocks,p02pins);
    assign PCPIN[4] = p02pins[0];
    assign PCPIN[5] = p02pins[1];
    assign PCPIN[6] = p02pins[2];
    assign p02pins[3] = PCPIN[ 7];
    assign p02STB_O = (bi0addr[11:8] == 2) ? 1'b1 : 1'b0;

// Slot: 3   dpespi
    wire p03STB_O;        // ==1 if this peri is being addressed
    wire p03STALL_O;      // ==1 if we need more clk cycles
    wire p03ACK_O;        // ==1 for peri to acknowledge transfer
    wire [7:0] p03DAT_I;  // Data INto the peripheral;
    wire [7:0] p03DAT_O;  // Data OUTput from the peripheral, = DAT_I if not us.
    tri [3:0] p03pins;
    dpespi p03(CLK_O,WE_O,TGA_O,p03STB_O,ADR_O[7:0],p03STALL_O,p03ACK_O,p03DAT_I,p03DAT_O,bc0clocks,p03pins);
    assign PCPIN[8] = p03pins[0];
    assign PCPIN[9] = p03pins[1];
    assign PCPIN[10] = p03pins[2];
    assign p03pins[3] = PCPIN[11];
    assign p03STB_O = (bi0addr[11:8] == 3) ? 1'b1 : 1'b0;

// Slot: 4   dpin32
    wire p04STB_O;        // ==1 if this peri is being addressed
    wire p04STALL_O;      // ==1 if we need more clk cycles
    wire p04ACK_O;        // ==1 for peri to acknowledge transfer
    wire [7:0] p04DAT_I;  // Data INto the peripheral;
    wire [7:0] p04DAT_O;  // Data OUTput from the peripheral, = DAT_I if not us.
    tri [3:0] p04pins;
    dpin32 p04(CLK_O,WE_O,TGA_O,p04STB_O,ADR_O[7:0],p04STALL_O,p04ACK_O,p04DAT_I,p04DAT_O,bc0clocks,p04pins);
    assign PCPIN[12] = p04pins[0];
    assign PCPIN[13] = p04pins[1];
    assign PCPIN[14] = p04pins[2];
    assign p04pins[3] = PCPIN[15];
    assign p04STB_O = (bi0addr[11:8] == 4) ? 1'b1 : 1'b0;

// Slot: 5   dpout32
    wire p05STB_O;        // ==1 if this peri is being addressed
    wire p05STALL_O;      // ==1 if we need more clk cycles
    wire p05ACK_O;        // ==1 for peri to acknowledge transfer
    wire [7:0] p05DAT_I;  // Data INto the peripheral;
    wire [7:0] p05DAT_O;  // Data OUTput from the peripheral, = DAT_I if not us.
    tri [3:0] p05pins;
    dpout32 p05(CLK_O,WE_O,TGA_O,p05STB_O,ADR_O[7:0],p05STALL_O,p05ACK_O,p05DAT_I,p05DAT_O,bc0clocks,p05pins);
    assign PCPIN[16] = p05pins[0];
    assign PCPIN[17] = p05pins[1];
    assign PCPIN[18] = p05pins[2];
    assign PCPIN[19] = p05pins[3];
    assign p05STB_O = (bi0addr[11:8] == 5) ? 1'b1 : 1'b0;

// Slot: 6   dproten
    wire p06STB_O;        // ==1 if this peri is being addressed
    wire p06STALL_O;      // ==1 if we need more clk cycles
    wire p06ACK_O;        // ==1 for peri to acknowledge transfer
    wire [7:0] p06DAT_I;  // Data INto the peripheral;
    wire [7:0] p06DAT_O;  // Data OUTput from the peripheral, = DAT_I if not us.
    tri [3:0] p06pins;
    dproten p06(CLK_O,WE_O,TGA_O,p06STB_O,ADR_O[7:0],p06STALL_O,p06ACK_O,p06DAT_I,p06DAT_O,bc0clocks,p06pins);
    assign p06pins[0] = PCPIN[20];
    assign p06pins[1] = PCPIN[21];
    assign p06pins[2] = PCPIN[22];
    assign PCPIN[23] = p06pins[3];
    assign p06STB_O = (bi0addr[11:8] == 6) ? 1'b1 : 1'b0;

// Slot: 7   dpio8
    wire p07STB_O;        // ==1 if this peri is being addressed
    wire p07STALL_O;      // ==1 if we need more clk cycles
    wire p07ACK_O;        // ==1 for peri to acknowledge transfer
    wire [7:0] p07DAT_I;  // Data INto the peripheral;
    wire [7:0] p07DAT_O;  // Data OUTput from the peripheral, = DAT_I if not us.
    tri [3:0] p07pins;
    dpio8 p07(CLK_O,WE_O,TGA_O,p07STB_O,ADR_O[7:0],p07STALL_O,p07ACK_O,p07DAT_I,p07DAT_O,bc0clocks,p07pins);
    assign PCPIN[24] = p07pins[0];
    assign PCPIN[25] = p07pins[1];
    assign PCPIN[26] = p07pins[2];
    assign p07pins[3] = PCPIN[27];
    assign p07STB_O = (bi0addr[11:8] == 7) ? 1'b1 : 1'b0;

// Slot: 8   dptif
    wire p08STB_O;        // ==1 if this peri is being addressed
    wire p08STALL_O;      // ==1 if we need more clk cycles
    wire p08ACK_O;        // ==1 for peri to acknowledge transfer
    wire [7:0] p08DAT_I;  // Data INto the peripheral;
    wire [7:0] p08DAT_O;  // Data OUTput from the peripheral, = DAT_I if not us.
    tri [3:0] p08pins;
    dptif p08(CLK_O,WE_O,TGA_O,p08STB_O,ADR_O[7:0],p08STALL_O,p08ACK_O,p08DAT_I,p08DAT_O,bc0clocks,p08pins);
    assign PCPIN[28] = p08pins[0];
    assign PCPIN[29] = p08pins[1];
    assign PCPIN[30] = p08pins[2];
    assign p08pins[3] = PCPIN[31];
    assign p08STB_O = (bi0addr[11:8] == 8) ? 1'b1 : 1'b0;

assign bi0datin = p00DAT_O;

assign p00DAT_I = p01DAT_O;
assign p01DAT_I = p02DAT_O;
assign p02DAT_I = p03DAT_O;
assign p03DAT_I = p04DAT_O;
assign p04DAT_I = p05DAT_O;
assign p05DAT_I = p06DAT_O;
assign p06DAT_I = p07DAT_O;
assign p07DAT_I = p08DAT_O;
assign p08DAT_I = bi0datout;

assign STALL_I = 
              p00STALL_O |
              p01STALL_O |
              p02STALL_O |
              p03STALL_O |
              p04STALL_O |
              p05STALL_O |
              p06STALL_O |
              p07STALL_O |
              p08STALL_O;

assign ACK_I = 
              p00ACK_O |
              p01ACK_O |
              p02ACK_O |
              p03ACK_O |
              p04ACK_O |
              p05ACK_O |
              p06ACK_O |
              p07ACK_O |
              p08ACK_O;

endmodule


module perilist(core, id);
    input  [3:0] core;
    output [15:0] id;
    assign id = 
            (core == 4'h0) ? 16'h002f : 
            (core == 4'h1) ? 16'h0024 : 
            (core == 4'h2) ? 16'h001b : 
            (core == 4'h3) ? 16'h001a : 
            (core == 4'h4) ? 16'h001d : 
            (core == 4'h5) ? 16'h0029 : 
            (core == 4'h6) ? 16'h0008 : 
            (core == 4'h7) ? 16'h001e : 
            (core == 4'h8) ? 16'h0026 : 
            (core == 4'h9) ? 16'h0000 : 
            (core == 4'ha) ? 16'h0000 : 
            (core == 4'hb) ? 16'h0000 : 
            (core == 4'hc) ? 16'h0000 : 
            (core == 4'hd) ? 16'h0000 : 
            (core == 4'he) ? 16'h0000 : 
                             16'h0000 ; 
endmodule

