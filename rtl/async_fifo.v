// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

module async_fifo

    #(
        parameter DSIZE = 8,
        parameter ASIZE = 4,
        parameter FALLTHROUGH = "TRUE" // First word fall-through using read-side prefetch
    )(
        input  wire             wclk,
        input  wire             wrst_n,
        input  wire             winc,
        input  wire [DSIZE-1:0] wdata,
        output wire             wfull,
        output wire             awfull,
        input  wire             rclk,
        input  wire             rrst_n,
        input  wire             rinc,
        output wire [DSIZE-1:0] rdata,
        output wire             rempty,
        output wire             arempty
    );

    wire [ASIZE-1:0] waddr, raddr;
    wire [ASIZE  :0] wptr, rptr, wq2_rptr, rq2_wptr;
    wire             rclken;
    wire [DSIZE-1:0] ram_rdata;

    // The module synchronizing the read point
    // from read to write domain
    sync_r2w
    #(ASIZE)
    sync_r2w (
    .wq2_rptr (wq2_rptr),
    .rptr     (rptr),
    .wclk     (wclk),
    .wrst_n   (wrst_n)
    );

    // The module synchronizing the write point
    // from write to read domain
    sync_w2r
    #(ASIZE)
    sync_w2r (
    .rq2_wptr (rq2_wptr),
    .wptr     (wptr),
    .rclk     (rclk),
    .rrst_n   (rrst_n)
    );

    // The module handling the write requests
    wptr_full
    #(ASIZE)
    wptr_full (
    .awfull   (awfull),
    .wfull    (wfull),
    .waddr    (waddr),
    .wptr     (wptr),
    .wq2_rptr (wq2_rptr),
    .winc     (winc),
    .wclk     (wclk),
    .wrst_n   (wrst_n)
    );

    // The DC-RAM
    fifomem
    #(DSIZE, ASIZE)
    fifomem (
    .rclken (rclken),
    .rclk   (rclk),
    .rdata  (ram_rdata),
    .wdata  (wdata),
    .waddr  (waddr),
    .raddr  (raddr),
    .wclken (winc),
    .wfull  (wfull),
    .wclk   (wclk)
    );

    generate
        if (FALLTHROUGH == "TRUE") begin : gen_fwft_reader

            // The FWFT reader prefetches from the synchronous RAM so rdata is
            // valid whenever rempty is low.
            rptr_empty_fwft
            #(ASIZE, DSIZE)
            rptr_empty (
            .arempty  (arempty),
            .rempty   (rempty),
            .ram_rdata (ram_rdata),
            .rdata    (rdata),
            .rclken   (rclken),
            .raddr    (raddr),
            .rptr     (rptr),
            .rq2_wptr (rq2_wptr),
            .rinc     (rinc),
            .rclk     (rclk),
            .rrst_n   (rrst_n)
            );

        end
        else begin : gen_registered_reader

            assign rclken = rinc & ~rempty;
            assign rdata = ram_rdata;

            // The module handling read requests
            rptr_empty
            #(ASIZE)
            rptr_empty (
            .arempty  (arempty),
            .rempty   (rempty),
            .raddr    (raddr),
            .rptr     (rptr),
            .rq2_wptr (rq2_wptr),
            .rinc     (rinc),
            .rclk     (rclk),
            .rrst_n   (rrst_n)
            );

        end
    endgenerate

endmodule

`resetall
