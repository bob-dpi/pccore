// *********************************************************
// Copyright (c) 2021 Demand Peripherals, Inc.
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

//////////////////////////////////////////////////////////////////////////
//
//  File: crc.v:   A CRC generator/checker
//  Description:  This modules validates packets from the SLIP interface
//       and generates CRC for data to the SLIP interface. This module
//       sits between the SLIP module and the bus interface.
//
/////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////
//
//  There are really two separate state machines in this module, one for
//  the CRC decoder and one for the CRC encoder.  


module crc(clk, icrhfdata, icrhfrxf_, ocrhfrd_, icrhfpkt, ocrhfdata, ocrhfrxf_,
            icrhfrd_, ocrhfpkt, ocrfhdata, icrfhtxe_, ocrfhwr, ocrfhpkt, icrfhdata,
            ocrfhtxe_, icrfhwr, icrfhpkt);
    input  clk;               // system clock
    // hosts serial side in the host-to-FPGA direction
    input  [7:0] icrhfdata;   // Data in from host serial
    input  icrhfrxf_;         // Receiver full (not) at crhf port.  Data valid
    output ocrhfrd_;          // Read the new data, latch on clk rising edge
    input  icrhfpkt;          // Slip has a packet for us
    // Bus Interface side in the host-to-FPGA direction
    output [7:0] ocrhfdata;   // Data out to the bus interface
    output ocrhfrxf_;         // Receiver full (not) at bihf port
    input  icrhfrd_;          // Read the new data, latched on clk rising edge
    output ocrhfpkt;          // ==1 if in a packet.  Rising edge == new pkt
    // host serial side in the FPGA-to-host direction
    output [7:0] ocrfhdata;   // Data out to the host serial
    input  icrfhtxe_;         // Transmitter empty (not) at slfh port
    output ocrfhwr;           // Write the new data, latch on clk rising edge
    output ocrfhpkt;          // We have a packet for SLIP
    // Bus Interface side in the FPGA-to-host direction
    input  [7:0] icrfhdata;   // Data in from the bus interface
    output ocrfhtxe_;         // Transmitter empty (not) at bifh port
    input  icrfhwr;           // Take the new data, latched on clk rising edge
    input  icrfhpkt;          // ==1 if in a packet.  Rising edge == new pkt



//  CRC GENERATOR FOR FPGA-TO-HOST PATH
//  This code adds a two byte CRC checksum to the end of packets going
//  from the bus interface toward the host.  The rising edge of the
//  in-packet signal from the bus interface causes the crc to be set
//  to zero (CRC16/XMODEM).  The falling edge of the in-packet signal
//  puts the code into a state where the two bytes are added to the
//  data stream before lowering the in-packet signal going to the SLIP
//  encoder.
//    Major state are FHIDLE, FHINPKT, FHCRCH, and FHCRCL.

//  IDLE in the FPGA-to-host direction
`define FHIDLE              2'h0
//  In-packet.  Pass chars on and add to CRC
`define FHINPKT             2'h1
//  Send high byte of CRC
`define FHCRCH              2'h2
//  Send low byte of CRC
`define FHCRCL              2'h3


    reg  [1:0]   fhstate;     // packet state in FPGA-to-host path
    reg  [15:0]  crcout;      // 16 bit CRC

    initial
    begin
        fhstate = 0;
        crcout = 0;
    end

    //  The FPGA-to-host path has a CRC generator
    always @(posedge clk)
    begin
        if ((fhstate == `FHIDLE) & (icrfhpkt))
        begin
            // Got start of a packet
            crcout <= 16'h0000;
            fhstate <= `FHINPKT;
        end
        else if ((icrfhpkt) & (icrfhwr))
        begin
            // Got a byte in a packet.  Add to crc
            crcout <= crc16(crcout, icrfhdata);
        end
        else if ((fhstate == `FHINPKT) & (~icrfhpkt))
        begin
            // Got end of packet
            fhstate <= `FHCRCH;
        end
        else if ((fhstate == `FHCRCH) & (~icrfhtxe_))
        begin
            // Sent high byte, now send low byte
            fhstate <= `FHCRCL;
        end
        else if ((fhstate == `FHCRCL) & (~icrfhtxe_))
        begin
            // Sent low byte.  We're now idle
            fhstate <= `FHIDLE;
        end
    end

           // pass bytes to SLIP unless we're adding the CRC bytes
    assign ocrfhdata = (fhstate == `FHCRCH) ? crcout[15:8] :
                       (fhstate == `FHCRCL) ? crcout[7:0] :
                       icrfhdata;
           // apply backpressure to BI if we're getting it or if sending CRC bytes
    assign ocrfhtxe_ = icrfhtxe_ & (fhstate != `FHCRCH) & (fhstate != `FHCRCL) ;
           // Extend in-packet while sending the CRC bytes
    assign ocrfhpkt  = icrfhpkt | (fhstate != `FHIDLE);
           // Pass BI write strobe to SLIP directly.
           // Add strobes for CRC bytes unless SLIP is applying back pressure
    assign ocrfhwr   = icrfhwr | ((~icrfhtxe_) & ((fhstate == `FHCRCH) | (fhstate == `FHCRCL)));




//  CRC VALIDATION FOR HOST-TO-FPGA PATH
//  This code checks the two byte CRC at the end of packets from the
//  host.  Rising edge of in-packet from the SLIP decoder clears the
//  16 bit CRC and as each byte of the packet arrives it is added to
//  the CRC.  When in-packet from the SLIP decoder goes low we test
//  the CRC to see if it is now zero.  If so, the packet is sent to
//  the bus interface.  If the CRC is not zero, the packet is dropped.
//
//  This implementation use two 512 byte buffers.  As a packet is
//  arriving in one buffer the other buffer is being sent to the bus
//  interface.  
//    The slowest peripheral (as of this writing) is the WS2812 
//  peripheral.  It holds the bus while sending each bit.  A packet
//  of 256 WS2812 data take about 2 milliseconds to play out.
//  At 460800 baud that is only one received bit.  At 1 megabit, it
//  is two received bits, at 10 Mbps it is 20 received bits, and at
//  100 Mbps it is 200 received bit.  That is, ping-pong buffers 
//  will work fine up to 10 Mbps but above that this code should
//  switch to variable length circular buffers.
//
//  The one bit register "wrbuf" specifies which buffer is taking
//  in bytes from the host, and "~wrbuf" is sending bytes to the
//  bus.  All bytes are stored in a dual port RAM block with wrbuf
//  being the the high bit of the address.  The eight bit registers
//  "waddr" and "raddr" are concatenated to wrbuf to form the full
//  nine bit write and read addresses.
//    The receiver passes full packet to the transmitter (to the 
//  bus) by setting raddr to zero, setting "rcount" to the number
//  of bytes in the packet (less the CRC bytes), and setting the
//  state of the transmitter to sending-packet.  The transmitter
//  remains in the sending-packet state as long as raddr does not
//  equal rcount.
//
//  There are two possible types of error.  The first is a bad
//  CRC check.  The second is buffer overrun due to a slow bus.
//  There is no means to report either error.
//
//  We use hard coded numbers here to make the code easier to read.
//  The first time we change any numbers we will switch to using
//  parameters for the various sizes.

//  IDLE in the host-to-FPGA direction
`define HFIDLE              2'h0
//  In-packet.  Save chars on and add to CRC
`define HFINPKT             2'h1
//  Per bus cycle delay.  Must have at least one to allow data to
//  settle at the RAM output.  Usually add one or two more to let
//  busy and other lines from the peripherals to apply flow control.
`define BIDELAY             4'h4

    // register and wire declarations
    reg          wrbuf;       // which buffer is getting received bytes
    reg    [8:0] waddr;       // write index into buffer RAM
    reg    [8:0] raddr;       // read index into buffer RAM
    reg    [8:0] wcount;      // number of bytes written
    reg    [8:0] rcount;      // number of bytes to send to bus interface
    reg   [15:0] crcin;       // 16 bit CRC
    reg          hfstate;     // packet state in host-to-FPGA path
    reg          oldirxf_;    // used to detect positive edge of input rxf_
    reg    [3:0] bidelay;     // used to delay output of rxf_ to account for BI delay
    reg          bistart;     // ready to send received pkt to bus interface
                 // define RAM lines
    wire         we;          // write enable/clk
    wire   [9:0] wa;          // write address
    wire   [7:0] wd;          // write data
    wire   [9:0] ra;          // read address
    wire   [7:0] rd;          // read data
    assign       we = icrhfpkt & (~icrhfrxf_); // write if inpkt and strobe
    assign       wd = icrhfdata;      // data from host
    assign       wa = {wrbuf,waddr};  // buffer ID and index
    assign       ra = {~wrbuf,raddr}; // buffer ID and index
    crram        crbuf(clk,we,wa,wd,ra,rd);


    initial
    begin
        wrbuf = 0;
        waddr = 0;
        raddr = 0;
        wcount = 0;
        rcount = 0;
        crcin = 0;
        oldirxf_ = 1;
        bidelay = 0;
        bistart = 0;
        hfstate = `HFIDLE;
    end

    //  The host-to-FPGA path has a CRC decoder
    always @(posedge clk)
    begin
        oldirxf_ <= icrhfrxf_;          // save to detect rising edge

        // SLIP decoder to write RAM state machine
        if ((hfstate == `HFIDLE) && icrhfpkt)
        begin
            // start of new packet from the host
            hfstate <= `HFINPKT;
            // add first byte of packet to CRC
            crcin <= crc16(crcin, icrhfdata);
        end
        else if ((hfstate == `HFINPKT) && icrhfpkt && (~icrhfrxf_))
        begin
            // Got a byte while in-packet.  Add it to the CRC and to RAM
            crcin <= crc16(crcin, icrhfdata);
            wcount <= wcount + 9'd1;
        end
        else if ((hfstate == `HFINPKT) && icrhfpkt && (icrhfrxf_) && (~oldirxf_))
        begin
            // increment address on rising edge of rxf_, else we miss the first byte
            waddr <= waddr + 9'd1;
        end
        else if ((hfstate == `HFINPKT) && (~icrhfpkt))
        begin
            // End of packet from host.  Check CRC
            if (crcin == 16'h0000)
            begin
                rcount <= wcount - 9'h2;   // -2 to remove crc bytes
                raddr <= 9'h000;
                bistart <= 1;
                wrbuf <= ~wrbuf;           // swap write/read buffers
            end
            // Good crc or not, end of pkt means we go idle
            hfstate <= `HFIDLE;
            crcin <= 16'h0000;         //  CRC16/XMODEM init value
            waddr <= 9'h000;
            wcount <= 9'h000;
        end

        // RAM to bus interface state machine
        // The bus interface has some internal states and may need extra
        // clock cycles between writes.  We use busdelay for this delay.
        if (((rcount+9'h1) != raddr) & (~icrhfrd_)) // data to send and read strobe
        begin
            raddr <= raddr +9'h1;
            bidelay <= 4'h1;               // delay from 1 up to `BIDELAY
        end
        else if (bistart == 1)
        begin
            bistart <= 0;
            bidelay <= 1;                  // set initial delay
        end
        else if (bidelay == `BIDELAY)
            bidelay <= 0;                  // stop incrementing at terminal count
        else
            bidelay <= bidelay + 4'h1;
    end

    assign ocrhfdata = rd;                 // RAM data to the bus interface
    assign ocrhfrd_  = icrhfrxf_;          // ACK every byte offered from SLIP
    assign ocrhfpkt  = ((rcount+1) != raddr);  // in-pkt if bytes to send to bus
                                           // rxf_ delayed to allow for RAM and BI delays
    assign ocrhfrxf_ = ~(((rcount+9'h1) != raddr) & (bidelay == `BIDELAY) & (bistart == 0));



// Function to compute the CRC16/XMODEM CRC.  
function [15:0] crc16;
    input [15:0] crcin;    // starting crc 
    input [7:0]  charin;   // character to add to the crc

    reg   [7:0]  x;        // temp to help the computation

    begin
    //  x = (crc >> 8) ^ c;
    //  x ^= x >> 4;
    x[0] = (crcin[ 8] ^ charin[0]) ^ (crcin[12] ^ charin[4]);
    x[1] = (crcin[ 9] ^ charin[1]) ^ (crcin[13] ^ charin[5]);
    x[2] = (crcin[10] ^ charin[2]) ^ (crcin[14] ^ charin[6]);
    x[3] = (crcin[11] ^ charin[3]) ^ (crcin[15] ^ charin[7]);
    x[4] = crcin[12] ^ charin[4];
    x[5] = crcin[13] ^ charin[5];
    x[6] = crcin[14] ^ charin[6];
    x[7] = crcin[15] ^ charin[7];
    //    crc = (crc << 8) ^ ((uint16_t)x << 12) ^ ((uint16_t)x << 5) ^ ((uint16_t)x);
    crc16[ 0] = (  1'b0  ) ^ (      1'b0       ) ^ (       1'b0     ) ^ (    x[0]   );
    crc16[ 1] = (  1'b0  ) ^ (      1'b0       ) ^ (       1'b0     ) ^ (    x[1]   );
    crc16[ 2] = (  1'b0  ) ^ (      1'b0       ) ^ (       1'b0     ) ^ (    x[2]   );
    crc16[ 3] = (  1'b0  ) ^ (      1'b0       ) ^ (       1'b0     ) ^ (    x[3]   );
    crc16[ 4] = (  1'b0  ) ^ (      1'b0       ) ^ (       1'b0     ) ^ (    x[4]   );
    crc16[ 5] = (  1'b0  ) ^ (      1'b0       ) ^ (       x[0]     ) ^ (    x[5]   );
    crc16[ 6] = (  1'b0  ) ^ (      1'b0       ) ^ (       x[1]     ) ^ (    x[6]   );
    crc16[ 7] = (  1'b0  ) ^ (      1'b0       ) ^ (       x[2]     ) ^ (    x[7]   );
    crc16[ 8] = (crcin[0]) ^ (      1'b0       ) ^ (       x[3]     ) ^ (   1'b0    );
    crc16[ 9] = (crcin[1]) ^ (      1'b0       ) ^ (       x[4]     ) ^ (   1'b0    );
    crc16[10] = (crcin[2]) ^ (      1'b0       ) ^ (       x[5]     ) ^ (   1'b0    );
    crc16[11] = (crcin[3]) ^ (      1'b0       ) ^ (       x[6]     ) ^ (   1'b0    );
    crc16[12] = (crcin[4]) ^ (      x[0]       ) ^ (       x[7]     ) ^ (   1'b0    );
    crc16[13] = (crcin[5]) ^ (      x[1]       ) ^ (       1'b0     ) ^ (   1'b0    );
    crc16[14] = (crcin[6]) ^ (      x[2]       ) ^ (       1'b0     ) ^ (   1'b0    );
    crc16[15] = (crcin[7]) ^ (      x[3]       ) ^ (       1'b0     ) ^ (   1'b0    );
    end

endfunction

endmodule


//
// Dual-Port RAM with synchronous Read
// Implements two 512 byte buffers
//
module crram(clk,we,wa,wd,ra,rd);
    input    clk;                           // system clock
    input    we;                            // write strobe
    input    [9:0] wa;                      // write address
    input    [7:0] wd;                      // write data
    input    [9:0] ra;                      // read address
    output   [7:0] rd;                      // read data

    reg      [7:0] rdreg;
    reg      [7:0] ram [1023:0];

    always@(posedge clk)
    begin
        if (we)
            ram[wa] <= wd;
        rdreg <= ram[ra];
    end

    assign rd = rdreg;

endmodule


