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

export PATH=/usr/bin:/usr/local/gowin/IDE/bin

default: impl/pnr/pccore.fs

impl/main.v:
	# Gowin insists on "impl" for a build directory
	mkdir -p impl
	sed 's/^`/\#/' < brddefs.h > impl/brddefs_c.h
	cp ../../peripherals/buildmain.c impl
	gcc -o impl/buildmain impl/buildmain.c
	cat ../../peripherals/protomain                         >  impl/main.v
	cd impl && ./buildmain ../perilist                      >> main.v
	echo "\`include \"../brddefs.h\""                       >  impl/sources.v
	echo "\`include \"../../../peripherals/sysdefs.h\""     >> impl/sources.v
	echo "\`include \"impl/main.v\""                        >> impl/sources.v
	echo "\`include \"../tang4k.v\""                        >> impl/sources.v
	echo "\`include \"../../../peripherals/clocks.v\""      >> impl/sources.v
	echo "\`include \"../../../peripherals/hostserial.v\""  >> impl/sources.v
	echo "\`include \"../../../peripherals/slip.v\""        >> impl/sources.v
	echo "\`include \"../../../peripherals/crc.v\""         >> impl/sources.v
	echo "\`include \"../../../peripherals/busif.v\""       >> impl/sources.v
	cat impl/sources.tmp | sort | uniq                      >> impl/sources.v

impl/pnr/pccore.fs: impl/main.v
	echo "add_file -type verilog \"impl/sources.v\" ; \
	      add_file \"tang4k.cst\" ; \
	      set_device GW1NSR-LV4CQN48PC7/I6 -name GW1NSR-4C ; \
	      set_option -output_base_name pccore ; \
	      set_option -synthesis_tool gowinsynthesis ; \
	      set_option -top_module pccore ; \
	      set_option -verilog_std v2001 ; \
	      set_option -gen_text_timing_rpt 1 ; \
	      set_option -show_all_warn 1 ; \
	      set_option -use_sspi_as_gpio 1 ; \
	      set_option -use_mspi_as_gpio 1 ; \
	      set_option -use_ready_as_gpio 1 ; \
	      set_option -use_done_as_gpio 1 ; \
	      set_option -use_reconfign_as_gpio 1 ; \
	      set_option -use_i2c_as_gpio 1 ; \
	      run all" | gw_sh

install: impl/pnr/pccore.fs
	/usr/local/bin/openFPGALoader impl/pnr/pccore.fs
clean:
	rm -rf impl


