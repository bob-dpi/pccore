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

`define NUM_CORE          9    // can address up to NUM_CORE peripherals
`define MX_PCPIN         33    // 8.5 peripherals, pins 0 to 33

`define BRD_CLOCK         0    //  "clk_in"
`define BRD_TX            1    //  Tx to host
`define BRD_RX            2    //  Rx from host
`define BRD_RED1          3    //  "Color_led_1[0]"
`define BRD_BLUE1         4    //  "Color_led_1[1]"
`define BRD_GREEN1        5    //  "Color_led_1[2]"
`define BRD_RED2          6    //  "Color_led_2[0]"
`define BRD_BLUE2         7    //  "Color_led_2[1]"
`define BRD_GREEN2        8    //  "Color_led_2[2]"
`define BRD_SEG1A         9    //  "Segment_led_1[0]"
`define BRD_SEG1B        10    //  "Segment_led_1[1]"
`define BRD_SEG1C        11    //  "Segment_led_1[2]"
`define BRD_SEG1D        12    //  "Segment_led_1[3]"
`define BRD_SEG1E        13    //  "Segment_led_1[4]"
`define BRD_SEG1F        14    //  "Segment_led_1[5]"
`define BRD_SEG1G        15    //  "Segment_led_1[6]"
`define BRD_SEG1DP       16    //  "Segment_led_1[7]"
`define BRD_SEG1         17    //  "Segment_led_1[8]"
`define BRD_SEG2A        18    //  "Segment_led_2[0]"
`define BRD_SEG2B        19    //  "Segment_led_2[1]"
`define BRD_SEG2C        20    //  "Segment_led_2[2]"
`define BRD_SEG2D        21    //  "Segment_led_2[3]"
`define BRD_SEG2E        22    //  "Segment_led_2[4]"
`define BRD_SEG2F        23    //  "Segment_led_2[5]"
`define BRD_SEG2G        24    //  "Segment_led_2[6]"
`define BRD_SEG2DP       25    //  "Segment_led_2[7]"
`define BRD_SEG2         26    //  "Segment_led_2[8]"
`define BRD_LED_0        27    //  "Water_led[0]"
`define BRD_LED_1        28    //  "Water_led[1]"
`define BRD_LED_2        29    //  "Water_led[2]"
`define BRD_LED_3        30    //  "Water_led[3]"
`define BRD_LED_4        31    //  "Water_led[4]"
`define BRD_LED_5        32    //  "Water_led[5]"
`define BRD_LED_6        33    //  "Water_led[6]"
`define BRD_LED_7        34    //  "Water_led[7]"
`define BRD_SW0          35    //  "SW[0]"
`define BRD_SW1          36    //  "SW[1]"
`define BRD_SW2          37    //  "SW[2]"
`define BRD_SW3          38    //  "SW[3]"
`define BRD_BTN0         39    //  "BTN[0]"
`define BRD_BTN1         40    //  "BTN[1]"
`define BRD_BTN2         41    //  "BTN[2]"

`define BRD_MX_LED        (`BRD_LED_0 + 7)        // LEDs are 0 to 7
`define BRD_MX_IO         (`BRD_BTN2)

