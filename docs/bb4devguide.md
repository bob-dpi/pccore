# Verilog Developer's Guide for the Baseboard4

## How to Get Started with Verilog

In this section you will see how to use Verilog to build FPGA
applications. The purpose of this section is to give non-Verilog users a
sense of how Verilog works. This section assumes you are already
familiar with digital circuit design.  The sample code below is for
the Demand Peripherals Baseboard4.  The ideas presented are useful
for almost all FPGA development boards. 

This section is broken into four topics:

  - "hello world" in Verilog
  - use iverilog to test your Verilog circuit
  - install the Xilinx compiler
  - compile your design and test it on the Baseboard
<br>
<br>

## "Hello World" in Verilog

Most programming languages have a sample application that prints the
phrase "Hello, World\!" to the console. This application is often used
to validate the installation of the language and its tool chain. For
microcontrollers and FPGAs the equivalent application usually flashes an
LED on the development board. The Verilog program below implements a
counter on the Baseboard LEDs. Save the following as counter.v

``` 
  // Simple up counter for the Baseboard.
  // Visible update rate is about 12 times per second
  
  module counter(CK12, LEDS);
      input   CK12;        // 12.5 MHz input clock
      output  [7:0] LEDS;  // eight LEDs on Baseboard
  
      reg [27:0] count;    // 28 bit counter
  
      initial
      begin
          count = 0;
      end
  
      always @(posedge CK12)
      begin
          count <= count + 28'b1;
      end
  
      assign LEDS = count[27:20];   // display high 8 bits of counter
  
  endmodule
```

Have you ever seen a circuit board with gold or copper fingers for the
connector? If so, you are already familiar with the idea of a *module*.
You can think of Verilog modules as a complete circuit boards with the
names of the connector pins given in the module definition. The *Top
Module* connects to the FPGA pins directly and it is to the top module
that the other modules connect.

Think of this counter module as a circuit board with nine signal pins on
its edge. In this case there is only one module, so the counter module
is the top module.

``` 
  module counter(CK12, LEDS);
      input   CK12;        // 12.5 MHz input clock
      output  [7:0] LEDS;  // eight LEDs on Baseboard
```

Clearly the code inside the module describes the digital circuitry on
our imaginary circuit board.

You already know that a register is just an array of flip-flops. In
Verilog you create a register using the *reg* keyword. You have to tell
the compiler how many flip-flops you want in the register by specifying
the upper and lower flip-flop numbers.

``` 
      reg [27:0] count;    // a 28 bit counter
```

You can tell the Verilog compiler what values to place in registers when
the FPGA is loaded. This is called the *initial* value of the register.
Do this with the initial construct.

``` 
      initial
      begin
          count = 0;
      end
```

Consider a flip-flop. It has an input and an output. In Verilog inputs
always appear on the left hand side of an assignment and outputs always
appear on the right hand side. While not obvious, this is true for the
following:

``` 
      always @(posedge CK12)
      begin
          count <= count + 28'b1;
      end
```

The left hand side is the input to the count register and the right hand
side is the output of count plus one. The output of an edge-triggered
flip-flop is given a value only on the edge of its input clock. Register
assignments must appear inside a block that defines the clock source for
the registers. That is what the `always @(posedge CK12)` line does.
Verilog uses a special syntax to show an edge-triggered flip-flop
assignment. That is the `<``=` syntax. This can only appear in a block
with a clock source. Some flip-flop schematic symbols use a tiny
triangle at the clock input. You can think of the `<` in `<``=` as that
clock symbol.

Assignment outside of a synchronous block is done with just an equal
sign. This is called a *continuous assignment* and is how you connect
one module to another and how you connect inputs and outputs. Continuous
assignments are also handy for giving a simple name to a complex piece
of logic. In the counter application the line

``` 
      assign LEDS = count[27:20];   // display high 8 bits of counter
```

sets the value of LEDS to the high eight bits of the counter. Just as
you should not drive a wire with two different output, so Verilog wants
just one output driving a wire or input. The following will generate a
Verilog compiler error.

``` 
  assign outputA = inputX;
  assign outputA = count + 1;
```

If you have enjoyed this introduction you may want to get more
information from one of the many books and on-line tutorials for
Verilog. The Wikipedia page is both simple and fairly complete
(<https://en.wikipedia.org/wiki/Verilog>). While the compiler can flag
many errors it can not identify logic errors in your design. The easiest
way to spot logic errors is to use a simulator that lets you look at
each signal in the circuit.

<br>
<br>

## Test Your Verilog Design Using Iverilog

The word "Verilog" is a combination of the words verification and logic.
It was originally a *hardware description language* intended as a
simulation tool to test and verify circuits. Only later was it used as
input for circuit systhesis. Most commercial Verilog compilers include a
simulation tool. In this section you will see how to use the open source
Icarius Verilog (<http://iverilog.icarus.com>) to simulate your counter.

The simulation environment for a circuit is called a *test bench*.
Recall how you were asked to think of a module as circuit board. Think
of a test bench as a motherboard that into which you plug your module.
This motherboard will have drive all the inputs on your *device under
test* and be able to change those inputs based on how many clock cycles
have passed. You can view all of the internal signals and the output
signals with the output of the simulation.

Install iverilog and gtkwave on a Debian system with the command:

``` 
  sudo apt-get install iverilog gtkwave
```

Save the following as counter\_tb.v

``` 
  //  iverilog test bench for the simple counter in counter.v
  
  `timescale 10ns/10ns
  
  module counter_tb;
      // direction is relative to the DUT
      reg    clk;          // 12.5 MHz system clock
      wire   [7:0] leds;   // LEDs on Baseboard
  
      // Add the device under test
      counter counter_dut(clk, leds);
  
      // generate the clock
      initial  clk = 0;
      always   #4 clk = ~clk;  // half period is 40ns == 4 * timescale
  
      initial
      begin
          $dumpfile ("counter_tb.xt2");
          $dumpvars (0, counter_tb);
  
          // 100 million steps of 10ns is one second
          #100000000
          $finish;
      end
  endmodule
```

Run the simulation, convert the output to a gtkwave format, and display
the results with the commands:

``` 
  iverilog -o counter_tb.vvp counter_tb.v counter.v
  vvp counter_tb.vvp -lxt2
  gtkwave counter_tb.xt2 
```

To view the LED waveforms click on "counter\_tb" and "counter\_dut" in
the top left gtkview pane. Then click on "LEDS" in the lower left pane.
Double click on "LEDS" in the display pane to expand the eight lines.
Hold down the CTRL key and use the mouse scroll wheel to compress the
display until the whole second of simulation is displayed. The display
should look something like this: ![](/usersguide/counter_leds.png)

<br>
<br>

## Install and Test the Xilinx Toolchain

Once your simulation output is correct you are ready to compile and
download your design to the FPGA. This section describes how to install
the Xilinx FPGA design tools, how to use the Xilinx command line tools
to compile a Verilog design, and how to download the compiled code to
the Baseboard. A later section will describe how to automate all these
steps in a Makefile.

The Baseboard uses a Xilinx Spartan-3E and a USB interface for both
downloads and a host interface. Since the Baseboard is downloaded
through a USB serial port you do not need a JTAG cable or dongle.

Xilinx provides a set of free design tools, ISE, which are part of their
WebPACK download. To get the WebPack download you have to select it,
register with Xilinx, and start the download.

Start by going to the Xilinx download site at:
<http://www.xilinx.com/support/download/index.htm>. Click on "ISE
Archive" link and select "14.7" and then "Full Installer for Linux".
This will take you to a login page where you can select "Create Account"
(since you probably don't already have a Xilinx account). You activate
the account using a token sent in email. Your first login will present a
page asking you to verify your name and address. The download starts
automatically after selecting Download at the bottom of the name
verification page.

Install the software by untarring the download file and running the
"xsetup" script in the top level directory. If installing as a non-root
user, you might want to create /opt/Xilinx/14.7 beforehand and give
yourself write permission on it. You should be able to install ISE in a
virtual machine but it might not install correctly in a docker image.

The installation will ask which products to install. We suggest the "ISE
WebPACK" as it is the smallest and has everything you'll need. You need
to "Acquire or Manage a License Key" but you do need to install the
Cable Drivers. Selecting Next then Install should start the
installation.

Once the installation is complete you can add the Xilinx Verilog
compiler toolchain to you path and verify that it can be found with the
commands:

``` 
  export PATH=$PATH:/opt/Xilinx/14.7/ISE_DS/ISE/bin/lin64
  which xst
```

By default, ise opens a graphical integrated development environment.
DPcore is *make* based and you do not need to learn the IDE. You may
recall that compiling a C++ or C program is broken into the steps of
preprocessing, compiler pass 1, compiler pass 2, assembly, and linking.
All these steps occur even though you only type g++ or gcc. In the same
way, Verilog is compiled to binary in several steps.

Before compiling your Verilog to an FPGA binary you need to tell the
compiler how the wires in the Verilog module map to the physical FPGA
pins. Xilinx uses a "user constraints file" (.ucf) for this. The minimum
UCF file for your counter is shown below. Save it as counter.ucf

``` 
  NET "CK12"      LOC = "P39"  ;    # 12.5 MHz clock
  NET "LEDS[0]"   LOC = "P70"  ;    # LED 0
  NET "LEDS[1]"   LOC = "P71"  ;    # LED 1
  NET "LEDS[2]"   LOC = "P62"  ;    # LED 2
  NET "LEDS[3]"   LOC = "P66"  ;    # LED 3
  NET "LEDS[4]"   LOC = "P67"  ;    # LED 4
  NET "LEDS[5]"   LOC = "P68"  ;    # LED 5
  NET "LEDS[6]"   LOC = "P63"  ;    # LED 6
  NET "LEDS[7]"   LOC = "P65"  ;    # LED 7
```

The commands that Xilinx uses to compile Verilog for a SPartan3 can be
hidden by a Makefile but you might be interested in the steps involved.
There is insufficient space in this tutorial to give detailed
descriptions of the commands. Your download of the Xilinx tools includes
comprehensive manuals for the Xilinx command line tools which you can
consult if you are interested. Look in ISE/doc/usenglish/books/docs/.
The following paragraphs give a brief overview of the commands involved.

The first command, xst, synthesizes the Verilog file into a hardware
design that is saved as a netlist file with an .ngc extension. Xilinx's
xst program is actually a command line interpreter and it expects input
from standard-in. Use an echo command and a pipe operator to give xst
input from standard-in if you want to keep all of your build information
in a Makefile.

``` 
  echo "run -ifn counter.v -ifmt Verilog -ofn counter.ngc -p xc3s100e-4-vq100" | xst
```

You have to specify the input file, the input file format, the name of
the output file and the exact type of FPGA. Xst generates several report
files and directories, but the real output is a netlist file with an
.ngc extension that is required for the next command. You can examine
the output files and reports to better understand the how the synthesis
works and an appendix in the xst manual describes the output files and
reports in detail.

The ngdbuild command further decomposes the design into FPGA native
elements such as flip-flops, gates, and RAM blocks.

``` 
  ngdbuild  -p xc3s100e-4-vq100 -uc counter.ucf  counter.ngc
```

It is the ngdbuild command that first considers the pin location,
loading, and timing requirements specified in the user constraints file,
counter.ucf. Like the other Xilinx commands, ngdbuild produces several
reports but its real output is a "Native Generic Database" stored in a
.ngd file.

The Xilinx map command converts the generic elements from the step above
to the elements specific to the target FPGA. It also performs a design
rules check on the overall design. The map command produces two files, a
Physical Constraints File file and a Native Circuit Description file,
that are used in subsequent commands.

``` 
  map -detail -pr b counter.ngd
```

The map command produces quite a few reports. As you gain experience
with FPGA design you may come to rely on these report to help identify
design and timing problems.

The place and route command (par) uses the Physical Constraints File and
the Native Circuit Description to produce another Native Circuit
Description file which contains the fully routed FPGA design.

``` 
  par counter.ncd parout.ncd counter.pcf
```

Output processing starts with the bitgen program which converts the
fully routed FPGA design into the pattern of configuration bits found in
the FPGA after download.

``` 
  bitgen -g StartUpClk:CClk -g CRC:Enable parout.ncd counter.bit counter.pcf
```

The bitgen program lets you specify which clock pin to use during
initialization and whether or not to generate a CRC checksum on the
download image. Files which contain a raw FPGA download pattern are
called bitstream files and traditionally has a .bit file extension.
Bitstream files are good for downloads using JTAG but since we're
downloading over a USB serial connection one more command is required to
convert the bitstream file into a download file.

``` 
  promgen -w -p bin -o counter.bin -u 0 counter.bit
```

The promgen program is a utility that converts bitstream files into
various PROM file formats. The format for the Baseboard is called bin so
the promgen command uses the -p bin option. The output of promgen,
counter.bin, is what you download to the Baseboard FPGA card.

All of the commands described above, including xst, ngdbuild, map, par,
bitgen, and promgen have excellent PDF manuals in either the
ISE/doc/usenglish/books/docs/xst directory or the
ISE/doc/usenglish/de/dev directory of your WebPACK installation.

``` 
  echo "run -ifn counter.v -ifmt Verilog -ofn counter.ngc -p xc3s100e-4-vq100" | xst
  ngdbuild  -p xc3s100e-4-vq100 -uc counter.ucf  counter.ngc
  map -detail -pr b counter.ngd
  par counter.ncd parout.ncd counter.pcf
  bitgen -g StartUpClk:CClk -g CRC:Enable parout.ncd counter.bit counter.pcf
  promgen -w -p bin -o counter.bin -u 0 counter.bit
```
<br>
<br>

## Download Your Design to the Baseboard

When the Baseboard powers up or after pressing the reset button the FPGA
waits for an binary image from the serial port. Linux serial port
drivers can suppress certain characters from an output stream. To
prevent this you need to turn off post processing on the serial
port.with the commands:

``` 
  sudo addgroup $LOGNAME dialout
  stty --file=/dev/ttyUSB0 -opost  # We want raw output
```

Press the reset button and send the FPGA binary to the Baseboard with
the command:

``` 
  cat counter.bin > /dev/ttyUSB0
```

If all has gone well you should see an up counter on the Baseboard LEDs.
