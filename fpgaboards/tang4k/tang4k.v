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
//////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////
//  Peripherals for the _Ax_elsys MachX_O2_ (axo2) FPGA card
//  Reg 64: Table of sixteen 16-bit peripherals ID numbers
//
/////////////////////////////////////////////////////////////////////////
module tang4k(CLK_O,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,BRDIO,PCPIN);
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
    wire   [15:0] perid;     // ID of peripheral in core specified by ADR_I 
    perilist periids(ADR_I[4:1], perid);
    wire   ck150mhz;         // 150 MHz clock
    wire   ck100mhz;         // 100 MHz clock
    wire   ck50mhz;          // 50 MHz clock for PLL debugging
    reg    [1:0] hist1;      // current values of the user buttons
    reg    [1:0] hist2;      // past values of the user buttons
    reg    data_ready;       // New button values to send to host


    // Convert the 27 MHz clock to 150 MHz.  Then convert the 150 MHz clock
    // to 100 MHz to drive the clock divide chain.
    CK27to150 ck27to150(ck150mhz, ck50mhz, BRDIO[`BRD_CLOCK]);
    CK150to100 ck150to100(ck100mhz, ck150mhz);
    clocks gensysclks(ck100mhz, CLK_O, clocks);


    // Bring the keys into our clock domain.
    always @(posedge CLK_O)
    begin
        hist1 <= BRDIO[`BRD_KEY2:`BRD_KEY1];
        hist2 <= hist1;

        // clear data_ready register on a read
        if (TGA_I & myaddr & ~WE_I)  // clear marked register on any read
            data_ready <= 0;

        // edge detection for sending data up to the host
        else if (hist1 != hist2)
        begin
            data_ready <= 1;
        end
    end
 


    // data out is the button if a read on us, our data ready send command 
    // if a poll from the bus interface, and data_in in all other cases.
    assign myaddr = (STB_I) && (ADR_I[7] == 0);
    assign DAT_O = (~myaddr) ? DAT_I : 
                    (~TGA_I & data_ready) ? 8'h01 :   // send up one byte if data available
                     (TGA_I && (ADR_I[6] == 0)) ? {6'h00,hist1} :
                     (TGA_I && (ADR_I[6] == 1) && (ADR_I[0] == 0)) ? perid[15:8] :
                     (TGA_I && (ADR_I[6] == 1) && (ADR_I[0] == 1)) ? perid[7:0] :
                     8'h00;

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule


// Use a PLL to convert the 27 MHz board clock to 150 MHz
module CK27to150 (clkout, clkoutd3, clkin);
output clkout;      // 150 MHz
output clkoutd3;    // 50 MHz  (used while debugging)
input  clkin;       // board clock at 27 MHz

wire lock_o;
wire clkoutp_o;
wire clkoutd_o;
wire gw_vcc;
wire gw_gnd;

assign gw_vcc = 1'b1;
assign gw_gnd = 1'b0;

PLLVR pllvr_inst (
    .CLKOUT(clkout),
    .LOCK(lock_o),
    .CLKOUTP(clkoutp_o),
    .CLKOUTD(clkoutd_o),
    .CLKOUTD3(clkoutd3),
    .RESET(gw_gnd),
    .RESET_P(gw_gnd),
    .CLKIN(clkin),
    .CLKFB(gw_gnd),
    .FBDSEL({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .IDSEL({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .ODSEL({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .PSDA({gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .DUTYDA({gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .FDLY({gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .VREN(gw_vcc)
);

// VCO frequency = (FCLKIN*(FBDIV_SEL+1)*ODIV_SEL)/(IDIV_SEL+1)
defparam pllvr_inst.FCLKIN = "27";
defparam pllvr_inst.DYN_IDIV_SEL = "false";
defparam pllvr_inst.IDIV_SEL = 8;
defparam pllvr_inst.DYN_FBDIV_SEL = "false";
defparam pllvr_inst.FBDIV_SEL = 49;
defparam pllvr_inst.DYN_ODIV_SEL = "false";
defparam pllvr_inst.ODIV_SEL = 8;
defparam pllvr_inst.PSDA_SEL = "0000";
defparam pllvr_inst.DYN_DA_EN = "true";
defparam pllvr_inst.DUTYDA_SEL = "1000";
defparam pllvr_inst.CLKOUT_FT_DIR = 1'b1;
defparam pllvr_inst.CLKOUTP_FT_DIR = 1'b1;
defparam pllvr_inst.CLKOUT_DLY_STEP = 0;
defparam pllvr_inst.CLKOUTP_DLY_STEP = 0;
defparam pllvr_inst.CLKFB_SEL = "internal";
defparam pllvr_inst.CLKOUT_BYPASS = "false";
defparam pllvr_inst.CLKOUTP_BYPASS = "false";
defparam pllvr_inst.CLKOUTD_BYPASS = "false";
defparam pllvr_inst.DYN_SDIV_SEL = 2;
defparam pllvr_inst.CLKOUTD_SRC = "CLKOUT";
defparam pllvr_inst.CLKOUTD3_SRC = "CLKOUT";
defparam pllvr_inst.DEVICE = "GW1NSR-4C";

endmodule 


// Use a PLL to convert the 150 MHz MHz clock to 100 MHz.
// VCO frequency = (FCLKIN*(FBDIV_SEL+1)*ODIV_SEL)/(IDIV_SEL+1)
module CK150to100 (clkout, clkin);
output clkout;
input clkin;

wire lock_o;
wire clkoutp_o;
wire clkoutd_o;
wire gw_vcc;
wire gw_gnd;

assign gw_vcc = 1'b1;
assign gw_gnd = 1'b0;

PLLVR pllvr_inst (
    .CLKOUT(clkout),
    .LOCK(lock_o),
    .CLKOUTP(clkoutp_o),
    .CLKOUTD(clkoutd_o),
    .CLKOUTD3(),
    .RESET(gw_gnd),
    .RESET_P(gw_gnd),
    .CLKIN(clkin),
    .CLKFB(gw_gnd),
    .FBDSEL({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .IDSEL({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .ODSEL({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .PSDA({gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .DUTYDA({gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .FDLY({gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .VREN(gw_vcc)
);
defparam pllvr_inst.FCLKIN = "150";
defparam pllvr_inst.DYN_IDIV_SEL = "false";
defparam pllvr_inst.IDIV_SEL = 2;
defparam pllvr_inst.DYN_FBDIV_SEL = "false";
defparam pllvr_inst.FBDIV_SEL = 1;
defparam pllvr_inst.DYN_ODIV_SEL = "false";
defparam pllvr_inst.ODIV_SEL = 8;
defparam pllvr_inst.PSDA_SEL = "0000";
defparam pllvr_inst.DYN_DA_EN = "true";
defparam pllvr_inst.DUTYDA_SEL = "1000";
defparam pllvr_inst.CLKOUT_FT_DIR = 1'b1;
defparam pllvr_inst.CLKOUTP_FT_DIR = 1'b1;
defparam pllvr_inst.CLKOUT_DLY_STEP = 0;
defparam pllvr_inst.CLKOUTP_DLY_STEP = 0;
defparam pllvr_inst.CLKFB_SEL = "internal";
defparam pllvr_inst.CLKOUT_BYPASS = "false";
defparam pllvr_inst.CLKOUTP_BYPASS = "false";
defparam pllvr_inst.CLKOUTD_BYPASS = "false";
defparam pllvr_inst.DYN_SDIV_SEL = 2;
defparam pllvr_inst.CLKOUTD_SRC = "CLKOUT";
defparam pllvr_inst.DEVICE = "GW1NSR-4C";
endmodule //Gowin_PLLVR



