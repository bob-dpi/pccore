# *********************************************************
# Copyright (c) 2022 Demand Peripherals, Inc.
# 
# This file is licensed separately for private and commercial
# use.  See LICENSE.txt which should have accompanied this file
# for details.  If LICENSE.txt is not available please contact
# support@demandperipherals.com to receive a copy.
# 
# In general, you may use, modify, redistribute this code, and
# use any associated patent(s) as long as
# 1) the above copyright is included in all redistributions,
# 2) this notice is included in all source redistributions, and
# 3) this code or resulting binary is not sold as part of a
#    commercial product.  See LICENSE.txt for definitions.
# 
# DPI PROVIDES THE SOFTWARE "AS IS," WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING
# WITHOUT LIMITATION ANY WARRANTIES OR CONDITIONS OF TITLE,
# NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR
# PURPOSE.  YOU ARE SOLELY RESPONSIBLE FOR DETERMINING THE
# APPROPRIATENESS OF USING OR REDISTRIBUTING THE SOFTWARE (WHERE
# ALLOWED), AND ASSUME ANY RISKS ASSOCIATED WITH YOUR EXERCISE OF
# PERMISSIONS UNDER THIS AGREEMENT.
# 
# *********************************************************
VIVADO_PATH=/usr/local/vivado/

default: build/pccore.bit

build/main.v: perilist 
	# Link all the requested peripherals into on .v file
	mkdir -p build
	sed 's/^`/\#/' < brddefs.h > build/brddefs_c.h
	cp ../../peripherals/buildmain.c build
	gcc -o build/buildmain build/buildmain.c
	cat ../../peripherals/protomain                          >  build/main.v
	cd build && ./buildmain ../perilist                      >> main.v

build/sources.v: build/main.v
	# Put all source files into on include file 
	echo "\`include \"../brddefs.h\""                        >  build/sources.v
	echo "\`include \"../../../peripherals/sysdefs.h\""      >> build/sources.v
	echo "\`include \"main.v\""                              >> build/sources.v
	echo "\`include \"../basys3.v\""                         >> build/sources.v
	echo "\`include \"../../../peripherals/clocks.v\""       >> build/sources.v
	echo "\`define BAUD_DEFAULT \`BAUD460800"                >> build/sources.v
	echo "\`include \"../../../peripherals/hostserial.v\""   >> build/sources.v
	echo "\`include \"../../../peripherals/slip.v\""         >> build/sources.v
	echo "\`include \"../../../peripherals/crc.v\""          >> build/sources.v
	echo "\`include \"../../../peripherals/busif.v\""        >> build/sources.v
	cat build/sources.tmp | sort | uniq                      >> build/sources.v
	
build/pccore.bit: build/sources.v brddefs.h basys3.v basys3.xdc
	# Use Xilinx Vivado to compile the sources to a .bit file
	cd build && echo "\
		set design_name pccore ; \
		read_verilog { sources.v } ; \
		read_xdc ../basys3.xdc ; \
		synth_design -top pccore -part xc7a35tcpg236-1 ; \
		write_checkpoint -force pccore_post_synth.dcp ; \
		opt_design ; \
		place_design ; \
		write_checkpoint -force pccore_post_place.dcp ; \
		report_utilization -file post_place_util.txt ; \
		route_design ; \
		report_timing_summary -file post_route_timing.txt ; \
		write_checkpoint -force pccore_post_route.dcp ; \
		report_drc -file post_route_drc.txt ; \
		write_bitstream -force pccore.bit ; \
		quit  " | \
	$(VIVADO_PATH)/bin/vivado -mode tcl

install: build/pccore.bit
	openFPGALoader -b arty_a7_35t build/pccore.bit

flash: build/pccore.bit
	openFPGALoader -b arty_a7_35t --write-flash build/pccore.bit

clean:
	rm -rf build

