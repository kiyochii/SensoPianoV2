`timescale 1ns / 1ps

module tb_uc;
    reg clk = 0;
    always #10 clk = ~clk;
    reg rst = 1, key_any = 0, key_valid = 0, key_error = 0;
    wire load_key, key_valid_pulse;
    wire [1:0] state_dbg;
    UC dut (.clk(clk), .rst(rst), .key_any(key_any), .key_valid(key_valid),
        .key_error(key_error), .load_key(load_key),
        .key_valid_pulse(key_valid_pulse), .state_dbg(state_dbg));
    task step;
        input any_key, valid_key, error_key;
        input [1:0] expected_state;
        input expected_pulse;
        begin
            @(negedge clk);
            key_any = any_key; key_valid = valid_key; key_error = error_key;
            @(posedge clk); #1;
            if (state_dbg !== expected_state || load_key !== expected_pulse ||
                key_valid_pulse !== expected_pulse)
                $fatal(1, "UC: estado=%0d carga=%b pulso=%b", state_dbg, load_key, key_valid_pulse);
        end
    endtask
    initial begin
        step(0,0,0,0,0);
        @(negedge clk); rst = 0;
        repeat (3) step(0,0,0,0,0);
        repeat (12) begin
            step(1,1,0,1,1);
            repeat (5) step(1,1,0,2,0);
            step(0,0,0,0,0);
        end
        step(1,0,1,2,0);
        repeat (5) step(1,1,0,2,0);
        step(0,0,0,0,0);
        step(1,1,1,2,0); // prioridade do erro
        step(0,0,0,0,0);
        step(1,1,0,1,1);
        @(negedge clk); rst = 1;
        @(posedge clk); #1;
        if (state_dbg !== 0 || load_key !== 0 || key_valid_pulse !== 0)
            $fatal(1, "Reset durante REGISTER");
        @(negedge clk); rst = 0;
        step(1,0,1,2,0);
        @(negedge clk); rst = 1;
        @(posedge clk); #1;
        if (state_dbg !== 0 || key_valid_pulse !== 0) $fatal(1, "Reset durante WAIT_RELEASE");
        $display("PASS: tb_uc (pulso unico, tecla mantida, acorde, rearme e reset)");
        $finish;
    end
    initial begin #10000; $fatal(1, "Timeout UC"); end
endmodule
