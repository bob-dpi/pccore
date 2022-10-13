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

export EFINITY_HOME=/usr/local/efinity/2021.2
export LD_LIBRARY_PATH=$(EFINITY_HOME)/lib
export EFXPT_HOME=$(EFINITY_HOME)/pt
# Disable Python user site support so we don't have package collisions
export PYTHONNOUSERSITE=1
export PYTHONPATH=$(EFINITY_HOME)/lib
#export PATH=/usr/bin:$(EFINITY_HOME)/bin:$(EFINITY_HOME)/scripts:$(EFINITY_HOME)/pt/bin:$(EFINITY_HOME)/pgm/bin

export PATH=/usr/local/efinity/2021.2/bin:/usr/local/efinity/2021.2/scripts:/usr/local/efinity/2021.2/pt/bin:/usr/local/efinity/2021.2/pgm/bin:/usr/local/efinity/2021.2/debugger/bin:/usr/local/efinity/2021.2/debugger/svf_player/bin:/usr/sbin:/usr/bin:/sbin:/bin

default: build/counter.hex

build/main.v:
	set > /tmp/x2
	# process perilist to get main.v is not implemented yet
	mkdir -p build
	#sed 's/^`/\#/' < brddefs.h > build/brddefs_c.h
	#cp ../../src/buildmain.c build
	#gcc -o build/buildmain build/buildmain.c
	#cat ../../src/protomain                                 >  build/main.v
	#cd build && ./buildmain ../perilist                     >> main.v
	#echo "\`include \"../brddefs.h\""                       >  build/sources.v
	#echo "\`include \"../../../src/sysdefs.h\""             >> build/sources.v
	#echo "\`include \"build/main.v\""                       >> build/sources.v
	#echo "\`include \"../fireant.v\""                       >> build/sources.v
	#echo "\`include \"../../../src/clocks.v\""              >> build/sources.v
	#echo "\`include \"../../../src/hostserial.v\""          >> build/sources.v
	#echo "\`include \"../../../src/slip.v\""                >> build/sources.v
	#echo "\`include \"../../../src/crc.v\""                 >> build/sources.v
	#echo "\`include \"../../../src/busif.v\""               >> build/sources.v
	#cat build/sources.tmp | sort | uniq                     >> build/sources.v
	touch build/main.v   # to pretend it is done

build/counter.hex: build/main.v
	$(EFINITY_HOME)/bin/efx_map \
	 --project "counter" \
	 --write-efx-verilog "build/outflow/counter.map.v" \
	 --write-premap-module "build/outflow/counter.elab.vdb" \
	 --binary-db "build/counter.vdb" \
	 --device "T8F81" \
	 --family "Trion" \
	 --mode "speed" \
	 --max_ram "-1" \
	 --max_mult "-1" \
	 --infer-clk-enable "3" \
	 --infer-sync-set-reset "1" \
	 --fanout-limit "0" \
	 --bram_output_regs_packing "1" \
	 --retiming "1" \
	 --seq_opt "1" \
	 --blast_const_operand_adders "1" \
	 --operator-sharing "0" \
	 --optimize-adder-tree "0" \
	 --mult_input_regs_packing "1" \
	 --mult_output_regs_packing "1" \
	 --veri_option "verilog_mode=verilog_2k,vhdl_mode=vhdl_2008" \
	 --work-dir "build/work_syn" \
	 --output-dir "build/outflow" \
	 --I "build" \
	 --v counter.v
	cp counter.peri.xml build
	echo "<efx:project name=\"counter\" "                                         >  build/counter.xml
	echo " xmlns:efx=\"http://www.efinixinc.com/enf_proj\""                       >> build/counter.xml
	echo "xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\""                >> build/counter.xml
	echo "xsi:schemaLocation=\"http://www.efinixinc.com/enf_proj enf_proj.xsd\">" >> build/counter.xml
	echo "</efx:project>"                                                         >> build/counter.xml
	cd build && python3  $(EFINITY_HOME)/scripts/efx_run_pt.py  "counter"  "Trion"  "T8F81"
	$(EFINITY_HOME)/bin/efx_pnr \
	 --circuit "counter" \
	 --family "Trion" \
	 --device "T8F81" \
	 --operating_conditions "C2" \
	 --pack \
	 --place \
	 --route \
	 --vdb_file "build/counter.vdb" \
	 --use_vdb_file "on" \
	 --place_file "build/outflow/counter.place" \
	 --route_file "build/outflow/counter.route" \
	 --sync_file "build/outflow/counter.interface.csv" \
	 --seed "1" \
	 --work_dir "build/work_pnr" \
	 --output_dir "build/outflow" \
	 --timing_analysis "on" \
	 --load_delay_matrix
	$(EFINITY_HOME)/bin/efx_pgm \
	 --source "build/work_pnr/counter.lbf" \
	 --dest "build/counter.hex" \
	 --device "T8F81" \
	 --family "Trion" \
	 --periph "build/outflow/counter.lpf" \
	 --enable_external_master_clock "off" \
	 --oscillator_clock_divider "DIV8" \
	 --active_capture_clk_edge "posedge" \
	 --spi_low_power_mode "on" \
	 --io_weak_pullup "on" \
	 --enable_roms "smart" \
	 --mode "active" \
	 --width "1" \
	 --release_tri_then_reset "on"

clean:
	rm -rf build


install: build/counter.hex
	python3 $(EFINITY_HOME)/pgm/bin/efx_pgm/ftdi_program.py \
	 --address 00000000 \
	 -m active \
	 -b 'Generic Board Profile Using FT232' \
	 build/counter.hex

