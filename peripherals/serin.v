//////////////////////////////////////////////////////////////////////////
//
//  File: serialin: Quad/Octal serial input port
//
//  Registers are (for quad port)
//    Addr=0    Data Out port #1
//    Addr=1    Data Out port #2
//    Addr=2    Data Out port #3
//    Addr=3    Data Out port #4
//    Addr=4    Baud rate divider
//
// NOTES:  The FIFO buffers are implemented using one dual-port
// block RAM.   The only read source is the host.  Depending on
// the activity all of the ports may try to write the RAM at the
// same time.  To resolve the conflicting write access we use
// a counter (rdsel) that sequentially looks at each port in turn.
//
//   The input sample rate is based on the baud rate and is set
// to about 65 samples per baud bit.  Samples are taken when the
// 'smplctr' counter reaches zero.
//
//   Each port has a low pass filter.  See the header block for lpf
// below for details.  The output of the low pass filters includes
// the previous state of the input and the next state.  We use this
// to detect a falling edge at the beginning of the start bit.
// 
//   Each port has three pieces of state associated with it.  The
// one-bit 'inxfer' is set to one when a start bit is detected and
// set back to zero after the eigth data bit is saved.  The 3-bit
// counter 'bitidx' says which bit we are currently getting.  The
// 7-bit counter 'bitdly' is used to delay one bit time.  The input
// bit is saved when bitdly reaches zero.  It is reloaded with 65 to
// delay for the next bit.  We want to skip over the start bit so
// the very first delay is (65 + 48) samples.  The idea of reading
// the bit 48 samples into it is to read after the low pass filter
// has captured the real value of the bit.
//
/////////////////////////////////////////////////////////////////////////

        // Log Base 2 of the buffer size for each port.  Should be betwee
        // 4 and 8.  Larger values ease the load on the USB port by sending
        // fuller USB packets.  Smaller buffers ease the FPGA resources 
        // needed.  
`define LB2BUFSZ   5


module serin(clk,rdwr,strobe,our_addr,addr,busy_in,busy_out,
       addr_match_in,addr_match_out,datin,datout,rxd);
    parameter NPORT = 8;
    parameter LOGNPORT = 3;
    input  clk;              // system clock
    input  rdwr;             // direction of this transfer. Read=1; Write=0
    input  strobe;           // true on full valid command
    input  [3:0] our_addr;   // high byte of our assigned address
    input  [11:0] addr;      // address of target peripheral
    input  busy_in;          // ==1 if a previous peripheral is busy
    output busy_out;         // ==our busy state if our address, pass through otherwise
    input  addr_match_in;    // ==1 if a previous peripheral claims the address
    output addr_match_out;   // ==1 if we claim the above address, pass through otherwise
    input  [7:0] datin ;     // Data INto the peripheral;
    output [7:0] datout ;    // Data OUTput from the peripheral, = datin if not us.
    input  [NPORT-1:0] rxd;  // input lines

    wire   myaddr;           // ==1 if a correct read/write on our address
    genvar  i;               // loop counter to generate code
    integer j;               // loop counter

           // Target baud rate
    reg    [3:0] baudrate;   // 0=38400,1=19200,3=9600,7=4800,f=2400
    reg    [3:0] smplctr;    // sets sample rate based on baudrate

           // Which input port to examine and process
    reg    [LOGNPORT-1:0] rdsel;   // port select counter

           // Bit state and shift register info
    reg    inxfer [NPORT-1:0];     // ==1 while in a byte transfer
    reg    [2:0] bitidx [NPORT-1:0]; // which bit we a receiving
    reg    [6:0] bitdly [NPORT-1:0]; // interbit delay counter

           //  Per port FIFO control lines
    reg    [`LB2BUFSZ-1:0] warx [NPORT-1:0]; // FIFO write address for Rx
    reg    [`LB2BUFSZ-1:0] rarx [NPORT-1:0]; // FIFO read address for Rx
    wire   [NPORT-1:0] buffull;    // ==1 if FIFO can not take more characters
    wire   [NPORT-1:0] bufempty;   // ==1 if there are no characters to send
    for (i = 0; i < NPORT; i=i+1)
    begin : gen_fifo_wires
        assign buffull[i] = ((warx[i] + `LB2BUFSZ'h01) == rarx[i]);
        assign bufempty[i] = (warx[i] == rarx[i]);
    end

           // Autosend to the host control lines
    reg    [LOGNPORT-1:0] sendport;  // which port needs to be read by host
    reg    autosend;              // set if we need to send up any port
    wire   [`LB2BUFSZ:0] usage;   // number of bytes in a FIFO
    assign usage = (2**`LB2BUFSZ) + warx[rdsel[LOGNPORT-1:0]] -
                   rarx[rdsel[LOGNPORT-1:0]];

           // Block RAM control lines
    wire   we;                    // RAM write strobe for Rx
    wire   [3+`LB2BUFSZ+LOGNPORT-1:0] wa;  // bit write address
    wire   [`LB2BUFSZ+LOGNPORT-1:0] ra;    // bit read address
    wire   wd;                    // shift data in
    wire   [7:0] rd;              // registered read data from RAM
    reg    busy;                  // set to 1 to delay read cycle for RAM 
    wire   wdout;                 // output of side A (not used)

    serinfifo memrx(clk, we, wa, wd, wdout, clk, 1'b0, ra, 8'h00, rd);

           // write as we transition from one bit to the next.  That is, when
           // the rdsel port is in a transfer, and when bit delay counter is zero.
    assign we = ((smplctr == 4'h0) && (inxfer[rdsel] == 1'b1) && 
                 (bitdly[rdsel] == 7'h00));
           // write address is port number in high bits and port's FIFO
           // write address in the lower bits, and the bit number in the
           // lowest three bits
    assign wa = {rdsel[LOGNPORT:0],warx[rdsel[LOGNPORT-1:0]],bitidx[rdsel[LOGNPORT-1:0]]};
           // read address is port number from rdsel and the FIFO read address
    assign ra = {addr[LOGNPORT-1:0], rarx[addr[LOGNPORT-1:0]]};
           // data written into the RAM is the current data bit 
    assign wd = curbit;

           // Low Pass Filter
           // The low pass filter looks at each input in turn (based on rdsel)
           // and accumulates a +1 if the input is high or a -1 if the input
           // is low.  The outputs are the current bit for rxd[rdsel] and
           // the next bit.  The inputs are examined only when smplctr is zero.
    wire   nxtbit;     // next value of LPF output for rxd[rdsel]
    wire   curbit;     // current value of LPF output for rxd[rdsel]
    lpf    #(.NPORT(NPORT)) lpfrx(clk, rxd, rdsel, (smplctr == 1'b0), nxtbit, curbit);


    initial
    begin
        baudrate = 4'h0;
        smplctr = 4'h0;
        rdsel = 4'h0;
        busy = 1'b1;       // busy the on the first read access
        autosend = 1'b0;
        for (j = 0; j < NPORT; j = j+1)
        begin : initfifo
            warx[j]   = `LB2BUFSZ'h00;
            rarx[j]   = `LB2BUFSZ'h00;
            inxfer[j] = 1'b0;
            bitidx[j] = 3'h0;
            bitdly[j] = 7'h00;
        end
    end

    always @(posedge clk)
    begin
        if (strobe & myaddr)  // read from FIFO or write to baudrate
        begin
            // Write to the baudrate register?
            if ((~rdwr) & (addr[LOGNPORT] == 1'b1))
            begin
                baudrate <= datin[3:0];
            end
            // Read from one of the character FIFOs?
            if ((rdwr) & (addr[LOGNPORT] == 1'b0) & (~bufempty[addr[LOGNPORT-1:0]]))
            begin
                // Pop FIFO character
                if (~busy)
                begin
                    rarx[addr[LOGNPORT-1:0]] <= rarx[addr[LOGNPORT-1:0]] + `LB2BUFSZ'h01;
                    busy <= 1'b1;
                    autosend <= 1'b0;  // clear autosend on host read
                end
                else
                    busy <= 1'b0;
            end
        end

        // We want to sample the inputs at a rate that is set by the
        // baudrate.  At 38400 we sample one input on every sysclk.  
        // At 19200, every two sysclk.  The down counter smplctr is
        // is decremented to zero and then reloaded from baudrate
        if (smplctr != 4'h0)
        begin
            smplctr <= smplctr - 4'h1;
        end
        else
        begin
            smplctr <= baudrate;   // reset the sample down counter
            rdsel <= rdsel + 4'h1; // look at next input

            // Check for start bit in idle input port
            if ((inxfer[rdsel] == 1'b0) && (nxtbit == 1'b0) &&
                (curbit == 1'b1) && (buffull[rdsel] == 1'b0))
            begin
                inxfer[rdsel] <= 1'b1;
                bitdly[rdsel] <= 7'd113;   // (65 + 48);
            end
            // else process input if we are already in an xfer
            else if (inxfer[rdsel] == 1'b1)
            begin
                // decrement the bit delay counter and reload it if needed
                if (bitdly[rdsel] == 7'h00)
                begin
                    // it is at this point that we write the current bit
                    // into the FIFO and go to the next bit
                    bitdly[rdsel] <= 7'd65;
                    bitidx[rdsel] <= bitidx[rdsel] + 3'h1;  // go to next bit
                    if (bitidx[rdsel] == 3'h7)              // done with char?
                    begin
                        // Done with this char. update FIFO write address
                        warx[rdsel] <= warx[rdsel] + `LB2BUFSZ'h01;
                        inxfer[rdsel] <= 1'b0;
                        // Is the FIFO three quarters full?  Autosend if nothing pending.
                        if ((usage[`LB2BUFSZ-1:`LB2BUFSZ-2] == 2'b11) && (autosend == 1'b0))
                        begin
                            autosend <= 1'b1;
                            sendport <= rdsel;
                        end
                    end
                end
                else
                begin
                    bitdly[rdsel] <= bitdly[rdsel] - 1;
                end
            end
        end
    end

    // Assign the outputs.
    assign myaddr = (addr[11:8] == our_addr) && (addr[7:LOGNPORT+1] == 5'h00);
    assign datout = (~myaddr) ? datin : 
                     (strobe && (addr[LOGNPORT:0] == NPORT)) ? {4'h0,baudrate} : 
                     rd; 

    // Loop in-to-out where appropriate
    // two cycles for a non-empty FIFO read
    assign busy_out = (~myaddr) ? busy_in : 
                      (busy & ((rdwr) & (addr[LOGNPORT] == 1'b0) &
                       (~bufempty[addr[LOGNPORT-1:0]])));

    // Accept write byte if our address and the config register or a non-empty FIFO read
    assign addr_match_out = addr_match_in | (myaddr & addr[LOGNPORT]) |
                            (myaddr & ~bufempty[addr[LOGNPORT-1:0]]);

endmodule



//
// Low Pass Filter.
// Accumulate a +1 if input[insel] is one and -1 if zero.  Saturate at
// values of 15 and 0.  We use hysteresis as part of the noise rejection.
// A zero bit must reach a value of 12 before it is switched to a one bit,
// and a one bit must get down to 3 to be declared a zero bit.
// We expect enable to go high about 65 times per baud bit.
module
lpf(clk, rxd, insel, enable, nxtbit, curbit);
    parameter NPORT = 8;
    input    clk;                           // system clock
    input    [7:0] rxd;                     // input Rx lines
    input    [2:0] insel;                   // which input line to process
    input    enable;                        // accumulate when set
    output   nxtbit;                        // new value of LPF output for bit
    output   curbit;                        // old value of LPF output for bit

    reg      [3:0] accum [NPORT-1:0];       // accumulators
    reg      current [NPORT-1:0];           // Current bit values
    wire     next;                          // the next value of the bit
    integer  j;

    initial
    begin
        for (j = 0; j < NPORT; j = j+1)
        begin : initaccum
            accum[j] = 4'h0;
            current[j]  = 1'b0;
        end
    end

    always@(posedge clk)
    begin
        if (enable)
        begin
            current[insel] <= next;

            // if input line is a zero and not zero saturated
            if ((rxd[insel] == 1'b0) && (accum[insel] != 4'h0))
                accum[insel] <= accum[insel] - 1;
            // if input line is a one and we're not saturated
            if ((rxd[insel] == 1'b1) && (accum[insel] != 4'hf))
                accum[insel] <= accum[insel] + 1;
        end
    end

    // The next bit is one if the accumulator is 12 or above,
    // is zero if the accumulator is 3 or below, and is not
    // changed if between 4 and 11
    assign next = (accum[insel] >= 4'd12) ? 1'b1 :
                  (accum[insel] <= 4'd3) ? 1'b0 :
                  current[insel];

    assign nxtbit = next;
    assign curbit = current[insel];

endmodule


/*******************************************************************************
*     This file is owned and controlled by Xilinx and must be used             *
*     solely for design, simulation, implementation and creation of            *
*     design files limited to Xilinx devices or technologies. Use              *
*     with non-Xilinx devices or technologies is expressly prohibited          *
*     and immediately terminates your license.                                 *
*                                                                              *
*     XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS"            *
*     SOLELY FOR USE IN DEVELOPING PROGRAMS AND SOLUTIONS FOR                  *
*     XILINX DEVICES.  BY PROVIDING THIS DESIGN, CODE, OR INFORMATION          *
*     AS ONE POSSIBLE IMPLEMENTATION OF THIS FEATURE, APPLICATION              *
*     OR STANDARD, XILINX IS MAKING NO REPRESENTATION THAT THIS                *
*     IMPLEMENTATION IS FREE FROM ANY CLAIMS OF INFRINGEMENT,                  *
*     AND YOU ARE RESPONSIBLE FOR OBTAINING ANY RIGHTS YOU MAY REQUIRE         *
*     FOR YOUR IMPLEMENTATION.  XILINX EXPRESSLY DISCLAIMS ANY                 *
*     WARRANTY WHATSOEVER WITH RESPECT TO THE ADEQUACY OF THE                  *
*     IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OR           *
*     REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE FROM CLAIMS OF          *
*     INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS          *
*     FOR A PARTICULAR PURPOSE.                                                *
*                                                                              *
*     Xilinx products are not intended for use in life support                 *
*     appliances, devices, or systems. Use in such applications are            *
*     expressly prohibited.                                                    *
*                                                                              *
*     (c) Copyright 1995-2009 Xilinx, Inc.                                     *
*     All rights reserved.                                                     *
*******************************************************************************/
// The synthesis directives "translate_off/translate_on" specified below are
// supported by Xilinx, Mentor Graphics and Synplicity synthesis
// tools. Ensure they are correct for your synthesis tool(s).

// You must compile the wrapper file serinfifo.v when simulating
// the core, serinfifo. When compiling the wrapper file, be sure to
// reference the XilinxCoreLib Verilog simulation library. For detailed
// instructions, please refer to the "CORE Generator Help".

`timescale 1ns/1ps

module serinfifo(
	clka,
	wea,
	addra,
	dina,
	douta,
	clkb,
	web,
	addrb,
	dinb,
	doutb);


input clka;
input [0 : 0] wea;
input [11 : 0] addra;
input [0 : 0] dina;
output [0 : 0] douta;
input clkb;
input [0 : 0] web;
input [8 : 0] addrb;
input [7 : 0] dinb;
output [7 : 0] doutb;

// synthesis translate_off

      BLK_MEM_GEN_V4_1 #(
		.C_ADDRA_WIDTH(12),
		.C_ADDRB_WIDTH(9),
		.C_ALGORITHM(0),
		.C_BYTE_SIZE(9),
		.C_COMMON_CLK(1),
		.C_DEFAULT_DATA("0"),
		.C_DISABLE_WARN_BHV_COLL(0),
		.C_DISABLE_WARN_BHV_RANGE(0),
		.C_FAMILY("spartan3"),
		.C_HAS_ENA(0),
		.C_HAS_ENB(0),
		.C_HAS_INJECTERR(0),
		.C_HAS_MEM_OUTPUT_REGS_A(0),
		.C_HAS_MEM_OUTPUT_REGS_B(0),
		.C_HAS_MUX_OUTPUT_REGS_A(0),
		.C_HAS_MUX_OUTPUT_REGS_B(1),
		.C_HAS_REGCEA(0),
		.C_HAS_REGCEB(0),
		.C_HAS_RSTA(0),
		.C_HAS_RSTB(0),
		.C_HAS_SOFTECC_INPUT_REGS_A(0),
		.C_HAS_SOFTECC_INPUT_REGS_B(0),
		.C_HAS_SOFTECC_OUTPUT_REGS_A(0),
		.C_HAS_SOFTECC_OUTPUT_REGS_B(0),
		.C_INITA_VAL("0"),
		.C_INITB_VAL("0"),
		.C_INIT_FILE_NAME("no_coe_file_loaded"),
		.C_LOAD_INIT_FILE(0),
		.C_MEM_TYPE(2),
		.C_MUX_PIPELINE_STAGES(0),
		.C_PRIM_TYPE(0),
		.C_READ_DEPTH_A(4096),
		.C_READ_DEPTH_B(512),
		.C_READ_WIDTH_A(1),
		.C_READ_WIDTH_B(8),
		.C_RSTRAM_A(0),
		.C_RSTRAM_B(0),
		.C_RST_PRIORITY_A("CE"),
		.C_RST_PRIORITY_B("CE"),
		.C_RST_TYPE("SYNC"),
		.C_SIM_COLLISION_CHECK("WARNING_ONLY"),
		.C_USE_BYTE_WEA(0),
		.C_USE_BYTE_WEB(0),
		.C_USE_DEFAULT_DATA(1),
		.C_USE_ECC(0),
		.C_USE_SOFTECC(0),
		.C_WEA_WIDTH(1),
		.C_WEB_WIDTH(1),
		.C_WRITE_DEPTH_A(4096),
		.C_WRITE_DEPTH_B(512),
		.C_WRITE_MODE_A("WRITE_FIRST"),
		.C_WRITE_MODE_B("WRITE_FIRST"),
		.C_WRITE_WIDTH_A(1),
		.C_WRITE_WIDTH_B(8),
		.C_XDEVICEFAMILY("aspartan3e"))
	inst (
		.CLKA(clka),
		.WEA(wea),
		.ADDRA(addra),
		.DINA(dina),
		.DOUTA(douta),
		.CLKB(clkb),
		.WEB(web),
		.ADDRB(addrb),
		.DINB(dinb),
		.DOUTB(doutb),
		.RSTA(),
		.ENA(),
		.REGCEA(),
		.RSTB(),
		.ENB(),
		.REGCEB(),
		.INJECTSBITERR(),
		.INJECTDBITERR(),
		.SBITERR(),
		.DBITERR(),
		.RDADDRECC());


// synthesis translate_on

// XST black box declaration
// box_type "black_box"
// synthesis attribute box_type of serinfifo is "black_box"

endmodule

