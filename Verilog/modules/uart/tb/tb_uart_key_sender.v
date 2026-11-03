`timescale 1ns / 1ps

module tb_uart_key_sender;
    reg clk = 0;
    always #10 clk = ~clk;
    reg rst = 1, send_pulse = 0, tx_tready = 0;
    reg [3:0] note_code = 0;
    reg [2:0] octave_code = 0;
    wire [7:0] tx_tdata;
    wire tx_tvalid;
    integer note, octave, transfers = 0;
    reg [7:0] expected;
    uart_key_sender dut (.clk(clk), .rst(rst), .send_pulse(send_pulse),
        .note_code(note_code), .octave_code(octave_code),
        .tx_tdata(tx_tdata), .tx_tvalid(tx_tvalid), .tx_tready(tx_tready));
    always @(posedge clk) if (!rst && tx_tvalid && tx_tready) begin
        if (tx_tdata !== expected) $fatal(1, "Byte de nota incorreto");
        transfers = transfers + 1;
    end
    task request;
        input [3:0] n;
        input [2:0] o;
        begin
            @(negedge clk); note_code = n; octave_code = o; send_pulse = 1;
            @(negedge clk); send_pulse = 0;
        end
    endtask
    task drain;
        begin
            @(negedge clk); tx_tready = 1;
            @(negedge clk); tx_tready = 0;
            if (tx_tvalid !== 0) $fatal(1, "Valid nao terminou no handshake");
            repeat (3) begin
                @(negedge clk);
                if (tx_tvalid !== 0) $fatal(1, "Byte duplicado");
            end
        end
    endtask
    initial begin
        repeat (3) @(negedge clk); rst = 0;
        for (octave = 0; octave < 8; octave = octave + 1)
            for (note = 0; note < 12; note = note + 1) begin
                expected = (octave << 4) | note;
                request(note, octave);
                repeat (4) begin
                    @(negedge clk);
                    // As entradas podem mudar enquanto o byte aguarda ready.
                    note_code = 15; octave_code = 7;
                    if (tx_tvalid !== 1 || tx_tdata !== expected)
                        $fatal(1, "Dados instaveis com transmissor ocupado");
                end
                // Sem fila: um segundo pulso pendente e descartado.
                request(15, 7);
                if (tx_tdata !== expected) $fatal(1, "Pulso ocupado sobrescreveu byte");
                drain;
            end
        if (transfers != 96) $fatal(1, "Esperadas 96 transferencias: %0d", transfers);
        request(3, 4);
        repeat (3) @(negedge clk);
        rst = 1;
        @(negedge clk);
        if (tx_tvalid !== 0 || tx_tdata !== 0) $fatal(1, "Reset de byte pendente");
        rst = 0;
        expected = 8'h65;
        request(5, 6);
        repeat (2) @(negedge clk);
        drain;
        if (transfers != 97) $fatal(1, "Recuperacao apos reset");
        $display("PASS: tb_uart_key_sender (96 notas/oitavas, backpressure, descarte e reset)");
        $finish;
    end
    initial begin #100000; $fatal(1, "Timeout emissor de notas"); end
endmodule
