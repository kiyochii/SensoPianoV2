`timescale 1ns / 1ps

module tb_uart_tx;
    reg clk = 0;
    always #10 clk = ~clk;
    reg rst = 1, valid = 0;
    reg [7:0] data = 0;
    reg [15:0] prescale = 1;
    wire ready, txd, busy;
    integer value, divisor, frames = 0;
    uart_tx dut (.clk(clk), .rst(rst), .s_axis_tdata(data), .s_axis_tvalid(valid),
        .s_axis_tready(ready), .txd(txd), .busy(busy), .prescale(prescale));

    task send_and_check;
        input [7:0] payload;
        integer cycle, bit_cycles, bit_index;
        reg expected;
        begin
            bit_cycles = prescale * 8;
            while (!ready) @(negedge clk);
            fork
                begin
                    @(negedge clk); data = payload; valid = 1;
                    @(posedge clk);
                    if (!ready) $fatal(1, "Ready ausente antes do byte");
                    @(negedge clk); valid = 0; data = ~payload;
                end
                begin
                    @(negedge txd); #1;
                    // Verifica cada ciclo do start, dos oito bits LSB-first e do stop.
                    for (cycle = 0; cycle < bit_cycles * 10; cycle = cycle + 1) begin
                        bit_index = cycle / bit_cycles;
                        if (bit_index == 0) expected = 0;
                        else if (bit_index == 9) expected = 1;
                        else expected = payload[bit_index-1];
                        if (txd !== expected || busy !== 1)
                            $fatal(1, "UART: divisor=%0d byte=%02h ciclo=%0d txd=%b esperado=%b busy=%b",
                                   prescale, payload, cycle, txd, expected, busy);
                        if (ready !== 0) $fatal(1, "Ready durante frame");
                        #20;
                    end
                end
            join
            while (busy) @(negedge clk);
            if (txd !== 1) $fatal(1, "Repouso UART");
            frames = frames + 1;
        end
    endtask
    initial begin
        repeat (3) @(negedge clk);
        if (txd !== 1 || busy !== 0 || ready !== 0) $fatal(1, "Reset UART");
        rst = 0;
        // Todos os bytes, com divisoes minima e seguinte, sem pausas artificiais.
        for (divisor = 1; divisor <= 2; divisor = divisor + 1) begin
            prescale = divisor;
            for (value = 0; value < 256; value = value + 1) send_and_check(value);
        end
        prescale = 54;
        send_and_check(8'h00); send_and_check(8'hff);
        send_and_check(8'h55); send_and_check(8'haa);
        prescale = 65535;
        send_and_check(8'ha5);
        prescale = 1;
        @(negedge clk); data = 8'h55; valid = 1;
        @(negedge clk); valid = 0;
        repeat (12) @(negedge clk);
        rst = 1;
        @(negedge clk);
        if (txd !== 1 || busy !== 0 || ready !== 0) $fatal(1, "Reset durante byte UART");
        rst = 0;
        send_and_check(8'h81);
        if (frames != 518) $fatal(1, "Contagem de frames UART");
        $display("PASS: tb_uart_tx (518 frames 8N1, divisores 1/2/54/65535 e reset)");
        $finish;
    end
    initial begin #200000000; $fatal(1, "Timeout UART TX"); end
endmodule
