module NNCU (
    input wire clk,
    input wire rst,
    input wire start,
    input wire [31:0] target, // target output for back_prop
    input wire do_backprop,
    input wire [15:0] top_address,
    input wire top_we,
    input wire [15:0] top_data_in,
    output wire [15:0] top_data_out,
    output wire done
);

    wire fp_mmu_ready, bp_mmu_req;
    wire [15:0] fp_mmu_data, bp_mmu_dat_i;
    wire fp_activate_ready;
    wire [15:0] fp_activate_out, bp_derivative;
    wire fp_mmu_we, bp_mmu_we;
    wire fp_mmu_valid;
    wire [15:0] fp_mmu_address, bp_mmu_adr_o;
    wire [15:0] fp_activate_in;
    wire [1:0] fp_activate_ctrl;

    forward_prop fp (
        .clk(clk),
        .rst(rst),
        .start(start),
        .mmu_ready(fp_mmu_ready),
        .mmu_data(fp_mmu_data),
        .activate_ready(fp_activate_ready),
        .activate_out(fp_activate_out),
        .mmu_we(fp_mmu_we),
        .mmu_valid(fp_mmu_valid),
        .mmu_address(fp_mmu_address),
        .activate_in(fp_activate_in),
        .activate_ctrl(fp_activate_ctrl),
        .done(done)
    );

    back_prop bp (
        .clk(clk),
        .rst(rst),
        .target(target),
        .out(fp_activate_out),
        .mmu_adr_o(bp_mmu_adr_o),
        .mmu_dat_o(bp_dat_o),
        .mmu_dat_i(bp_mmu_dat_i),
        .mmu_we_o(bp_mmu_we),
        .mmu_req_o(bp_mmu_req),
        .gradient_in(fp_activate_in),
        .gradient_out(fp_activate_out),
        .derivative(bp_derivative)
    );

    wire [15:0] mmu_address = fp_mmu_valid ? fp_mmu_address : (bp_mmu_req ? bp_mmu_adr_o : top_address);
    wire mmu_we = fp_mmu_valid ? fp_mmu_we : (bp_mmu_req ? bp_mmu_we : top_we);
    wire [15:0] mmu_data_in = fp_mmu_valid ? fp_activate_in : (bp_mmu_req ? bp_dat_o : top_data_in);

    assign fp_mmu_data = top_data_out;
    assign bp_mmu_dat_i = top_data_out;

    MMU mmu (
        .clk(clk),
        .rst(rst),
        .address(mmu_address),
        .we(mmu_we),
        .data_in(mmu_data_in),
        .data_out(top_data_out)
    );

    // Logic for interfacing with MMU...
    
endmodule
