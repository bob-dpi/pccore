This directory is a stub for the FireAnt board that 
uses an Efinix FPGA.  The problem is that the Efinix
Verilog compiler does not recognize the 'z' state
for an output line.  That is, Efinix requires the
wiring of a external, explicit tri-state control for
all bidirectional input/output lines.  This is not
standard and the BRDIO array of lines requires that
some be inputs and some outputs, hence all are inout.


