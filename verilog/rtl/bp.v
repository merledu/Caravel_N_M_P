module gradient_computation(
    input wire clk,
    input wire rst,
    input wire [15:0] in, // input value
    input wire [15:0] derivative, // derivative of activation function
    output wire [15:0] out // output gradient
);

    reg [15:0] out_int;

    // Compute the gradient
    // This is a very simple example and will need to be modified based on your specific needs
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out_int <= 16'h0;
        end else begin
            out_int <= in * derivative;
        end
    end
    
    assign out = out_int;

endmodule

module back_prop(
    input wire clk,
    input wire rst,
    input wire [31:0] target, // target output
    input wire [31:0] out, // actual output
    output wire [31:0] mmu_adr_o,
    output wire [31:0] mmu_dat_o,
    input wire [31:0] mmu_dat_i,
    output wire mmu_we_o,
    output wire mmu_req_o,
    output wire [15:0] gradient_in,
    input wire [15:0] gradient_out,
    output wire [15:0] derivative
);

    localparam WEIGHTS_BASE_ADDRESS = 16'h0100; // Base address for the weights memory
    localparam BIASES_BASE_ADDRESS  = 16'h0200; // Base address for the biases memory


    reg [31:0] mmu_adr_o_int;
    reg [31:0] mmu_dat_o_int;
    reg        mmu_we_o_int;
    reg        mmu_req_o_int;
    reg [15:0] derivative_int;
    reg [15:0] gradient_in_int;

    reg [4:0] neuron_id;  // 5 bits can handle up to 32 neurons
    reg [1:0] layer_id;   // 2 bits can handle up to 4 layers

    always @(posedge clk) begin
        if (rst) begin
            neuron_id <= 5'b00000;
            layer_id <= 2'b00;
        end else begin
            if (layer_id == 2'b00) begin  // Input layer
                if (neuron_id == 2'b01) begin
                    neuron_id <= 5'b00000;
                    layer_id <= 2'b01;
                end else begin
                    neuron_id <= neuron_id + 1;
                end
            end else if (layer_id == 2'b01) begin  // First hidden layer
                if (neuron_id == 3'b100) begin
                    neuron_id <= 5'b00000;
                    layer_id <= 2'b10;
                end else begin
                    neuron_id <= neuron_id + 1;
                end
            end else if (layer_id == 2'b10) begin  // Second hidden layer
                if (neuron_id == 3'b100) begin
                    neuron_id <= 5'b00000;
                    layer_id <= 2'b11;
                end else begin
                    neuron_id <= neuron_id + 1;
                end
            end else if (layer_id == 2'b11) begin  // Output layer
                if (neuron_id == 2'b00) begin
                    neuron_id <= 5'b00000;
                    layer_id <= 2'b00;
                end else begin
                    neuron_id <= neuron_id + 1;
                end
            end
        end
    end

    // Learning rate
    reg [15:0] LEARNING_RATE = 16'h0A3D; // 0.001 in fixed-point format

    // State definitions
    localparam [3:0] 
        IDLE = 4'b0001, 
        READ_WEIGHTS = 4'b0010, 
        READ_BIASES = 4'b0011, 
        COMPUTE_GRADIENT = 4'b0100, 
        UPDATE_WEIGHTS = 4'b0101, 
        UPDATE_BIASES = 4'b0110;

    reg [3:0] state, next_state;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // State transitions
    always @* begin
        case (state)
            IDLE: next_state = READ_WEIGHTS;
            READ_WEIGHTS: next_state = READ_BIASES;
            READ_BIASES: next_state = COMPUTE_GRADIENT;
            COMPUTE_GRADIENT: next_state = UPDATE_WEIGHTS;
            UPDATE_WEIGHTS: next_state = UPDATE_BIASES;
            UPDATE_BIASES: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Instantiate gradient computation module
    gradient_computation gc (
        .clk(clk),
        .rst(rst),
        .in(out),
        .derivative(derivative),
        .out(gradient_out)
    );

    // Operations
    always @* begin
        case (state)
            READ_WEIGHTS: begin
                mmu_adr_o_int = WEIGHTS_BASE_ADDRESS + (neuron_id * 16); // Assuming 16-bit weights
                mmu_we_o_int = 0; // Read operation
                mmu_req_o_int = 1; // Valid request
            end
            READ_BIASES: begin
                mmu_adr_o_int = BIASES_BASE_ADDRESS + neuron_id; // Assuming 16-bit biases
                mmu_we_o_int = 0; // Read operation
                mmu_req_o_int = 1; // Valid request
            end
            COMPUTE_GRADIENT: begin
                // Compute gradient here
                gradient_in_int = mmu_dat_i; // Compute gradient based on received data
            end
            UPDATE_WEIGHTS: begin
                // Update weights here
                mmu_adr_o_int = WEIGHTS_BASE_ADDRESS + (neuron_id * 16);
                mmu_dat_o_int = mmu_dat_i - LEARNING_RATE * gradient_out; // Gradient descent
                mmu_we_o_int = 1; // Write operation
                mmu_req_o_int = 1; // Valid request
            end
            UPDATE_BIASES: begin
                // Update biases here
                mmu_adr_o_int = BIASES_BASE_ADDRESS + neuron_id;
                mmu_dat_o_int = mmu_dat_i - LEARNING_RATE * gradient_out; // Gradient descent
                mmu_we_o_int = 1; // Write operation
                mmu_req_o_int = 1; // Valid request
            end
            default: begin
                mmu_we_o_int = 0;
                mmu_req_o_int = 0;
            end
        endcase
    end

    assign mmu_adr_o = mmu_adr_o_int;
    assign mmu_dat_o = mmu_dat_o_int;
    assign mmu_we_o = mmu_we_o_int;
    assign mmu_req_o = mmu_req_o_int;
    assign derivative = derivative_int;
    assign gradient_in = gradient_in_int;
endmodule
