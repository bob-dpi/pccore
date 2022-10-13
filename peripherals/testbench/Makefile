# *********************************************************
# Copyright (c) 2021 Demand Peripherals, Inc.
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

# Makefile to run Verilog tests for some of the peripherals


default: mainbb4io_tb.xt2

all: 

mainbb4io_tb.xt2: ../boardperi.v ../main.v
	iverilog -o mainbb4io_tb.vvp ../brddefs.h ../sysdefs.h mainbb4io_tb.v ../main.v \
	../busif.v ../slip.v ../crc.v ../clocks.v ../hostserial.v ../boardperi.v ../in4.v ../out4.v
	vvp mainbb4io_tb.vvp -lxt2

mainspi_tb.xt2: mainspi_tb.v ../main.v ../busif.v ../crc.v ../slip.v ../dpespi.v \
		../clocks.v ../hostserial.v ../sysdefs.h 
	iverilog -o mainspi_tb.vvp  ../sysdefs.h mainspi_tb.v ../main.v ../busif.v \
		../slip.v ../crc.v ../dpespi.v ../clocks.v ../hostserial.v
	vvp mainspi_tb.vvp -lxt2

dpcore_tb.xt2: dpcore_tb.v ../dpcore.v
	iverilog -o dpcore_tb.vvp  dpcore_tb.v ../dpcore.v
	vvp dpcore_tb.vvp -lxt2

mainout4_tb.xt2: mainout4_tb.v ../main.v
	iverilog -o mainout4_tb.vvp ../sysdefs.h mainout4_tb.v ../main.v ../busif.v \
	../slip.v ../crc.v ../dpespi.v ../clocks.v ../hostserial.v ../out4.v ../in4.v
	vvp mainout4_tb.vvp -lxt2

mainin4_tb.xt2: mainin4_tb.v ../main.v
	iverilog -o mainin4_tb.vvp ../brddefs.h ../sysdefs.h mainin4_tb.v ../main.v \
	../busif.v ../slip.v ../crc.v ../clocks.v ../hostserial.v ../in4.v ../out4.v
	vvp mainin4_tb.vvp -lxt2

maindpespi_tb.xt2: maindpespi_tb.v ../main.v
	iverilog -o maindpespi_tb.vvp../sysdefs.h maindpespi_tb.v ../main.v ../busif.v \
	../slip.v ../crc.v ../dpespi.v ../clocks.v ../hostserial.v
	vvp maindpespi_tb.vvp -lxt2

clean:
	rm -rf *.vvp *.xt2


