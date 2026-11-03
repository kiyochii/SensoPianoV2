`timescale 1ns / 1ps

module tb_fd;
    reg clk = 0;
    always #10 clk = ~clk;
    reg rst = 1, load_key = 0;
    reg [11:0] keys_raw = 0;
    wire [11:0] keys_db, keys_reg;
    wire key_any, key_valid, key_error;
    integer value, bit_index, ones;
    fluxo_dados dut (.clk(clk), .rst(rst), .keys_raw(keys_raw), .load_key(load_key),
        .keys_db(keys_db), .keys_reg(keys_reg), .key_any(key_any),
        .key_valid(key_valid), .key_error(key_error));
    initial begin
        repeat (3) @(negedge clk);
        if ({keys_db, keys_reg, key_any, key_valid, key_error} !== 27'd0)
            $fatal(1, "Reset fluxo de dados");
        rst = 0;
        for (value = 0; value < 4096; value = value + 1) begin
            @(negedge clk); keys_raw = value;
            repeat (4) @(negedge clk);
            ones = 0;
            for (bit_index = 0; bit_index < 12; bit_index = bit_index + 1)
                if (value & (1 << bit_index)) ones = ones + 1;
            if (keys_db !== value[11:0] || key_any !== (ones != 0) ||
                key_valid !== (ones == 1) || key_error !== (ones > 1))
                $fatal(1, "Classificacao incorreta para %03h", value);
            if (keys_reg !== 0) $fatal(1, "Registro alterado sem carga");
        end
        keys_raw = 12'h800;
        repeat (4) @(negedge clk);
        load_key = 1;
        @(negedge clk); load_key = 0;
        if (keys_reg !== 12'h800) $fatal(1, "Carga integrada");
        keys_raw = 0;
        repeat (4) @(negedge clk);
        if (keys_reg !== 12'h800) $fatal(1, "Retencao integrada");
        rst = 1;
        @(negedge clk);
        if (keys_reg !== 0 || keys_db !== 0) $fatal(1, "Reset integrado");
        $display("PASS: tb_fd (4096 vetores: silencio, 12 teclas e 4083 acordes)");
        $finish;
    end
    initial begin #1000000; $fatal(1, "Timeout fluxo de dados"); end
endmodule
