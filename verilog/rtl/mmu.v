module MMU (
    input wire clk,
    input wire rst,
    input wire [15:0] address,
    input wire we,
    input wire [15:0] data_in,
    output reg [15:0] data_out
);

    // Declare memories for data, weights, and biases
    reg [15:0] neuron_data_memory [0:5];
    reg [15:0] weights_memory [0:17];
    reg [15:0] biases_memory [0:6];

    // Memory management logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            data_out <= 16'h0;
        end else if (we) begin
            if (address < 16'h0100) begin
                neuron_data_memory[address[3:0]] <= data_in;
            end else if (address < 16'h0200) begin
                weights_memory[address[4:0]] <= data_in;
            end else begin
                biases_memory[address[2:0]] <= data_in;
            end
        end else begin
            if (address < 16'h0100) begin
                data_out <= neuron_data_memory[address[3:0]];
            end else if (address < 16'h0200) begin
                data_out <= weights_memory[address[4:0]];
            end else begin
                data_out <= biases_memory[address[2:0]];
            end
        end
    end

    reg _write_vcd = 0;
    initial
    begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, MMU, _write_vcd);
    while(1) begin
        #1; if (_write_vcd) $dumpflush;
    end
    end
endmodule
