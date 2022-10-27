### pccore

This repository contains the Verilog FPGA-based peripherals
that are the core of the Peripheral Control project.  The
contents of this directory should be of interest to anyone
who wants to create a new Verilog peripheral or who wants
to modify an existing one.

If you don't need to create a new Verilog peripheral you
may find it easier to use the build service offered by
Demand Peripherals.  The service lets you select your FPGA
card and the peripherals you want.  The resulting binary
FPGA image is then emailed to you.  This service is available
from the Demand Peripherals Support page: 
https://demandperipherals.com/support/build_fpga.html.

**QUICK INDEX:**<br>
 - [**System  Architecture**](#arch)<br>
 - [**How to Build the Peripheral Control Project**](#build)<br>
   - [**Supported FPGA Boards**](#boards)<br>
   - [**Tool Chain Installation**](#toolchain)<br>
   - [**Make, Download, and Test**](#maketest)<br>
 - [**How to Write a New Peripheral**](#newperi)<br>
   - [**The Peripheral Control Wishbone bus**](#wish)<br>
   - [**Clone an Existing Peripheral**](#clone)<br>
   - [**Design Tips for a New Peripheral**](#tips)<br>
   - [**Debug Your Peripheral with Iverilog**](#debug)<br>
   - [**How to Add a New Peripheral Driver Module**](#drv)<br>
 - [**How to Port Peripheral Control to a New FPGA Board**](#newboard)<br>
   - [**Clone an Existing FPGA Board**](#cloneboard)<br>
   - [**Create a New Pinout File**](#pinout)<br>
   - [**Create a New Board IO Peripheral**](#boardperi)<br>
   - [**Modify the Makefile**](#makefile)<br>

<br>
<br>

<span id="arch"></span>
# System  Architecture

A peripherals has two parts, an FPGA part and a driver part. The drivers
and APIs to them are described in the pcdaemon documentation. This
document describes the FPGA part of a peripheral.

The FPGA part of a peripheral is written in Verilog and contains the
timing and logic needed to drive the FPGA pins of the peripheral.
The host controls the peripheral via a set of 8-bit registers which
tie to the peripheral's Wishbone address and data bus. The **slot** of
a peripheral is actually the upper four bits of the 12-bit address block
assigned to each peripheral.

The example below is for an Axelsys MachXO2 development board.
Slot #0 always contains the **enumerator**, a list of the peripherals
in the build.  The daemon uses this list to determine which drivers to
load.  The slot #0 also contain the logic for any LEDs, buttons,
or other IO available on the FPGA board itself. 

<img src=docs/arch2.svg height=240 border=1><br>

The FPGA internal address and data bus tie to the host system though a serial
interface (often a USB-to-serial chip). Logic in the FPGA implements
a parser for command packets that come from the host over the serial link.
The command set consists of simple register reads and writes. No single
document describes the registers for all of the peripherals, however
most of the pcdaemon driver files have the register descriptions for
the peripheral it uses.  The protocol and design of the host interface
is described here: <br>
[protocol.md](docs/protocol.md). <br>
<br>
<br>

<span id="build"></span>
## How to Build the Peripheral Control Project
This section describes how build an FPGA binary image using your choice
of peripherals.  This section assumes you have one of the following
supported FPGA board.

<span id="boards"></span>
## Supported FPGA Boards
 \- Axelsys MachXO2 using Lattice Diamond ([Latticesemi](
    https://www.latticesemi.com/products/developmentboardsandkits/machxobreakoutboard))<br>
 \- Baseboard4 using Xilinx ISE  ([ebay](https://www.ebay.com/itm/295095094890))<br>
 \- Digilent Basys-3 using Xilinx Vivado ([digilent](
    https://digilent.com/shop/basys-3-artix-7-fpga-trainer-board-recommended-for-introductory-users/))<br>
 \- Gowin Runber ([Seeedstudio](
    https://www.seeedstudio.com/Gowin-RUNBER-Development-Board-p-4779.html))<br>
 \- STEP-MXO2 board using Lattice Diamond ([tindie](
    https://www.tindie.com/products/evoinmotion/fpga-development-board-step-mxo2/))<br>
 \- Tang Nano 4K using the Gowin tool chain  ([ebay](
    https://www.ebay.com/itm/325278731641))<br>

<img src=fpgaboards/axelxo2/MachXO2.png width=150> <img src=fpgaboards/baseboard4/bb4.jpg width=150> <img src=fpgaboards/basys3/Basys-3.png width=150> <img src=fpgaboards/runber/runber.png width=150> <img src=fpgaboards/stepxo2/stepxo2.jpg width=150> <img src=fpgaboards/tang4k/tang4k.png width=150>

<span id="toolchain"></span>
### Tool Chain Installation
 (in progress)

<span id="maketest"></span>
### Make, Download, and Test
 (in progress)

<br>
<br>

<span id="newperi"></span>
# How to Write a New Peripheral

This section describes how create new software defined peripherals
for the Peripheral Control project using the Verilog hardware
description language. To appreciate this document you should be
comfortable with digital design and with the Verilog hardware
description language.  You should also have one of the FPGA boards
mentioned above.

If you have never used Verilog before you might want to start with
a tutorial on how install Xilinx ISE and build an LED counter for
the Baseboard4.  The tutorial is available [here](docs/bb4devguide.md).

<br>

<span id="wish"></span>
## The Peripheral Control Wishbone Bus
A Wishbone Bus is a synchronous, parallel data bus intended to
connect on-chip peripherals to an on-chip CPU.  Wishbone
describes both the interface signals to the peripherals as well
as the how the peripherals are connected to each other and to
the CPU.  The full specification is available
[here](https://cdn.opencores.org/downloads/wbspec_b4.pdf).
Wishbone is a common interface for many of the project at
[Opencores](https://opencores.org).

In the case of pccore, the Wishbone bus does not connect to a
CPU but to a serial interface to a host computer.

<img src=docs/wb_p2p.gif height=240 border=1><br>

Wishbone supports different peripherals/CPU interconnect
topologies.  You may already be familiar with a *shared bus*
topology since early PCs used these as the ISA and PCI buses.  A
*crossbar* topology is often used when peripherals need to
communicate amongst themselves or with a DMA controller.  A
*point-to-point* topology is often used when the bandwidth
requirements of a peripheral would interfere with access to
other peripherals.  A *ring* topology is often used when speed
is less important than the amount of FPGA fabric used in the
system.  Pccore uses a ring topology.  Note that the topology
does not necessarily affect the address, data, and control lines
going to and from the peripheral.  The diagram above
shows the major Wishbone signals in a point-to-point topology.

Wishbone gives a general description of a peripheral bus.  For
example, Wishbone buses can be 8, 16, 32, or 64 bits wide.  It
is up the the implementer to decide things such as bus width, clock
frequencies, and which controls lines to use.  The Wishbone
specification lists and defines both required and optional bus
signals.

<img src=docs/wb_sdp_arch.png height=400 border=1><br>

The diagram above shows the topology for pccore.  It
shows two of the possible sixteen peripherals.  The pccore data
bus is 8 bits wide.  Each peripheral has 8 bits of internal
addressing.  That is, each peripheral can have up to 256 8-bit
registers.  You have previously seen that one advantage of
pccore is that you can have any mix of peripherals you want.  This
diagram illustrates why you can have any peripherals in any slot.
All peripherals have the same interface, so any peripheral can
be substituted for any other.


The paragraphs below describe the Wishbone bus as implemented
for pccore.  We use _X to indicate both input (_I) and output
(_O) signals.  Instead of the terms Master and Slave we use the
term Controller and Peripheral which better match our use of
Wishbone.  In our implementation when a peripheral is not
selected it must route DAT_I to DAT_O unchanged--.

Peripheral Signal Names :
CLK_I : System clock.  All peripherals use this 20 MHz clock to
drive state machines and other peripheral logic.  This is used
by the controller and all peripherals.

WE_I : Write enable.  This is set to indicate a register write
into the peripheral.  A zero for WE_I indicates a read operation.

STB_I : Strobe.  This is set to indicate that a bus cycle to
this peripheral is in progress.  The cycle can be either a
register read/write or a poll.

TGA_I : Address tag.  A bus cycle with TGA_I set is a normal
register read/write.  For a read bus cycle with TGA_I cleared,
the peripheral places the number of bytes it wishes to send to
the host on DAT_O.  A DAT_O value of zero indicates that the
peripheral has no data for the host at this time.  If DAT_O is
non-zero the controller internally generates a read request for
the number of bytes specified.

ADR_I : Address.  An 8 bit address that specifies which register
in the peripheral to read or write.  The peripheral can treat
some addresses as simple register reads/writes and other
addresses as top-of-stack for a FIFO.

STALL_O : Stalled.  The peripheral asserts this signal to
indicate that more system clock cycles are needed to complete
the bus cycle. The controller waits for STALL_O to be deasserted
before completing the read or write operation.

ACK_O : Acknowledge.  The peripheral asserts ACK_O to tell the
controller that the read or write bus cycle has successfully
completed.  This signal is used in FIFO accesses to indicate
that a FIFO is full (on write) or empty (on read).  The
controller write successive bytes to the same address to fill a
FIFO.  As long as the bytes are successfully written, the
peripheral asserts ACK_O.  When a byte can not be written, the
peripheral does not raise ACK and the controller knows that the
FIFO is full and the sequence of writes stops at that point.
The controller sends an acknowledgment to the host giving the
number of bytes written (or read).  This lets the host
application know how many bytes were successfully written to the
FIFO letting the application resend the unacknowledged bytes at
a later time.

DAT_X : An 8 bit data bus that is passed in ring from the bus
controller through all peripherals and back to the bus
controller.   This arrangement is close to the Wishbone Data
Flow Interconnection but the data path is a ring.  This
arrangement is sometime called a "serpentine" bus.
The "Port Size" is 8 bits and the "Granularity" is 8 bits.
There is no "Endianness" associated with the data bus.
During a bus write cycle the peripheral latches DAT_I into the
selected register. During a read bus cycle the peripheral ignore
DAT_I and places the requested data on DAT_O.

The Verilog code fragment below shows a typical peripheral
interface definition.  "Clocks" are system available strobes
that occur every 10.0ns, 100ns, 1.0us, 10us, 100us, 1.0ms, 10ms,
100ms, and 1 second.  The four inout pins go to the FPGA pins.  Some
peripherals have eight instead of four FPGA pins.

```
  module pc_peri(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
      input  CLK_I;            // system clock
      input  WE_I;             // direction. Read-from-peri==0; Write-to-peri==1
      input  TGA_I;            // ==1 for register read/write, ==0 for data-to-send poll
      input  STB_I;            // ==1 if peri is addressed for r/w or poll
      input  [7:0] ADR_I;      // address of target register
      output STALL_O;          // ==1 if we need more clk cycles to complete
      output ACK_O;            // ==1 if we claim the address and complete the read/write
      input  [7:0] DAT_I;      // Data INto the peripheral;
      output [7:0] DAT_O;      // Data OUTput from the peripheral, = DAT_I if not us.
      input  [8:0] clocks;     // 10ns to 1 second pulses synchronous CLK_I
      inout  [3:0] pins;       // FPGA pins for this peripheral
```

The pccore implementation of Wishbone is fairly bare-bones.
That is, it does not use some Wishbone signals including: RST_I,
TGD_I, TGD_O, CYC_I, ERR_O, LOCK_I, RTY_O, SEL_I, or TGC_I.

<br>

<span id="clone"></span>
## Clone an Existing Peripheral
It should be no surprise that the easiest way to build a new
peripheral is to base it on an existing one.  This section
shows you how to do this.  The example in this section is for
the Baseboard4 but the commands are similar for all of the
supported boards.

Start with a working system built from source. Download the
source code for pccore and build a binary image with the
following commands:
```
    XXXXXXX git clone ....
    wget https://demandperipherals.com/downloads/pccore-latest.tgz
    tar -xf pccore.tgz
    cd pccore/fpgaboards/baseboard4
    # Edit perilist to set all peripherals to your new one
    vi perilist
    make
    sudo cp build/pccore.bin /usr/local/lib

```
Expect several warnings about signals without loads.  This happens
because, depending on the peripherals selected, some wires  may be
defined but never used.  Now build the API daemon with the following
commands.
```
    XXXXXXX git clone ....
    wget https://demandperipherals.com/downloads/pcdaemon-latest.tgz
    tar -xf pcdaemon.tgz
    cd pcdaemon
    make
    sudo make install
    # start pcdaemon and test Baseboard LEDs
    # (use sudo for the following if not in dialout group)
    stty -opost  < /dev/ttyUSB0
    cat /usr/local/lib/pccore.bin > /dev/ttyUSB0
    sudo pcdaemon -efdv3 -s /dev/ttyUSB0
    pcset out4 outval 5
```

With everything built from source, you can now start adding your
own code.  Move to the pccore/peripherals directory and copy gpio4.v
to myperi.v, where you replace "myperi" with the name for your
new peripheral. Edit the file to change all references of "gpio4"
to "myperi".  Edit drivlist.h and clone the line for gpio4 so that
```
    {"gpio4", 22, "gpio4", 0xf, 4 }, becomes
    {"myperi", 22, "myperi", 0xf, 4 },
```
Replace the "22" in your myperi entry with a new peripheral ID.
This is usually one greater than the largest peripheral ID
already defined.  Move your entry to the bottom of the list to
keep the peripherals numerically ordered.

Edit fpgaboards/baseboard4/perilist and replace all of the
peripherals with your new peripheral name.  The promise of the
Peripherals Control project is "any peripheral in any slot",
which implies that no peripheral is allowed more than its fair
share of FPGA fabric.  That is why you should fill perilist with
your new peripheral.   Rebuild pccore.bin with a ''make'' and
again copy pccore.bin to /usr/local/lib.

Next is the myperi Linux shared object driver.  Move to the
pcdaemon/fpga-drivers directory and copy the gpio4 directory to
myperi.
```
    cd pcdaemon
    cp -r fpga-drivers/gpio4 fpga-drivers/myperi
```
Change the name of the driver file and change the target name in
the Makefile.
```
    mv fpga-drivers/myperi/gpio4.c fpga-drivers/myperi/myperi.c
    vi fpga-drivers/myperi/Makefile
```
While not strictly required, this is a good time to edit
myperi.c and change the name of the peripheral.  The line with
the peripheral name should now look something like:
```
    pslot->name = "myperi";
```
Edit the Makefile in fpga-drivers to add entries for make,
install, clean, and remove.
```
    vi fpga-drivers/Makefile
```
The peripherals IDs must be kept in synch between the Verilog
code and the daemon code.  This is currently a manual process so
copy the drivlist.h file you edited in the pccore steps above to
the pcdaemon/include directory.
```
    cp ../pccore/src/drivlist.h include
```

Build, install, and run pcdaemon as you did earlier.  Be sure to
kill any running instances of pcdaemon before starting a new
instance.  Use sudo to run pcdaemon or add yourself to the
dialout group.
```
    cd pcdaemon
    make
    sudo make install
    stty -opost  < /dev/ttyUSB0
    cat /usr/local/lib/pccore.bin > /dev/ttyUSB0
    sudo pcdaemon -efdv3 -s /dev/ttyUSB0
    dplist
```

If all has gone well the list of peripherals should now include
your new peripheral name.  This might a good time to do a backup.

<br>

<span id="tips"></span>
## Design Tips for a New Peripheral
This guide can not give you specific advice about your new
peripheral but we can give some tips for its design and coding.

Your Verilog design actually starts with the driver and its API.
Try to design the resources in the API to match how your view
of the peripheral at a high level.  Your design goal is to put
as much logic into the driver as possible so that the FPGA part
of the peripheral can be as small and as simple as possible.
Once you've got a view of what the driver and Verilog each do,
you can define the registers that link the driver to the FPGA
logic.  It is important to document the meaning, limits, and
suggested use of the registers at the top of your Verilog file.
This will help you maintain the code when you come back to it
months or years later.

The module declaration for most Peripheral Control peripherals
look the same.
```
    module myperi(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
        input  CLK_I;         // system clock
        input  WE_I;          // direction of this transfer.  Read=0; Write=1
        input  TGA_I;         // ==1 if reg access, ==0 if poll
        input  STB_I;         // ==1 if this peri is being addressed
        input  [7:0] ADR_I;   // address of target register
        output STALL_O;       // ==1 if we need more clk cycles to complete
        output ACK_O;         // ==1 if we claim the above address
        input  [7:0] DAT_I;   // Data IN to the peripheral;
        output [7:0] DAT_O;   // Data OUT from the peripheral, = DAT_I if not us.
        input  [8:0] clocks;  // Array of clock pulses from 10ns to 1 second
        inout  [3:0] pins;    // Lines out to FPGA pins
```

After the module declaration you'll want to add wires and
registers specific to your peripheral.  All pccore Wishbone
peripherals implement a Mealy-Moore state machine
(https://en.wikipedia.org/wiki/Moore_machine).  When you
write your Verilog be aware that you are implementing a state
machine.  The absolute best thing you can do for your future
self or others reading your code is to describe in some detail
the meaning of the registers you use and how they help implement
your state machine.  The design of your peripheral is all about
the state machine it implements.

Timers and timing are common in peripherals.  If your state
machine is partly based on timing you might expect code
something like the following:
```
    if ((mystate == `MYSTATE_A) && (clocks[`M10CLK]))
    begin
        if (polltmr == 0)
        begin
            mystate <= `MYSTATE_B;  // go to (describe next state)
            polltmr <= 'STB_TMR;    // init timer for state B
        end
        else
            polltmr <= polltmr - 4'h1;
        end
    end
    else if (mystate == 'MYSTATE_B)
    begin
        ......
```
Both ''case'' statements and ''if / else if'' constructs are
good for switching on state registers.

Outputs are often based on the state of the peripheral.  For
example, to get a 10 millisecond pulse on pins[0] at the end of
MYSTATE_A you would use Verilog something like:
```
    assign pin[0] = ((mystate == `MYSTATE_A) & (polltmr == 0));
```

**Auto Send**: The pccore bus controller continuously polls each
peripheral in turn to ask if the peripheral has data for the
host.  If the peripheral has data to send the bus controller
builds a read request request packet, performs the bus read
cycles, and sends the data to the host.  This feature is called
"auto send" and removes the need for an interrupt line to the
host.

The bus controller uses the Wishbone line TGA_I to select a
normal read/write cycle or a auto send poll.  The code below
shows how an internal flag, dataready, triggers an auto send
packet.
```
    assign DAT_O = (~myaddr) ? DAT_I :
                   (~TGA_I && myaddr && (dataready)) ? 8'h08 :
                   (TGA_I) ? {5'h00,rout} :
                   8'h00 ;
```
In the above code you can see that data out equals data in if
the peripheral is not selected, is rout if the peripheral is
selected for a normal bus cycle (TGA_I ==1),
and is equal to 8 if it is a poll bus cycle and there is data
ready for the host.  The "8" in the above code tell the bus
controller how many bytes to send to the host.  It might not be
obvious but the peripheral returns zero on a poll when it does
not have data ready for the host.  In an auto send the bus
controller reads consecutive registers starting at register
zero.  For the above example this would mean reading registers 0
through 7 in the auto send response.

<br>

<span id="debug"></span>
## Debug Your Peripheral with Iverilog
Having done it both ways, this author can attest to the fact
that it is **much** easier to debug a new peripheral using a
simulator.  This section gives sample code and a few tips for
debugging you peripheral using iverilog.

You may recall from the counter example in the Verilog tutorial
article that you can think of a test bench as a circuit board
onto which you plug your new peripheral.  Inputs to your
peripheral are outputs from the test bench.  As with all
Verilog, it is best to start with an explanation of how the
circuit works

``` 
    /////////////////////////////////////////////////////////////////
    // sr04_tb.v : Testbench for the sr04 peripheral with parallel trigger
    //
    //  Registers are
    //    Addr=0/1    Echo time of sensor 1 in microseconds
    //    Addr=2/3    Echo time of sensor 2 in microseconds
    //    Addr=4/5    Echo time of sensor 3 in microseconds
    //    Addr=6/7    Echo time of sensor 4 in microseconds
    //    Addr=8/9    Echo time of sensor 5 in microseconds
    //    Addr=10/11  Echo time of sensor 6 in microseconds
    //    Addr=12/13  Echo time of sensor 7 in microseconds
    //    Addr=14     Trigger interval in units of 10 ms, 0==off
    //
    //  The test procedure is as follows:
    //  - Set the trigger interval to 40ms
    //  - Raise all inputs after 500us
    //  - Lower inputs after 10,11,12,13,14,15, and 16 ms
    //  - Verify that data ready flag goes high
    //  - Read all 14 echo time registers and verify times
    `timescale 1ns/1ns
```

The test bench is self contained so it does not have
input/output lines.
```
    module sr04_tb;
```

As mentioned above, the inputs to your circuit are registered
outputs from the test bench and outputs from your circuit are
wires to the test bench.
```
    reg    CLK_I;            // system clock
    reg    WE_I;             // direction of this transfer.  Read=0; Write=1
    reg    TGA_I;            // ==1 if reg access, ==0 if poll
    reg    STB_I;            // ==1 if this peri is being addressed
    reg    [7:0] ADR_I;      // address of target register
    wire   STALL_O;          // ==1 if we need more clk cycles to complete
    wire   ACK_O;            // ==1 if we claim the above address
    reg    [7:0] DAT_I;      // Data INto the peripheral;
    wire   [7:0] DAT_O;      // Data OUT from the peripheral, = DAT_I if not us.
    reg    [8:0] clocks;     // Array of clock pulses from 10ns to 1 second
    wire   [7:0] pins;       // Pins to HC04 modules.  Strobe is LSB
    reg    [6:0] echo;       // echo inputs from the SR04 sensors
 
    // Add the device under test
    sr04 sr04_dut(CLK_I,WE_I,TGA_I,STB_I,ADR_I,STALL_O,ACK_O,DAT_I,DAT_O,clocks,pins);
```

The initialization for your test bench will be similar to the initialization
in the other testbench files.
```
    initial echo = 0;
    assign pins[7:1] = echo[6:0];

    // generate the clock(s)
    initial  CLK_I = 1;
    always   #25 CLK_I = ~CLK_I;
    initial  clocks = 8'h00;
    always   begin #50 clocks[`N100CLK] = 1;  #50 clocks[`N100CLK] = 0; end
    always   begin #950 clocks[`U1CLK] = 1;  #50 clocks[`U1CLK] = 0; end
    always   begin #9950 clocks[`U10CLK] = 1;  #50 clocks[`U10CLK] = 0; end
    always   begin #99950 clocks[`U100CLK] = 1;  #50 clocks[`U100CLK] = 0; end
    always   begin #999950 clocks[`M1CLK] = 1;  #50 clocks[`M1CLK] = 0; end
    always   begin #9999950 clocks[`M10CLK] = 1;  #50 clocks[`M10CLK] = 0; end
    always   begin #99999950 clocks[`M100CLK] = 1;  #50 clocks[`M100CLK] = 0; end
    always   begin #999999950 clocks[`S1CLK] = 1;  #50 clocks[`S1CLK] = 0; end
 
    // Test the device
    initial
    begin
        $display($time);
        $dumpfile ("sr04_tb.xt2");
        $dumpvars (0, sr04_tb);
```

Usually you will want to start with no activity on the bus.
```
        //  - Set bus lines and FPGA pins to idle state
        #50; WE_I = 0; TGA_I = 0; STB_I = 0; ADR_I = 0; DAT_I = 0;
```

Some time later you can start writing to the configuration
registers in your design.  You are addressing your registers as
long as STB_I and TGA_I are high so be sure to set them low
after writing to your configuration registers.
```
        #1000    // some time later
        //  - Set the sr04 trigger interval to 40ms
        #50; WE_I = 1; TGA_I = 1; STB_I = 1; ADR_I = 14; DAT_I = 4;
        #50; WE_I = 0; TGA_I = 0; STB_I = 0; ADR_I = 0; DAT_I = 0;
```

When debugging your circuit you might want to see not just what
the test bench is doing but see what your circuit is doing.  For
example, to see that the value when writing to the configuration
register you could add a display statement to the Verilog for
your peripherals.  For sr04 this might appear as:
```
        // Latch new trigger interval on write to reg 14.
        if (TGA_I & myaddr & WE_I & (ADR_I[3:0] == 14))
        begin
            rate <= DAT_I[3:0];  // get poll interval
            state <= `ST_WAIT;   // wait for next poll
            $display("New trigger rate is", DAT_I[3:0]);
        end
```
The $display statement in the above code is ignored when the
code is compiled for an FPGA.

If you are dealing inputs to the FPGA your test bench will have
to drive those inputs.  In the case of the sr04 the inputs are
set at particular intervals.
```
        //  - Wait 10.1 ms for start of sampling
        #10100000
 
        //  - Trigger is done, now raise echo inputs
        echo[6:0] = 7'h7f;            // all inputs high waiting for ping response
        //  - Lower inputs after 10,11,12,13,14,15, and 16 ms
        #10000000 echo[0] = 1'b0;
        #1000000  echo[1] = 1'b0;
        #1000000  echo[2] = 1'b0;
        #1000000  echo[3] = 1'b0;
        #1000000  echo[4] = 1'b0;
        #1000000  echo[5] = 1'b0;
        #1000000  echo[6] = 1'b0;
        $display("inputs done at t=", $time);
```

End your test bench as you did for the counter.
```
        $finish;
        end
    endmodule
```

Run iverilog and view the waveforms with gtkwave.
```
    iverilog -o sr04_tb.vvp ../sysdefs.h sr04_tb.v ../sr04.v
    vvp sr04_tb.vvp -lxt2
    gtkwave sr04_tb.xt2
```

The code in this section has been take in part from the sr04
test bench.  Hopefully you will not have too much difficulty
modifying it for your peripheral.

<br>


<span id="drv"></span>
## How to Add a New Peripheral Driver Module
The next step after adding and testing your Verilog peripheral
is to write a driver for it.  This section describes the common
features of the drivers and offers some tips that might simplify
your driver.

We use the term "driver" but do not confuse these with real Linux
kernel drivers.  Driver is the right concept but technically our
drivers are loadable plug-in modules implemented as shared-object
files.  Our existing drivers all use C but you can use any
language that can produce a shared-object file.  C, C++, and Rust
are all good choices.

The code structure of drivers is fairly consistent from one
driver to the next.  This make your documentation describing
your module all the more important.  Your file header block
should start with copyright and license information.  Since the
driver connects the pcset/pcget API to the registers you should
include a description of the API as if you were describing to
someone who had never seen it before.  This is where you answer
the reader's question of "what does it do?" Next describe the
registers and the meaning, if appropriate, of all of the bits in
the registers.  The final piece is a description of how the API
values relate to the register values.  The API-to-register
documentation will make your driver much easier to maintain when
you come back to it later.

Peripheral Control drivers are event driven and deal with three
events: creation, an API command from the user, and arrival of a
packet from the FPGA. These three events are handled by
Initialize(), which is executed when the module is attached to
the daemon, usercmd() which is a callback invoked for the API
commands pcset, pcget, and pccat, and packet_hdlr() which is a
callback that is executed when a packet arrives from the FPGA.



### Initialize()
To understand how to load a driver into pcdaemon you should,
perhaps, have some understanding of how pcdaemon works.

The core of pcdaemon is a list of slots.  Each slot has a SLOT
structure (include/daemon.h) which has the information needed to
manage the peripheral in that slot.  SLOT has the number of the
slot, the name of the shared object file, and an array of
resources (RSC in includes/daemon.h) for the peripheral.
//Resources//, you may recall, is the generic term given to the
attributes and data endpoints of the peripheral.

Peripheral #0 in the FPGA binary is the //enumerator//. This  is
just a copy of the perilist configuration file used to build the
FPGA binary.  When pcdaemon starts it loads the enumerator
driver and reads the list of peripherals in the FPGA. It then
loops through the list trying to load the shared object driver
for each peripheral.  When the driver is loaded pcdaemon looks
up and calls the Initialize() routine in the driver. (Look for
dlsym() in daemon/ui.c to see how this works.)  The goal of
Initialize() is to give pcdaemon (i.e. the SLOT structure)
everything it needs to manage the peripheral.  The enumerator is
usually overloaded with a board specific driver.  The board file
lets you access buttons, LEDs, or other features unique to the
board.

Pcdaemon can have multiple instances of the same peripheral.
This implies that an instance's internal state must be kept
separate from the internal state of all other instances.  To do
this you should create a structure or object that holds your
peripheral internal state.  For example, the gpio4 peripheral
keeps the following state information:
```
    // All state info for an instance of an gpio4
    typedef struct
    {
        void    *pslot;    // handle to peripheral's slot info
        int      pinval;   // value of the (output) pins
        int      dir;      // pin direction (in=0, out=1)
        int      intr;     // autosend on change (no=0, yes=1)
        void    *ptimer;   // timer to watch for dropped ACK packets
    } GPIO4DEV;
```

The Initialize() routine is passed a pointer to its allocated
SLOT structure (SLOT *pslot).
Allocate memory for your peripheral state information and attach
it to the SLOT structure with:
```
    MYPERIDEV *pctx;    // our local device context
 
    // Allocate memory for this peripheral
    pctx = (MYPERIDEV *) malloc(sizeof(MYPERIDEV));
    if (pctx == (MYPERIDEV *) 0) {
        // Malloc failure this early?
        pclog("memory allocation failure in myperi initialization");
        return (-1);
    }
    pslot->priv = pctx;
```

While not a hard requirement, generally the above is the only
time your driver should allocate memory.

```
    // Register this slot's packet callback (pcb).
    // Set its name, description and help text.
    (pslot->pcore)->pcb  = packet_hdlr;
    pslot->name = "myperi";
    pslot->desc = "Quad General Purpose Great Peripheral";
    pslot->help = README;
```

The help text is stored in the readme.txt file and is converted
to readme.h as part of the build process.  Be sure to give your
readme.txt file a high level description of the peripheral and a
detailed description of all of your peripherals resources.  You
can help your users a lot by including examples that can be
cut-and-pasted in a shell and will always work.

The Initialize() routine is where you set the name and
properties of your resources.  The pointer to the get/set
callback (pgscb) can be unique to each resource or can point to
one routine that handles all user API calls.  Over time we have
found that having one API callback is easier to understand and
maintain, especially for simple peripherals.  Your resource
definitions might appear something like this: 
```
    // Add the handlers for the user visible resources
    pslot->rsc[RSC_PINS].name = FN_PINS;
    pslot->rsc[RSC_PINS].flags = IS_READABLE | IS_WRITABLE | CAN_BROADCAST;
    pslot->rsc[RSC_PINS].bkey = 0;
    pslot->rsc[RSC_PINS].pgscb = usercmd;
    pslot->rsc[RSC_PINS].uilock = -1;
    pslot->rsc[RSC_PINS].slot = pslot;
    pslot->rsc[RSC_DIR].name = FN_DIR;
    pslot->rsc[RSC_DIR].flags = IS_READABLE | IS_WRITABLE;
    pslot->rsc[RSC_DIR].bkey = 0;
    pslot->rsc[RSC_DIR].pgscb = usercmd;
    pslot->rsc[RSC_DIR].uilock = -1;
    pslot->rsc[RSC_DIR].slot = pslot;
    pslot->rsc[RSC_INTR].name = FN_INTR;
    pslot->rsc[RSC_INTR].flags = IS_READABLE | IS_WRITABLE;
    pslot->rsc[RSC_INTR].bkey = 0;
    pslot->rsc[RSC_INTR].pgscb = usercmd;
    pslot->rsc[RSC_INTR].uilock = -1;
    pslot->rsc[RSC_INTR].slot = pslot;
```

### usercmd()
The usercmd() routine is where you convert your API calls to
read and write resources into packets of register reads and
writes.

The interface to pcdaemon is a TCP socket.  The daemon listens
on the socket and accepts connections from application programs.
 The application program sends lines of text in the form
    [pcset|pcget|pccat] [peri_name|slot_id] resource_name
[resource_values]
The daemon parses lines of input and rejects lines that do not
match the above format.  The daemon checks for a valid
peripheral name or slot ID, checks for a valid resource name,
and verifies that the command (get/set/cat) is appropriate for
the resource.  If everything is valid, the daemon calls your
get/set callback.

The daemon passes a lot of information into your callback,
including the command (PCGET, PCSET, or PCCAT), the resource
index you set in Initialize(), and the string of the new value,
There can be many instances of your peripheral, so the callback
includes a SLOT pointer from which you can the the instance's
private data structer.  Your response the the application that
issued the command should be a newline terminated line of ASCII
text.  The text goes into the 'buf' parameter and before
returning you set *plen to the number of characters you put in
buf.  You should be able to use the following exactly as it for
your usercmd() callback.
```
    static void usercmd(
        int      cmd,        //==PCGET if a read, ==PCSET on write
        int      rscid,      // ID of resource being accessed
        char    *val,        // new value for the resource
        SLOT    *pslot,      // pointer to slot info.
        int      cn,         // Index into UI table for requesting conn
        int     *plen,       // size of buf on input, #char in buf on output
        char    *buf)
    {
```

Usually the first thing to do is get the "local context" for
this instance of your peripheral.  Do this with:
```
    pctx = (MYPERIDEV *) pslot->priv;
```

Your code now needs to switch based on the resource and command.
A switch() statement works as does a string of if()/else if()
statement.  Use your preferred coding style.  Long or complex
calculations based on the user input might be moved to a
separate routine to keep usercmd() simple and readable.  Your
code might look something like the following:

```
    if ((cmd == PCGET) && (rcsid == RSC_MYRSC1)) {
        ret = snprintf(buf, *plen, "%1x\n", pctx->intr);
        *plen = ret;  // (errors are handled in calling routine)
        return;
    }
    else if ((cmd == PCSET) && (rcsid == RSC_MYRSC1)) {
        ret = sscanf(val, "%x", &newrsc1);
        if ((ret != 1) || (newrsc1 < 0) || (newrsc1 > 0xf)) {
            ret = snprintf(buf, *plen,  E_BDVAL, pslot->rsc[rscid].name);
            *plen = ret;
            return;
        }
        pctx->rsc1 = newrsc1;
        sendconfigtofpga(pctx, plen, buf);  // send rsc1 and rsc2 to FPGA
    }
    else if ((cmd == PCSET) && (rcsid == RSC_MYRSC2)) {
        // Do a long or complex calculation in another routine
        newrsc2 = getrsc2(val);
    }
    else if ((cmd == PCCAT) && (rcsid == RSC_MYRSC3)) {
    .....
    }
```

The above code shows how to respond to resource values that are
out of range or otherwise invalid.  This code hides sending the
packets to the FPGA.

### Sending Packets to the FPGA
The daemon and pccore communicate using a packet based protocol
which is defined in include/fpga.h.  You build a packet by
setting the command, specifying the slot number, the register
address, and the number of bytes in the data part of the packet.
Your code to build a packet might appear as follows:
```
    static void sendconfigtofpga(
        MYPERIDEV *pctx,   // This peripheral's context
        int     *plen,     // size of buf on input, #char in buf on output
        char    *buf)      // where to store user visible error messages
    {
        PC_PKT   pkt;      // send write and read cmds to the gpio4
        SLOT    *pslot;    // This peripheral's slot info
        CORE    *pmycore;  // FPGA peripheral info
        int      txret;    // ==0 if the packet went out OK
        int      ret;      // generic return value
 
        pslot = pctx->pslot;
        pmycore = pslot->pcore;
 
        // Write the values for the pins, direction, and interrupt mask
        // down to the card.
        pkt.cmd = PC_CMD_OP_WRITE | PC_CMD_AUTOINC;
        pkt.core = pmycore->core_id;
        pkt.reg = MYPERI_REG_RSC1;   // the first reg of the three
        pkt.data[0] = pctx->rsc1;
        pkt.data[1] = pctx->rsc2;
        pkt.data[2] = pctx->rsc3;
        pkt.count = 3;
        txret = pc_tx_pkt(pmycore, &pkt, 4 + pkt.count); // 4 header + data
```


Some peripherals use a FIFO as a data endpoint.  In this case
you would want to write all the bytes to one register.  Other
peripherals have a string of registers that should be written
sequentially.  This is referred to as "autoincrement" or "no
autoincrement".  Autoincrement can apply to both reading and
writing registers so the four possibilities for the command are:
```
    pkt.cmd = PC_CMD_OP_WRITE | PC_CMD_AUTOINC;
    pkt.cmd = PC_CMD_OP_WRITE | PC_CMD_NOAUTOINC;
    pkt.cmd = PC_CMD_OP_READ  | PC_CMD_AUTOINC;
    pkt.cmd = PC_CMD_OP_READ  | PC_CMD_NOAUTOINC;
```

The routine to send a packet to the FPGA is pc_tx_pkt().  You
give it the peripheral address, the packet to send, and the
total number of byte in the packet.  Pc_tx_pkt() returns a
success or failure indication.  You can use this to warn the
user or to schedule another attempt.  Generally, something is
seriously wrong if pci_tx_pkt() returns an error.


### Handling Packets from the FPGA
When you initialized your peripheral instance you specified a
packet receive callback.  Your callback should be able to handle
three types of packets from the FPGA.  The first is an
acknowledgement for a packet you sent.  Use this packet to stop
the timeout timers if you have one set.  Otherwise the
acknowledgement can be ignored.

The second kind of packet is a read response.  Validate the
packet and then read and format the packet data to send to the
application.  Data to the application must be formatted as an
ASCII string terminated by a newline.  When an application gives
a PC_GET command the daemon marks the TCP connection as waiting
for data from your peripheral.  You send data back to the
application using a call to send_ui().

The third kind of packet is an autosend packet.  Recall that the
FPGA does not have a interrupt line to the CPU and instead can
automatically send packets up to the host.  The autosend packet
is similar in structure to a read response packet.  The
difference is the high bit of the ''cmd'' byte.  In a read
response the bit is set and in an autosend packet the bit is
cleared.  Autosend data is most often used with resources that
support the PC_CAT command.  The publish subscribe system in
pcdaemon allows multiple TCP connections to subscribe to the
same resource.   The routine to publish autosend data is the
bcst_ui() routine.  Your code for read responses and autosend
data might look like:

```
    // If a read response from a user dpget command, send value to UI
    if ((pkt->cmd & PC_CMD_AUTO_MASK) != PC_CMD_AUTO_DATA) {
        pinlen = sprintf(pinstr, "%1x\n", (pkt->data[0] & 0x0f));
        send_ui(pinstr, pinlen, prsc->uilock);
        prompt(prsc->uilock);

        // Response sent so clear the lock
        prsc->uilock = -1;
        del_timer(pctx->ptimer);  //Got the response
        pctx->ptimer = 0;
        return;
    }

    // Process of elimination makes this an autosend packet.
    // Broadcast it if any UI are monitoring it.
    if (prsc->bkey != 0) {
        pinlen = sprintf(pinstr, "%1x\n", (pkt->data[0] & 0x0f));
        // bkey will return cleared if UIs are no longer monitoring us
        bcst_ui(pinstr, pinlen, &(prsc->bkey));
        return;
    }
```

You can see some of the internal working of the daemon in the
above code.  The uilock tied to a resource tells your driver
that it is in a state of waiting for a read response from the
FPGA.  The resource 'broadcast key', bkey, tells if any
applications have subscribed to the stream of data offered by
the resource.


### Non-FPGA Based Peripherals
If you have built an application using pcdaemon then you might
appreciate the clean, simple, publish-subscribe API that it
offers.  This section describes how you can use the pcdaemon and
its API for non-FPGA based peripherals.  Let's start with an
example of how it works.

Pcdaemon comes with several examples of non-FPGA peripherals.
The first one to test is the 'hello_world' demo.  Start pcdaemon
with any pccore binary you have available.  Then at a command
prompt enter:
```
    pcloadso hellodemo.so
    pclist
    pclist hellodemo
```
You should see the new peripheral listed in last slot.  The help
text displays the resources available to the peripheral.  Test
it with the commands:
```
    pcget hellodemo messagetext
    pcset hellodemo messagetext "Hello, again!"
    pcset hellodemo period 5
    pccat hellodemo message
```

The structure of non-FPGA based drivers is almost identical to
FPGA based ones.  You will still need the Initialize() and
usercmd() routines.  One difference is that non-FPGA based
peripherals do not need a packet handler.  However they may need
the ability to respond to data arriving from a file descriptor.
Working code for this is in the gamepad driver.  If you have as
device or socket that you want to use as a data source you can
add a callback for your file descriptor with a call to add_fd().
An example taken from the gamepad driver Initialize routine is
shown below:
```
    // Init our GAMEPAD structure
    pctx->pslot = pslot;       // this instance of the hello demo
    pctx->period = 0;          // default state update on event
    pctx->filter = 0;          // default is to report all controls
    pctx->indx = 0;            // no bytes in gamepad event structure yet
    (void) strncpy(pctx->device, DEFDEV, PATH_MAX);
    // now open and register the gamepad device
    pctx->gpfd = open(pctx->device, (O_RDONLY | O_NONBLOCK));
    if (pctx->gpfd != -1) {
        add_fd(pctx->gpfd,PC_READ, getevents, (void *) pctx);
    }
```

In the above case the callback getevents() is called when the
file descriptor is readable.  Callbacks are given the file
descriptor that generated the callback as well as the
transparent data pointer passed in when add_fd() is called.  In
the above example the transparent data is a pointer to the
GAMEPAD pctx structure.  The getevents() routine shows the
callback structure.
```
    static void getevents(
        int       fd_in,         // FD with data to read,
        void     *cb_data)       // callback date (==*GAMEPAD)
    {
```

You can think of pcdaemon as having two parts, the daemon part
and the FPGA part.  The FPGA part is actually started as if it
were a non-FPGA driver.  As mentioned above, pcdaemon loads the
driver for the "enumerator" peripheral and then the enumerator
driver loads drivers for the peripherals found in the list from
the FPGA.  You can easily make pcdaemon entirely ***non-FPGA***
based by a small change in main() of daemon/main.c.
```
    // Add drivers here to always have them when the program starts
    // The first loaded is in slot 0, the next in slot 1, ...
    (void) add_so("enumerator.so");   // slot 0
    //(void) add_so("tts.so");      // first available slot after FPGA slots
```


To better understand this you might want to comment our the
enumerator and add tts and gamepad to main.c and see how the
resulting system is all non-FPGA peripherals.

<br>
<br>

<span id="newboard"></span>
# How to Port Peripheral Control to a New FPGA Board
This section describes how to port the Peripheral Control project to a new
FPGA board. 

<span id="cloneboard"></span>
### Clone an Existing FPGA Board
  (in progress)

<span id="pinout"></span>
### Create a New Pinout File
  (in progress)

<span id="boardperi"></span>
### Create a New Board IO Peripheral
  (in progress)

<span id="make"></span>
### Modify the Makefile
  (in progress)

