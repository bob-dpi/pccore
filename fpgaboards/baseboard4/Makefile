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


DEVICE=xc3s100e-4-vq100
ISE_PATH=/usr/local/ISE/ISE_DS/ISE/bin/lin64


pccore.bin:
	mkdir -p build
	sed 's/^`/\#/' < brddefs.h > build/brddefs_c.h
	cp ../../peripherals/buildmain.c build
	gcc -o build/buildmain build/buildmain.c
	cat ../../peripherals/protomain                          >  build/main.v
	cd build && ./buildmain ../perilist                      >> main.v
	echo "\`include \"../brddefs.h\""                        >  build/sources.v
	echo "\`include \"../../../peripherals/sysdefs.h\""      >> build/sources.v
	echo "\`include \"main.v\""                              >> build/sources.v
	echo "\`include \"../bb4io.v\""                          >> build/sources.v
	echo "\`include \"../../../peripherals/clocks.v\""       >> build/sources.v
	echo "\`include \"../../../peripherals/hostparallel.v\"" >> build/sources.v
	echo "\`include \"../../../peripherals/slip.v\""         >> build/sources.v
	echo "\`include \"../../../peripherals/crc.v\""          >> build/sources.v
	echo "\`include \"../../../peripherals/busif.v\""        >> build/sources.v
	cat build/sources.tmp | sort | uniq                      >> build/sources.v
	cd build && echo "run -ifn sources.v -ifmt Verilog -ofn pccore \
		 -p $(DEVICE) -opt_mode Speed -opt_level 2" | $(ISE_PATH)/xst
	cd build && $(ISE_PATH)/ngdbuild -p $(DEVICE) -uc ../baseboard4.ucf -nt on \
		 -aul pccore.ngc pccore.ngd
	cd build && $(ISE_PATH)/map -p $(DEVICE) -w -logic_opt off -ol high -t 1 \
		-register_duplication off  -global_opt off -ir off -pr off \
		-power off -o pccore_map.ncd pccore.ngd pccore.pcf
	cd build && $(ISE_PATH)/par -w -ol high -mt off pccore_map.ncd pccore.ncd pccore.pcf
	cd build && $(ISE_PATH)/bitgen -w  -g CRC:Enable -g StartUpClk:CClk -g Compress \
		pccore.ncd pccore.bit pccore.pcf
	cd build && $(ISE_PATH)/promgen -w -p bin -o pccore.bin -u 0 pccore.bit

install: build/pccore.bin
	stty -opost  < /dev/ttyUSB0
	cat build/pccore.bin > /dev/ttyUSB0

clean:
	rm -rf build

