# pccore

This repository contains the Verilog FPGA-based peripherals
that are the core of the Peripheral Control project.

**QUICK INDEX:**<br>
 \- [**Overview and Architecture**](#arch)<br>
 \- [**How to Build an FPGA Image**](#build)<br>
 \- [**How to Write a New Peripheral**](#newperi)<br>

**List of Peripherals by Type**<br>
  \- **Motion Control**<br>
  \- \- [Dual DC Motor Control](#dc)<br>
  \- \- [Dual Quadrature Decoder](#quad)<br>
  \- \- [Bipolar Stepper Controller](#stepb)<br>
  \- \- [Unipolar Stepper Controller](#stepu)<br>
  \- \- [Quad Servo Controller](#servo)<br>
  \- **Simple Input/Output**<br>
  \- \- [Quad GPIO](#gpio)<br>
  \- \- [Quad Input](#in4)<br>
  \- \- [Quad Output](#out4)<br>
  \- \- [Quad PWM Out](#pwmout)<br>
  \- \- [Quad PWM In](#pwmin)<br>
  \- \- [Quad Counter](#count)<br>
  \- \- [Quad Serial Output](#serout)<br>
  \- \- [Dual Pulse Generator](#pulse)<br>
  \- \- [Generic SPI Input/Output](#spi)<br>
  \- \- [DPI 32 Channel Input](#in32)<br>
  \- \- [DPI 32 Channel Output](#out32)<br>
  \- \- [DPI Enhanced SPI](#espi)<br>
  \- \- [DPI Enhanced I2C](#ei2c)<br>
  \- \- [DPI Octal Input/Output](#io8)<br>
  \- **User Interface**<br>
  \- \- [Tone Generator](#tonegen)<br>
  \- \- [Quad WS2812 LED Controller](#ws2812)<br>
  \- \- [Eight Channel RC Decoder](#rcrx)<br>
  \- \- [Consumer IR Receiver/Transmitter](#irio)<br>
  \- \- [DPI Text Interface](#tif)<br>
  \- \- [DPI Rotary Encoder](#roten)<br>
  \- \- [DPI Six Digit Display](#lcd6)<br>
  \- **Sensor Interfaces**<br>
  \- \- [Octal SR04 Interface](#sr04)<br>
  \- \- [Octal Pololu QTR-RC Interface](#qtr8)<br>
  \- \- [Quad Pololu QTR-RC Interface](#qtr4)<br>
  \- \- [Quad Parallax PING))) Interface](#ping)<br>
  \- \- [DPI Octal ADC Interface](#adc)<br>
<br>
<br>

<span id="arch"></span> <span></span>
# **Overview and Architecture:**

A peripherals has two parts, an FPGA part and a driver part. The driver
and API to it are described in a separate document. The FPGA part of a
peripheral has the timing and logic needed to drive the FPGA pins out
to/from the hardware. The FPGA logic is controlled by a set of 8-bit
registers which tie to an internal address and data bus. The **slot** of
a peripheral is actually the upper four bits of the 12-bit address block
assigned to that peripheral.<br>

<img src=docs/arch2.svg width="99%" border=1><br>

The FPGA internal address and data bus tie to host system though a serial
interface (often using a USB-to-serial chip). Logic in the FPGA implements
a parser for commands that come from the host over the serial link. The
command set consists of simple register reads and writes. No single 
document describes the registers for all of the peripherals, however
most of the pcdaemon driver files have the register descriptions for
the peripheral it uses.  The protocol for the command set is described
here: <br>
XXXXX [protocol.html](/peripherals/protocol.html). <br>


The  peripherals have a *Wishbone* bus interface. The diagram below
shows the overall architecture of the bus system. Note that while the
peripherals are Wishbone compliant, the bus controller and system
interconnect is not.   The specification for this instance of a
Wishbone bus is [here](docs/WISHBONE_DATASHEET.html).  
![](docs/wb_pc_arch.svg)  

The host side of the bus controllers has the physical host interface
(pure serial or FTDI parallel), a SLIP encoder/decoder, and a CRC
generator/checker,  If you read the sources you may find the signal
naming can be a little confusing.  Hopefully the following diagram
will help you decipher it.
![](docs/pc_interconnect.svg)  


