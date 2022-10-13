/////////////////////////////////////////////////////////////////////////
//  File: brddefs.h     FPGA board specific pin definitions 
//
/////////////////////////////////////////////////////////////////////////

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
// *********************************************************

/////////////////////////////////////////////////////////////////////////
//
`define BRD_CLOCK         0        // 12.5 MHz
`define BRD_BTN_0         1
`define BRD_MX_BTN        3        // buttons are 0 to 2
`define BRD_LED_0         4                
`define BRD_MX_LED        11       // LEDs are 0 to 7

`define BRD_RXF_          12       // New data is available
`define BRD_RD_           13       // Active low read data
`define BRD_TXE_          14       // Transmit buffer empty (not)
`define BRD_WR            15       // Write data on positive edge
`define BRD_DATA_0        16       // USB Data 0
`define BRD_DATA_1        17       // USB Data 1
`define BRD_DATA_2        18       // USB Data 2
`define BRD_DATA_3        19       // USB Data 3
`define BRD_DATA_4        20       // USB Data 4
`define BRD_DATA_5        21       // USB Data 5
`define BRD_DATA_6        22       // USB Data 6
`define BRD_DATA_7        23       // USB Data 7
`define BRD_MX_IO         (`BRD_DATA_7)

`define NUM_CORE          16   // can address up to NUM_CORE peripherals
`define MX_PCPIN          31   // eight peripherals, pins 0 to 31

