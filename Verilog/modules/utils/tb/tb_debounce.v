`timescale 1ns / 1ps

module tb_debouncer;
    reg clk = 0;
    always #10 clk = ~clk;
    reg rst_n = 0, button_in = 0;
    wire filtered, bypass;
    integer i;

    // Escala reduzida: limiar de cinco ciclos, mais sincronizacao.
    debouncer #(.CLK_FREQ(1000), .DEBOUNCE_TIME_MS(5)) dut
        (.clk(clk), .rst_n(rst_n), .button_in(button_in), .button_out(filtered));
    debouncer #(.CLK_FREQ(1000), .DEBOUNCE_TIME_MS(0)) zero_delay
        (.clk(clk), .rst_n(rst_n), .button_in(button_in), .button_out(bypass));

    task tick;
        begin @(posedge clk); #1; end
    endtask
    task drive;
        input value;
        begin @(negedge clk); button_in = value; end
    endtask
    task check;
        input expected;
        begin
            if (filtered !== expected)
                $fatal(1, "Debounce: esperado %b, recebido %b", expected, filtered);
        end
    endtask

    initial begin #10000; $fatal(1, "Timeout debounce"); end
    initial begin
        tick; check(0);
        @(negedge clk); rst_n = 1;
        repeat (4) begin
            drive(1);
            repeat (4) begin tick; check(0); end
            drive(0);
            repeat (5) begin tick; check(0); end
        end
        drive(1);
        for (i = 0; i < 7; i = i + 1) begin
            tick; check(0);
            if (i == 1 && bypass !== 0) $fatal(1, "Sincronizacao antecipada");
            if (i == 2 && bypass !== 1) $fatal(1, "Debounce zero: latencia incorreta");
        end
        tick; check(1);
        repeat (10) begin tick; check(1); end
        repeat (4) begin
            drive(0);
            repeat (4) begin tick; check(1); end
            drive(1);
            repeat (5) begin tick; check(1); end
        end
        drive(0);
        repeat (7) begin tick; check(1); end
        tick; check(0);
        drive(1);
        repeat (8) tick;
        check(1);
        // Reset ativo baixo e assincrono, fora da borda de clock.
        @(negedge clk); #2; rst_n = 0; #1;
        if (filtered !== 0 || bypass !== 0) $fatal(1, "Reset assincrono debounce");
        @(negedge clk); rst_n = 1; button_in = 0;
        repeat (10) begin tick; check(0); end
        $display("PASS: tb_debouncer (bounce, limiar, retencao, zero e reset)");
        $finish;
    end
endmodule
