module NPU_Top(
    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [15:0] io_in,
    output [15:0] io_out,
    output [15:0] io_oeb,

    // IRQ
    output [2:0] irq
);

    wire start = la_data_in[0] ? la_data_in[1] : io_in[0];
    wire do_backprop = la_data_in[0] ? la_data_in[2] : io_in[1];

    NNCU nncu (
        .clk(wb_clk_i),
        .rst(wb_rst_i),
        .start(start),
        .target(wbs_dat_i[31:0]), // Target from wishbone
        .do_backprop(do_backprop),
        .top_address(wbs_adr_i[15:0]),
        .top_we(wbs_we_i),
        .top_data_in(wbs_dat_i[15:0]),
        .top_data_out(wbs_dat_o[15:0]),
        .done(irq[0]) // You can also adjust this as per your requirement
    );

    assign wbs_ack_o = wbs_stb_i & wbs_cyc_i;
    assign la_data_out = 128'b0;
    assign io_out = 16'b0;
    assign io_oeb = 16'b0;
    assign irq[2:1] = 2'b0;

endmodule
