//////////////////////////////////////////////////////////////////////////
//
//  File: qtr4.v;   Interface to Pololu QTR-RC sensors
//
//      This peripheral interfaces a Pololu quad QTR-RC sensor to Linux.
//  The sensor is triggered and after a programmable delay all four
//  are sensed as either high or low.  That is, this peripheral does
//  not give the reflectance value, it tells if the reflectance is
//  above or below a threshold.
//
//  The sampling period is controlled by a 4 bit register and can be
//  set between 0 and 150ms.  A value of zero is the default and turns
//  off the sensor polling.  An 8 bit counter controls the amount of
//  time to wait before reading the input pins.  A short time makes
//  the sensor seem more sensitive and a longer time less sensitive.

//  Registers
//  0  :   Sensor values in low 4 LSBs.  1==black level detected.
//  1  :   8 bits sensitivity value.  This is the number of 10us
//         periods to wait until reading the sensor.
//  2  :   Sample period in units of 10 ms.  0 turns off sampling
//
/////////////////////////////////////////////////////////////////////////

// This code implements a simple state machine.  IDLE if waiting for
// the start of a poll.  CHARGING if charging the QRT capacitor, and
// SENSING if waiting to sense the pin values.
`define IDLE       2'h00
`define CHARGING   2'h01
`define SENSING    2'h02

module qtr4(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
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
    inout  [3:0] pins;       // FPGA I/O pins, QTR-RC inputs

    wire m10clk  =  clocks[`M10CLK];     // utility 10.00 millisecond pulse
    wire u10clk  =  clocks[`U10CLK];     // utility 10.00 microsecond pulse

    // Addressing and bus interface lines 
    wire   myaddr;           // ==1 if a correct read/write on our address
 
    // Counter state and signals
    reg    data_avail;       // Flag to say data is ready to send
    reg    [3:0] polltime;   // Poll interval in units of 10ms.  0==off
    reg    [3:0] pollcount;  // Counter from 0 to polltime.
    reg    [7:0] sensitivity; // Timer for when to sample input pins
    reg    [7:0] senscount;  // Counter from 0 to sensitivity.
    reg    [3:0] qtrval;     // sampled pin values
    reg    [1:0] state;      // One of idle, charging, or sensing


    initial
    begin
        state = `IDLE;
        data_avail = 0;
        polltime = 0;
        pollcount = 1;
        sensitivity = 1;
        senscount = 1;
    end

    always @(posedge CLK_I)
    begin
        // Update pollcount and start charging the QTR cap at timeout
        if (m10clk && (state == `IDLE))
        //if (m10clk)
        begin
            if (polltime != 0)
            begin
                if (pollcount == polltime)
                begin
                    state <= `CHARGING;     // Charge the QTR cap
                    pollcount <= 1;         // restart polling counter
                end
                else
                    pollcount <= pollcount + 4'h1;
            end
        end
        else if (u10clk && (state == `CHARGING))
        begin
            // We need to charge the cap for 1 us but do so for one 10us period
            state <= `SENSING;              // Wait for light sensitive discharge
        end
        else if (u10clk && (state == `SENSING))
        begin
            // Waiting for light sensitive discharge before reading the pins
            if (senscount == sensitivity)
            begin
                qtrval <= pins;             // read input pins    
                data_avail <= 1;            // set flag to send data to host
                senscount <= 1;             // comparison before inc so ==1
                state <= `IDLE;
            end
            else
                senscount <= senscount + 8'h01;
        end


        // Handle write requests from the host
        if (TGA_I & myaddr & WE_I & (ADR_I[1:0] == 2'h1))       // latch data on a write
            sensitivity <= DAT_I;               // sensitivity
        else if (TGA_I & myaddr & WE_I & (ADR_I[1:0] == 2'h2))  // latch data on a write
            polltime <= DAT_I[3:0];             // how often to poll pins

        // Any read from the host clears the data available flag.
        else if (TGA_I & myaddr & ~WE_I) // if a read from the host
        begin
            // Clear data_available if we are sending up to the host
            data_avail <= 0;
        end
    end

    assign pins[0] = (state == `CHARGING) ? 1'b1 : 1'bz ;
    assign pins[1] = (state == `CHARGING) ? 1'b1 : 1'bz ;
    assign pins[2] = (state == `CHARGING) ? 1'b1 : 1'bz ;
    assign pins[3] = (state == `CHARGING) ? 1'b1 : 1'bz ;

    assign myaddr = (STB_I) && (ADR_I[7:2] == 0);
    assign DAT_O = (~myaddr) ? DAT_I : 
                    // send 4 bits per sample
                    (~TGA_I && data_avail) ? 8'h01 :       // autosend one byte
                    (TGA_I & (ADR_I[1:0] == 0)) ? {4'h0,qtrval} :
                    (TGA_I & (ADR_I[1:0] == 1)) ? sensitivity :
                    (TGA_I & (ADR_I[1:0] == 2)) ? {4'h0,polltime} :
                    8'h00 ;

    // Loop in-to-out where appropriate
    assign STALL_O = 0;
    assign ACK_O = myaddr;

endmodule

