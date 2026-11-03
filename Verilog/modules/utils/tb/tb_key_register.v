`timescale 1ns / 1ps

module tb_key_register;
    reg clk = 0;
    always #10 clk = ~clk;
    reg rst = 1, load_key = 0;
    reg [11:0] keys_in = 0;
    wire [11:0] keys_out;
    integer value;
    key_register dut (.clk(clk), .rst(rst), .load_key(load_key),
                      .keys_in(keys_in), .keys_out(keys_out));
    task tick;
        begin @(posedge clk); #1; end
    endtask
    initial begin
        tick;
        if (keys_out !== 0) $fatal(1, "Reset do registrador");
        @(negedge clk); rst = 0;
        for (value = 0; value < 4096; value = value + 1) begin
            @(negedge clk); keys_in = value; load_key = 1;
            tick;
            if (keys_out !== value[11:0]) $fatal(1, "Carga %h", value);
            @(negedge clk); load_key = 0; keys_in = ~value;
            tick;
            if (keys_out !== value[11:0]) $fatal(1, "Retencao %h", value);
        end
        @(negedge clk); rst = 1; load_key = 1; keys_in = 12'hfff;
        #1;
        if (keys_out !== 12'hfff) $fatal(1, "Reset deve ser sincrono");
        tick;
        if (keys_out !== 0) $fatal(1, "Reset deve ter prioridade sobre carga");
        $display("PASS: tb_key_register (4096 cargas, retencao e prioridade do reset)");
        $finish;
    end
    initial begin #1000000; $fatal(1, "Timeout registrador"); end
endmodule
