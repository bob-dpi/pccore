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

export DIAMOND=/usr/local/diamond/3.12
export FOUNDRY=$(DIAMOND)/ispfpga
export LD_LIBRARY_PATH=$(DIAMOND)/bin/lin64/:$(DIAMOND)/ispfpga/bin/lin:$(DIAMOND)/ispfpga/bin/lin64/
export LM_LICENSE_FILE=$(DIAMOND)/bin/lin64//../../license/license.dat
export PATH=$(DIAMOND)/bin/lin64/:$(DIAMOND)/ispfpga/bin/lin:/usr/bin

default: build/pccore.jed

src/main.v:
	# Diamond insists on a src directory in the build directory
	mkdir -p src
	cp -r ../../peripherals/* src
	cp  brddefs.h src
	cp  axo2.v src
	sed 's/^`/\#/' < brddefs.h > src/brddefs_c.h
	gcc -o src/buildmain src/buildmain.c
	cat src/protomain                                       >  src/main.v
	cd src && ./buildmain ../perilist                       >> main.v
	echo "\`include \"brddefs.h\""                          >  src/sources.v
	echo "\`include \"sysdefs.h\""                          >> src/sources.v
	echo "\`include \"main.v\""                             >> src/sources.v
	echo "\`include \"axo2.v\""                             >> src/sources.v
	echo "\`include \"clocks.v\""                           >> src/sources.v
	echo "\`include \"hostserial.v\""                       >> src/sources.v
	echo "\`include \"slip.v\""                             >> src/sources.v
	echo "\`include \"crc.v\""                              >> src/sources.v
	echo "\`include \"busif.v\""                            >> src/sources.v
	cat src/sources.tmp | sort | uniq | sed 's:../../../peripherals/::' >> src/sources.v
	cp src/sources.v src/includes.v

build/pccore.jed: src/main.v
	echo "prj_project open \"pccore.ldf\"; prj_run Export -forceAll" |\
	 $(DIAMOND)/bin/lin64/diamondc
	cd build && $(DIAMOND)/ispfpga/bin/lin64/bitgen \
	 -w -jedec pc_core.ncd pccore.jed

install: build/pccore.jed
	sudo /usr/local/bin/openFPGALoader build/pccore.jed

clean:
	rm -rf src build .recovery


# The following is a failed attempt at building from the command line.
# There are no errors but the resultant image does not respond to the host
#	mkdir -p build
#	cd ./build && $(DIAMOND)/ispfpga/bin/lin64/synthesis -a MachXO2 \
#	 -d LCMXO2-7000HE -s 4 -top pccore -optimization_goal balanced \
#	 -p ../src -ver sources.v -logfile pccore.syn.log -lpf 1 \
#	 -ngo pccore.ngo -t TQFP144
#	cd ./build && $(DIAMOND)/ispfpga/bin/lin64/ngdbuild -a MachXO2 \
#	 -d LCMXO2-7000HE pccore.ngo pccore.ngd
#	cd ./build && $(DIAMOND)/ispfpga/bin/lin64/map -a MachXO2 \
#	 -p LCMXO2-7000HE -s 5 -t TQFP144 pccore.ngd ../pccore.lpf \
#	 -o pccore.ncd -pr pccore.prf
#	cd ./build && $(DIAMOND)/ispfpga/bin/lin64/par \
#	 -w pccore.ncd pccore.ncd



