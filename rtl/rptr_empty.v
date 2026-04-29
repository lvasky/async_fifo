// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

module rptr_empty

    #(
    parameter ADDRSIZE = 4
    )(
    input  wire                rclk,
    input  wire                rrst_n,
    input  wire                rinc,
    input  wire [ADDRSIZE  :0] rq2_wptr,
    output reg                 rempty,
    output reg                 arempty,
    output wire [ADDRSIZE-1:0] raddr,
    output reg  [ADDRSIZE  :0] rptr
    );

    reg  [ADDRSIZE:0] rbin;
    wire [ADDRSIZE:0] rgraynext, rbinnext, rgraynextm1;
    wire              arempty_val, rempty_val;

    //-------------------
    // GRAYSTYLE2 pointer
    //-------------------
    always @(posedge rclk or negedge rrst_n) begin

        if (!rrst_n)
            {rbin, rptr} <= 0;
        else
            {rbin, rptr} <= {rbinnext, rgraynext};

    end

    // Memory read-address pointer (okay to use binary to address memory)
    assign raddr     = rbin[ADDRSIZE-1:0];
    assign rbinnext  = rbin + ((rinc & ~rempty) ? 1 : 0);
    assign rgraynext = (rbinnext >> 1) ^ rbinnext;
    assign rgraynextm1 = ((rbinnext + 1'b1) >> 1) ^ (rbinnext + 1'b1);

    //---------------------------------------------------------------
    // FIFO empty when the next rptr == synchronized wptr or on reset
    //---------------------------------------------------------------
    assign rempty_val = (rgraynext == rq2_wptr);
    assign arempty_val = (rgraynextm1 == rq2_wptr);

    always @ (posedge rclk or negedge rrst_n) begin

        if (!rrst_n) begin
            arempty <= 1'b0;
            rempty <= 1'b1;
        end
        else begin
            arempty <= arempty_val;
            rempty <= rempty_val;
        end

    end

endmodule

module rptr_empty_fwft

    #(
    parameter ADDRSIZE = 4,
    parameter DATASIZE = 8
    )(
    input  wire                rclk,
    input  wire                rrst_n,
    input  wire                rinc,
    input  wire [ADDRSIZE  :0] rq2_wptr,
    input  wire [DATASIZE-1:0] ram_rdata,
    output reg                 rempty,
    output reg                 arempty,
    output reg  [DATASIZE-1:0] rdata,
    output wire                rclken,
    output wire [ADDRSIZE-1:0] raddr,
    output reg  [ADDRSIZE  :0] rptr
    );

    reg  [ADDRSIZE:0] rpop_bin;
    reg  [ADDRSIZE:0] rpre_bin;
    reg  [DATASIZE-1:0] skid_data;
    reg  [1:0]          data_count;
    reg                 read_pending;

    wire [ADDRSIZE:0] rpre_gray;
    wire [ADDRSIZE:0] rpre_binnext;
    wire [ADDRSIZE:0] rpre_graynext;
    wire [ADDRSIZE:0] rpop_binnext;
    wire [ADDRSIZE:0] rpop_graynext;
    wire              read_valid;
    wire              consume;
    wire              fetch;
    wire              data_arrive;
    wire [2:0]        space_used_next;
    wire [1:0]        count_after_consume;
    wire [1:0]        data_count_next;

    assign rpre_gray = (rpre_bin >> 1) ^ rpre_bin;
    assign read_valid = (rpre_gray != rq2_wptr);

    assign consume = rinc & (data_count != 0);
    assign data_arrive = read_pending;
    assign space_used_next = data_count + (read_pending ? 1'b1 : 1'b0) -
                             (consume ? 1'b1 : 1'b0);
    assign fetch = read_valid & (space_used_next < 2);
    assign rclken = fetch;
    assign raddr = rpre_bin[ADDRSIZE-1:0];

    assign rpre_binnext  = rpre_bin + (fetch ? 1'b1 : 1'b0);
    assign rpre_graynext = (rpre_binnext >> 1) ^ rpre_binnext;
    assign rpop_binnext  = rpop_bin + (consume ? 1'b1 : 1'b0);
    assign rpop_graynext = (rpop_binnext >> 1) ^ rpop_binnext;

    assign count_after_consume = data_count - (consume ? 1'b1 : 1'b0);
    assign data_count_next = count_after_consume + (data_arrive ? 1'b1 : 1'b0);

    always @(posedge rclk or negedge rrst_n) begin

        if (!rrst_n) begin
            rpop_bin     <= 0;
            rpre_bin     <= 0;
            rptr         <= 0;
            read_pending <= 1'b0;
        end
        else begin
            rpop_bin     <= rpop_binnext;
            rpre_bin     <= rpre_binnext;
            rptr         <= rpop_graynext;
            read_pending <= fetch;
        end

    end

    always @(posedge rclk or negedge rrst_n) begin

        if (!rrst_n) begin
            rdata      <= 0;
            skid_data  <= 0;
            data_count <= 0;
        end
        else begin
            if (consume && (data_count == 2))
                rdata <= skid_data;

            if (data_arrive) begin
                if (count_after_consume == 0)
                    rdata <= ram_rdata;
                else
                    skid_data <= ram_rdata;
            end

            data_count <= data_count_next;
        end

    end

    always @(posedge rclk or negedge rrst_n) begin

        if (!rrst_n) begin
            arempty <= 1'b0;
            rempty  <= 1'b1;
        end
        else begin
            arempty <= (data_count_next == 1) &&
                       (rpre_graynext == rq2_wptr) &&
                       !fetch;
            rempty  <= (data_count_next == 0);
        end

    end

endmodule

`resetall
