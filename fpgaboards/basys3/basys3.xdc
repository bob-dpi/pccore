## This file is a modification of the  general .xdc for the Basys3 rev B
##  board which is supplied by Digilent

# Clock signal
set_property -dict {PACKAGE_PIN W5 IOSTANDARD LVCMOS33} [get_ports {BRDIO[0]}]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports {BRDIO[0]}]

# USB-RS232
set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 } [get_ports {BRDIO[1]}]; # tx
set_property -dict { PACKAGE_PIN B18 IOSTANDARD LVCMOS33 } [get_ports {BRDIO[2]}]; # rx
# LEDs
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {BRDIO[3]}]; # LED #0
set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports {BRDIO[4]}]
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports {BRDIO[5]}]
set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 } [get_ports {BRDIO[6]}]
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports {BRDIO[7]}]
set_property -dict { PACKAGE_PIN U15 IOSTANDARD LVCMOS33 } [get_ports {BRDIO[8]}]
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports {BRDIO[9]}]
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports {BRDIO[10]}]
set_property -dict { PACKAGE_PIN V13 IOSTANDARD LVCMOS33 } [get_ports {BRDIO[11]}]
set_property -dict { PACKAGE_PIN V3  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[12]}]
set_property -dict { PACKAGE_PIN W3  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[13]}]
set_property -dict { PACKAGE_PIN U3  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[14]}]
set_property -dict { PACKAGE_PIN P3  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[15]}]
set_property -dict { PACKAGE_PIN N3  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[16]}]
set_property -dict { PACKAGE_PIN P1  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[17]}]
set_property -dict { PACKAGE_PIN L1  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[18]}]; # LED #15
# Switches
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports {BRDIO[19]}]; # SW #0
set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports {BRDIO[20]}]
set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS33 } [get_ports {BRDIO[21]}]
set_property -dict { PACKAGE_PIN W17 IOSTANDARD LVCMOS33 } [get_ports {BRDIO[22]}]
set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS33 } [get_ports {BRDIO[23]}]
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports {BRDIO[24]}]
set_property -dict { PACKAGE_PIN W14 IOSTANDARD LVCMOS33 } [get_ports {BRDIO[25]}]
set_property -dict { PACKAGE_PIN W13 IOSTANDARD LVCMOS33 } [get_ports {BRDIO[26]}]
set_property -dict { PACKAGE_PIN V2  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[27]}]
set_property -dict { PACKAGE_PIN T3  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[28]}]
set_property -dict { PACKAGE_PIN T2  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[29]}]
set_property -dict { PACKAGE_PIN R3  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[30]}]
set_property -dict { PACKAGE_PIN W2  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[31]}]
set_property -dict { PACKAGE_PIN U1  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[32]}]
set_property -dict { PACKAGE_PIN T1  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[33]}]
set_property -dict { PACKAGE_PIN R2  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[34]}]
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports {BRDIO[35]}]; # btnC
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports {BRDIO[36]}]; # btnU
set_property -dict { PACKAGE_PIN W19 IOSTANDARD LVCMOS33 } [get_ports {BRDIO[37]}]; # btnL
set_property -dict { PACKAGE_PIN T17 IOSTANDARD LVCMOS33 } [get_ports {BRDIO[38]}]; # btnR
set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports {BRDIO[39]}]; # btnD = sw #20
set_property PULLDOWN true [get_ports {BRDIO[35]}]; # btnC
set_property PULLDOWN true [get_ports {BRDIO[36]}]; # btnU
set_property PULLDOWN true [get_ports {BRDIO[37]}]; # btnL
set_property PULLDOWN true [get_ports {BRDIO[38]}]; # btnR
set_property PULLDOWN true [get_ports {BRDIO[39]}]; # btnD = sw #20
# Seven Segment Displays 
set_property -dict { PACKAGE_PIN W7  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[40]}]; # segment a
set_property -dict { PACKAGE_PIN W6  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[41]}]
set_property -dict { PACKAGE_PIN U8  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[42]}]
set_property -dict { PACKAGE_PIN V8  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[43]}]
set_property -dict { PACKAGE_PIN U5  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[44]}]
set_property -dict { PACKAGE_PIN V5  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[45]}]
set_property -dict { PACKAGE_PIN U7  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[46]}]; # segment g
set_property -dict { PACKAGE_PIN V7  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[47]}]; # segment dp
set_property -dict { PACKAGE_PIN U2  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[48]}]; # digit left
set_property -dict { PACKAGE_PIN U4  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[49]}]
set_property -dict { PACKAGE_PIN V4  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[50]}]
set_property -dict { PACKAGE_PIN W4  IOSTANDARD LVCMOS33 } [get_ports {BRDIO[51]}]; # digit right


# Pmod Header JA
set_property -dict { PACKAGE_PIN J1  IOSTANDARD LVCMOS33 } [get_ports {PCPIN[0]}]; # Sch name = JA1
set_property -dict { PACKAGE_PIN L2  IOSTANDARD LVCMOS33 } [get_ports {PCPIN[1]}]; # Sch name = JA2
set_property -dict { PACKAGE_PIN J2  IOSTANDARD LVCMOS33 } [get_ports {PCPIN[2]}]; # Sch name = JA3
set_property -dict { PACKAGE_PIN G2  IOSTANDARD LVCMOS33 } [get_ports {PCPIN[3]}]; # Sch name = JA4
set_property -dict { PACKAGE_PIN H1  IOSTANDARD LVCMOS33 } [get_ports {PCPIN[4]}]; # Sch name = JA7
set_property -dict { PACKAGE_PIN K2  IOSTANDARD LVCMOS33 } [get_ports {PCPIN[5]}]; # Sch name = JA8
set_property -dict { PACKAGE_PIN H2  IOSTANDARD LVCMOS33 } [get_ports {PCPIN[6]}]; # Sch name = JA9
set_property -dict { PACKAGE_PIN G3  IOSTANDARD LVCMOS33 } [get_ports {PCPIN[7]}]; # Sch name = JA10
# Pmod Header JB
set_property -dict { PACKAGE_PIN A14 IOSTANDARD LVCMOS33 } [get_ports {PCPIN[8]}]; # Sch name = JB1
set_property -dict { PACKAGE_PIN A16 IOSTANDARD LVCMOS33 } [get_ports {PCPIN[9]}]; # Sch name = JB2
set_property -dict { PACKAGE_PIN B15 IOSTANDARD LVCMOS33 } [get_ports {PCPIN[10]}]; # Sch name = JB3
set_property -dict { PACKAGE_PIN B16 IOSTANDARD LVCMOS33 } [get_ports {PCPIN[11]}]; # Sch name = JB4
set_property -dict { PACKAGE_PIN A15 IOSTANDARD LVCMOS33 } [get_ports {PCPIN[12]}]; # Sch name = JB7
set_property -dict { PACKAGE_PIN A17 IOSTANDARD LVCMOS33 } [get_ports {PCPIN[13]}]; # Sch name = JB8
set_property -dict { PACKAGE_PIN C15 IOSTANDARD LVCMOS33 } [get_ports {PCPIN[14]}]; # Sch name = JB9
set_property -dict { PACKAGE_PIN C16 IOSTANDARD LVCMOS33 } [get_ports {PCPIN[15]}]; # Sch name = JB10
# Pmod Header JC
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports {PCPIN[16]}]; # Sch name = JC1
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports {PCPIN[17]}]; # Sch name = JC2
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports {PCPIN[18]}]; # Sch name = JC3
set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports {PCPIN[19]}]; # Sch name = JC4
set_property -dict { PACKAGE_PIN L17 IOSTANDARD LVCMOS33 } [get_ports {PCPIN[20]}]; # Sch name = JC7
set_property -dict { PACKAGE_PIN M19 IOSTANDARD LVCMOS33 } [get_ports {PCPIN[21]}]; # Sch name = JC8
set_property -dict { PACKAGE_PIN P17 IOSTANDARD LVCMOS33 } [get_ports {PCPIN[22]}]; # Sch name = JC9
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports {PCPIN[23]}]; # Sch name = JC10
# Pmod Header JXADC
set_property -dict { PACKAGE_PIN J3  IOSTANDARD LVCMOS33 } [get_ports {PCPIN[24]}]; # Sch name = XA1_P
set_property -dict { PACKAGE_PIN L3  IOSTANDARD LVCMOS33 } [get_ports {PCPIN[25]}]; # Sch name = XA2_P
set_property -dict { PACKAGE_PIN M2  IOSTANDARD LVCMOS33 } [get_ports {PCPIN[26]}]; # Sch name = XA3_P
set_property -dict { PACKAGE_PIN N2  IOSTANDARD LVCMOS33 } [get_ports {PCPIN[27]}]; # Sch name = XA4_P
set_property -dict { PACKAGE_PIN K3  IOSTANDARD LVCMOS33 } [get_ports {PCPIN[28]}]; # Sch name = XA1_N
set_property -dict { PACKAGE_PIN M3  IOSTANDARD LVCMOS33 } [get_ports {PCPIN[29]}]; # Sch name = XA2_N
set_property -dict { PACKAGE_PIN M1  IOSTANDARD LVCMOS33 } [get_ports {PCPIN[30]}]; # Sch name = XA3_N
set_property -dict { PACKAGE_PIN N1  IOSTANDARD LVCMOS33 } [get_ports {PCPIN[31]}]; # Sch name = XA4_N


## Configuration options, can be used for all designs
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]


##VGA Connector
#set_property -dict { PACKAGE_PIN G19   IOSTANDARD LVCMOS33 } [get_ports {vgaRed[0]}]
#set_property -dict { PACKAGE_PIN H19   IOSTANDARD LVCMOS33 } [get_ports {vgaRed[1]}]
#set_property -dict { PACKAGE_PIN J19   IOSTANDARD LVCMOS33 } [get_ports {vgaRed[2]}]
#set_property -dict { PACKAGE_PIN N19   IOSTANDARD LVCMOS33 } [get_ports {vgaRed[3]}]
#set_property -dict { PACKAGE_PIN N18   IOSTANDARD LVCMOS33 } [get_ports {vgaBlue[0]}]
#set_property -dict { PACKAGE_PIN L18   IOSTANDARD LVCMOS33 } [get_ports {vgaBlue[1]}]
#set_property -dict { PACKAGE_PIN K18   IOSTANDARD LVCMOS33 } [get_ports {vgaBlue[2]}]
#set_property -dict { PACKAGE_PIN J18   IOSTANDARD LVCMOS33 } [get_ports {vgaBlue[3]}]
#set_property -dict { PACKAGE_PIN J17   IOSTANDARD LVCMOS33 } [get_ports {vgaGreen[0]}]
#set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports {vgaGreen[1]}]
#set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS33 } [get_ports {vgaGreen[2]}]
#set_property -dict { PACKAGE_PIN D17   IOSTANDARD LVCMOS33 } [get_ports {vgaGreen[3]}]
#set_property -dict { PACKAGE_PIN P19   IOSTANDARD LVCMOS33 } [get_ports Hsync]
#set_property -dict { PACKAGE_PIN R19   IOSTANDARD LVCMOS33 } [get_ports Vsync]



##USB HID (PS/2)
#set_property -dict { PACKAGE_PIN C17   IOSTANDARD LVCMOS33   PULLUP true } [get_ports PS2Clk]
#set_property -dict { PACKAGE_PIN B17   IOSTANDARD LVCMOS33   PULLUP true } [get_ports PS2Data]


##Quad SPI Flash
##Note that CCLK_0 cannot be placed in 7 series devices. You can access it using the
##STARTUPE2 primitive.
#set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports {QspiDB[0]}]
#set_property -dict { PACKAGE_PIN D19   IOSTANDARD LVCMOS33 } [get_ports {QspiDB[1]}]
#set_property -dict { PACKAGE_PIN G18   IOSTANDARD LVCMOS33 } [get_ports {QspiDB[2]}]
#set_property -dict { PACKAGE_PIN F18   IOSTANDARD LVCMOS33 } [get_ports {QspiDB[3]}]
#set_property -dict { PACKAGE_PIN K19   IOSTANDARD LVCMOS33 } [get_ports QspiCSn]



