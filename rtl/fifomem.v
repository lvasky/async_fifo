// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

module fifomem

    #(
        parameter  DATASIZE = 8,    // Memory data word width
        parameter  ADDRSIZE = 4    // Number of mem address bits
    ) (
        input  wire                wclk,
        input  wire                wclken,
        input  wire [ADDRSIZE-1:0] waddr,
        input  wire [DATASIZE-1:0] wdata,
        input  wire                wfull,
        input  wire                rclk,
        input  wire                rclken,
        input  wire [ADDRSIZE-1:0] raddr,
        output wire [DATASIZE-1:0] rdata
    );

    localparam DEPTH = 1<<ADDRSIZE;

    (* ram_style = "block" *)
    reg [DATASIZE-1:0] mem [0:DEPTH-1];
    reg [DATASIZE-1:0] rdata_r;

    wire ena;
    wire wea;
    assign ena = 1'b1;
    assign wea = wclken && !wfull;
    always @(posedge wclk) begin
        if (ena) begin
            if (wea) mem[waddr] <= wdata;
        end
    end

    always @(posedge rclk) begin
        if (rclken) rdata_r <= mem[raddr];
    end

    assign rdata = rdata_r;

endmodule

`resetall
