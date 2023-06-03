module forward_prop (
    input wire clk,
    input wire rst,
    input wire start,
    input wire mmu_ready,
    input wire [15:0] mmu_data,
    input wire activate_ready,
    input wire [15:0] activate_out,
    output wire mmu_we,
    output wire mmu_valid,
    output wire [15:0] mmu_address,
    output wire [15:0] activate_in,
    output wire [1:0] activate_ctrl,
    output wire done
);

    // Base addresses for the neuron data, weights, and biases
    localparam neuron_data_base_address = 16'h0000;
    localparam weights_base_address = 16'h0100;
    localparam biases_base_address = 16'h0200;

    parameter IDLE = 3'b000;
    parameter READ_DATA = 3'b001;
    parameter READ_WEIGHTS = 3'b010;
    parameter READ_BIASES = 3'b011;
    parameter COMPUTE = 3'b100;

    // Define activation function type for each layer (Modify as needed)
    reg [1:0] layer_activation [0:3]; // 4 layers in the network

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Initialization of other variables...

            // Set initial activation functions for each layer
            layer_activation[0] <= 2'b00; // Sigmoid for layer 0
            layer_activation[1] <= 2'b01; // Tanh for layer 1
            layer_activation[2] <= 2'b10; // ReLU for layer 2
            layer_activation[3] <= 2'b00; // Sigmoid for layer 3
        end
    end


    reg [2:0] state;
    reg [2:0] next_state;

    reg [15:0] data_in, w, b, neuron_out; // Buffers for memory data
    reg [4:0] neuron_counter; // Counts neurons in a layer
    reg [1:0] layer_counter; // Counts layers in the network
    reg done_signal;

    // Intermediate registers
    reg [15:0] mmu_address_int;
    reg mmu_valid_int;
    reg mmu_we_int;
    reg [15:0] activate_in_int;
    reg [1:0] activate_ctrl_int;


    // Counters initialization
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            neuron_counter <= 5'b0;
            layer_counter <= 2'b0;
            done_signal <= 1'b0;
        end else if (state == COMPUTE && next_state == READ_DATA && neuron_counter == 5'b110) begin
            neuron_counter <= 5'b0;
            layer_counter <= layer_counter + 1'b1;
        end else if (state == COMPUTE && next_state == READ_DATA) begin
            neuron_counter <= neuron_counter + 1'b1;
        end else if (state == COMPUTE && next_state == IDLE) begin
            done_signal <= 1'b1;
        end
    end

    // State transition logic
    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next state logic
    always @* begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = READ_DATA;
            READ_DATA: next_state = READ_WEIGHTS;
            READ_WEIGHTS: next_state = READ_BIASES;
            READ_BIASES: next_state = COMPUTE;
            COMPUTE: next_state = (layer_counter == 2'b11 || (layer_counter != 2'b10 && neuron_counter == 5'b010)) ? IDLE : READ_DATA;
            default: next_state = IDLE;
        endcase
    end

    // State output logic
    always @(posedge clk) begin
        case (state)
            READ_DATA: // Send read request to MMU to read input neuron data
                begin
                    mmu_address_int <= neuron_data_base_address + (layer_counter << 4) + neuron_counter;
                    mmu_valid_int <= 1;
                    mmu_we_int <= 0;
                    if (mmu_ready)
                        data_in <= mmu_data;
                    if (mmu_ready)
                        state <= READ_WEIGHTS;
                end
            READ_WEIGHTS: // Send read requests to MMU to read weights
                begin
                    mmu_address_int <= weights_base_address + (layer_counter << 4) + neuron_counter;
                    mmu_we_int <= 0;
                    mmu_valid_int <= 1;
                    if (mmu_ready)
                        w <= mmu_data;
                    if (mmu_ready)
                        state <= READ_BIASES;
                end
            READ_BIASES: // Send read requests to MMU to read biases
                begin
                    mmu_address_int <= biases_base_address + neuron_counter;
                    mmu_we_int <= 0;
                    mmu_valid_int <= 1;
                    if (mmu_ready)
                        b <= mmu_data;
                    if (mmu_ready)
                        state <= COMPUTE;
                end
            COMPUTE: // Compute neuron output value
                begin
                    activate_in_int <= data_in * w + b;
                    activate_ctrl_int <= layer_activation[layer_counter];
                    mmu_valid_int <= 0;
                    if (activate_ready)
                        neuron_out <= activate_out;
                    if (activate_ready)
                        state <= IDLE;
                end
            default:;
        endcase
    end

    assign mmu_address = mmu_address_int;
    assign mmu_valid = mmu_valid_int;
    assign mmu_we = mmu_we_int;
    assign activate_in = activate_in_int;
    assign activate_ctrl = activate_ctrl_int;
    assign done = done_signal;

endmodule
