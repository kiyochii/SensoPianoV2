// Adaptacao fisica para Terasic DE0-CV, clock de 50 MHz.
module sensopiano_de0_cv (
    input wire CLOCK_50,
    input wire [1:0] KEY,
    input wire SW0,
    input wire [11:0] piano_keys,
    output wire [9:0] LEDR,
    output wire [11:0] piano_leds_n,
    output wire [11:0] rgb_r_n,
    output wire [11:0] rgb_g_n,
    output wire [11:0] rgb_b_n,
    output wire esp_txd,
    output wire pc_txd,
    output wire audio_pwm
);
    // KEY0 ativo baixo; afirmacao assincrona, liberacao sincronizada.
    reg [1:0] reset_sync = 2'b11;
    always @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0]) reset_sync <= 2'b11;
        else reset_sync <= {reset_sync[0], 1'b0};
    end
    wire rst = reset_sync[1];
    reg [1:0] mode_sync;
    always @(posedge CLOCK_50) begin
        if (rst) mode_sync <= 2'b00;
        else mode_sync <= {mode_sync[0], SW0};
    end
    wire start;
    wire [11:0] filtered_keys;
    debouncer #(.DEBOUNCE_TIME_MS(10)) start_filter (
        .clk(CLOCK_50), .rst_n(~rst),
        .button_in(~KEY[1]), .button_out(start)
    );
    genvar i;
    generate for (i = 0; i < 12; i = i + 1) begin : key_filters
        debouncer #(.DEBOUNCE_TIME_MS(10)) key_filter (
            .clk(CLOCK_50), .rst_n(~rst),
            .button_in(piano_keys[i]), .button_out(filtered_keys[i])
        );
    end endgenerate
    // LEDs da DE0-CV sao ativos altos; os externos preservam o top original.
    assign LEDR = ~piano_leds_n[9:0];
    top core (
        .clk(CLOCK_50), .rst(rst), .keys_raw(filtered_keys),
        .mode_sel(mode_sync[1]), .start(start),
        .esp_txd(esp_txd), .pc_txd(pc_txd), .audio_pwm(audio_pwm),
        .leds_out(piano_leds_n),
        .rgb_r(rgb_r_n), .rgb_g(rgb_g_n), .rgb_b(rgb_b_n)
    );
endmodule
