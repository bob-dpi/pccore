`timescale 1ns/1ns

module dpram_tb;
    // direction is relative to the DUT
    reg    clk;        // system clock
    reg    we;         // write strobe
    reg    [5:0] wa;   // write address
    reg    [7:0] wd;   // write data
    reg    [4:0] ra;   // read address
    wire   [15:0]rd;   // read data

    // Add the device under test
    dpram dpram_dut(clk,we,wa,wd,ra,rd);

    // generate the clock(s)
    initial  clk = 0;
    always   #25 clk = ~clk;

    initial
    begin
        $dumpfile ("dpram_tb.xt2");
        $dumpvars (0, dpram_tb);

        #50   we = 0; wa = 0 ; wd = 5;
        #50   we = 1;
        #50   we = 0; wa = 1 ; wd = 6;
        #50   we = 1;
        #50   we = 0; wa = 2 ; wd = 7;
        #50   we = 1;

        #50   ra = 0;
        #50 $display("rd is %x", rd);
        #50   ra = 1;
        #50 $display("rd is %x", rd);
        #50   ra = 2;
        #50 $display("rd is %x", rd);

        #500  // some time later ...
        $finish;
    end
endmodule

