


//  File: sr04.v;   SR04 interface with broadcast trigger
//
//  Registers are
//    Addr=0/1    Echo time of sensor 1 in microseconds
//    Addr=2/3    Echo time of sensor 2 in microseconds
//    Addr=4/5    Echo time of sensor 3 in microseconds
//    Addr=6/7    Echo time of sensor 4 in microseconds
//    Addr=8/9    Echo time of sensor 5 in microseconds
//    Addr=10/11  Echo time of sensor 6 in microseconds
//    Addr=12/13  Echo time of sensor 7 in microseconds
//    Addr=14     Poll interval in units of 10 ms, 0==off
//
// NOTES:
//     This peripheral does a broadcast ping of a set of SR04 sensors.
// The system goes through several states to complete a poll.
`define  ST_WAIT  0     // The system is not yet polling
`define  ST_TRIG  1     // 10 us period to hold trigger high
`define  ST_CLR   2     // Clear times to zero
`define  ST_SMPL  3     // Record echo times
//
//
/////////////////////////////////////////////////////////////////////////
module sr04(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
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
    inout  [7:0] pins;       // Pins to HC04 modules.  Strobe is LSB
 
    wire   myaddr;           // ==1 if a correct read/write on our address
    wire   m10clk  =  clocks[`M10CLK];     // utility 10.00 millisecond pulse
    wire   u100clk =  clocks[`U100CLK];    // utility 100.0 microsecond pulse 
    wire   u10clk  =  clocks[`U10CLK];     // utility 10.00 microsecond pulse 
    wire   u1clk   =  clocks[`U1CLK];      // utility 1.000 microsecond pulse 

    reg    [1:0] state;      // State of the peripheral
    reg    [3:0] rate;       // Poll period in units of 10 ms.
    reg    [3:0] polltmr;    // Poll period counter
    reg    sendflag;         // ==1 when data is ready for the host
    reg    [3:0] trigtmr;    // Trigger is 10 us pulse
    reg    [2:0] masktmr;    // Ignore inputs just after trigger pulse
    reg    [6:0] meta;       // bring inputs into our clock domain
    reg    [2:0] taddr;      // echo timer location in RAM (ie its addr)
    reg    dopoll;           // poll only 1 us edges
    wire   pollpin;          // value of pins[taddr]

    // RAM for echo timers and its lines
    wire   [15:0] etmout;    // RAM output lines
    wire   [15:0] etmin;     // RAM input lines
    wire   [2:0]  etmaddr;   // RAM address
    wire   etwen;            // RAM write enable
    ram16x8sr04 echotimes(etmout,etmaddr,etmin,CLK_I,etwen);

    initial
    begin
        rate = 0;
        state = 0;
        sendflag = 0;
        polltmr = 0;
        taddr = 0;
        dopoll = 0;
    end

    always @(posedge CLK_I)
    begin
        // Get the inputs and bring into our clock domain
        meta   <= pins[7:1]; 

        // Latch new poll interval on write to reg 14.
        if (TGA_I & myaddr & WE_I & (ADR_I[3:0] == 14))
        begin
            rate <= DAT_I[3:0];  // get poll interval 
            state <= `ST_WAIT;   // wait for next poll
        end
        else if (TGA_I & myaddr & ~WE_I)
        begin
            // clear data ready flag on any host read
            sendflag <= 0;
        end


        // Go to trigger state on 10 ms edge when poll timer reaches zero.
        // This runs regardless of current state.
        if ((m10clk) && (rate != 4'h0))
        begin
            if (polltmr == 0)
            begin
                state <= `ST_TRIG;
                polltmr <= rate - 4'h1; // re-init timer
                sendflag <= 1'b1;       // send times up to host
                $display("Send flag set at t=", $time);
            end
            else
                polltmr <= polltmr - 4'h1;
        end

        // If in trigger state go clear ram on first 10us clock
        if ((state == `ST_TRIG) && (u10clk))
        begin
            state <= `ST_CLR;
            taddr <= 6;
        end

        // Clear echo timer RAM locations
        else if (state == `ST_CLR)
        begin
            if (taddr == 0)
                state <= `ST_SMPL;
            else
                taddr <= taddr - 1;
        end

        // Examine input pins at 1 us intervals
        else if (state == `ST_SMPL)
        begin
            if (dopoll)             // if examining inputs
            begin
                if (taddr == 0)
                    dopoll <= 0;
                else
                    taddr <= taddr -1;
            end
            else if (u1clk)         // start examining inputs
            begin
                dopoll <= 1;
                taddr <= 6;
            end
        end
    end

    // Get the pin corresponding to input # taddr
    assign pollpin = (taddr == 0) ? meta[0] : 
                     (taddr == 1) ? meta[1] : 
                     (taddr == 2) ? meta[2] : 
                     (taddr == 3) ? meta[3] : 
                     (taddr == 4) ? meta[4] : 
                     (taddr == 5) ? meta[5] : 
                     (taddr == 6) ? meta[6] : 0;

    // The echo times are stored in RAM.  We clear the RAM
    // during the ST_CLR state and increment its value if
    // input pin "taddr" is high during a poll.
    assign etmin  = (state == `ST_SMPL) ? (etmout + pollpin) : 0 ;
    assign etwen = ((state == `ST_CLR) ||
                   ((state == `ST_SMPL) && (dopoll)));
    // bus address if a read, taddr otherwise
    assign etmaddr = (myaddr & TGA_I & ~WE_I) ? ADR_I[3:1] : taddr;

    // Assign the outputs.
    assign pins[0] = (state == `ST_TRIG) ? 1 : 0;

    assign myaddr = (STB_I) && (ADR_I[7:4] == 0);
    assign DAT_O = (~myaddr) ? DAT_I : 
                    (~TGA_I & sendflag) ? 8'd14 :   // results to host
                     (TGA_I && (ADR_I[3:0] == 14)) ? {4'h0,rate} :
                     (TGA_I && (ADR_I[3:0] != 14)) ?
                         ((ADR_I[0]) ? etmout[7:0] : etmout[15:8]) :
                     8'h00;

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule



// Distributed RAM to store echo timers
module ram16x8sr04(dout,addr,din,wclk,wen);
    output   [15:0] dout;
    input    [2:0] addr;
    input    [15:0] din;
    input    wclk;
    input    wen;

    reg      [15:0] ram [8];

    always@(posedge wclk)
    begin
        if (wen)
            ram[addr] <= din;
    end

    assign dout = ram[addr];

endmodule

