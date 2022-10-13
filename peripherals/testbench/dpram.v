//
// Dual-Port RAM with synchronous Read
//
module
dpram(clk,we,wa,wd,ra,rd);
    input    clk;                // system clock
    input    we;                 // write strobe
    input    [5:0] wa;           // write address
    input    [7:0] wd;           // write data
    input    [4:0] ra;           // read address
    output   [15:0] rd;           // read data

    reg      [15:0] rdreg;
    reg      [7:0] ram [63:0];

    always@(posedge clk)
    begin
        if (we)
            ram[wa] <= wd;
        rdreg[7:0] <= ram[(ra << 1) + 0];
        rdreg[15:8] <= ram[(ra << 1) + 1];
    end

    assign rd = rdreg;

endmodule

