`timescale 1ns / 1ps

module tb_audio_output;
    reg clk = 0;
    always #10 clk = ~clk;
    reg rst = 1, mode_sel = 0, start = 0;
    reg [11:0] keys_raw = 0;
    wire audio_pwm, mc_done;
    wire [11:0] leds_out, leds_out_reg, rgb_r, rgb_g, rgb_b;
    integer half_periods [0:11];
    reg [6:0] song [0:5];
    integer i, half_cycles;
    time edge_time;
    top dut (.clk(clk), .rst(rst), .keys_raw(keys_raw), .mode_sel(mode_sel),
        .start(start), .audio_pwm(audio_pwm), .mc_done(mc_done),
        .leds_out(leds_out), .leds_out_reg(leds_out_reg),
        .rgb_r(rgb_r), .rgb_g(rgb_g), .rgb_b(rgb_b));

    task check_period;
        input integer expected_cycles;
        begin
            // Medicao apenas pela porta publica, sem force ou acesso ao contador.
            @(posedge audio_pwm); edge_time = $time;
            @(negedge audio_pwm);
            if (($time - edge_time) != expected_cycles * 20)
                $fatal(1, "Semiperiodo alto: %0t, esperado %0d ciclos", $time-edge_time, expected_cycles);
            edge_time = $time;
            @(posedge audio_pwm);
            if (($time - edge_time) != expected_cycles * 20)
                $fatal(1, "Semiperiodo baixo: %0t, esperado %0d ciclos", $time-edge_time, expected_cycles);
        end
    endtask
    task quiet;
        begin
            repeat (20) begin
                @(negedge clk);
                if (audio_pwm !== 0) $fatal(1, "Audio deveria estar em silencio");
            end
        end
    endtask
    initial begin
        half_periods[0]=47778; half_periods[1]=45098; half_periods[2]=42567;
        half_periods[3]=40177; half_periods[4]=37922; half_periods[5]=35792;
        half_periods[6]=33784; half_periods[7]=31888; half_periods[8]=30101;
        half_periods[9]=28409; half_periods[10]=26814; half_periods[11]=25310;
        song[0]=7'h30; song[1]=7'h42; song[2]=7'h54;
        song[3]=7'h61; song[4]=7'h54; song[5]=7'h65;
        repeat (4) @(negedge clk); rst = 0;
        quiet;
        for (i=0; i<12; i=i+1) begin
            @(negedge clk); keys_raw = 12'b1 << i;
            repeat (10) @(negedge clk);
            if (leds_out !== ~keys_raw || leds_out_reg !== ~keys_raw ||
                rgb_r !== ~keys_raw || rgb_g !== ~keys_raw || rgb_b !== ~keys_raw)
                $fatal(1, "Polaridade ativa baixa da tecla %0d", i);
            check_period(half_periods[i]);
            @(negedge clk); keys_raw = 0;
            repeat (10) @(negedge clk);
            quiet;
        end
        @(negedge clk); keys_raw = 12'h003;
        repeat (10) @(negedge clk);
        quiet;
        @(negedge clk); keys_raw = 0; mode_sel = 1;
        repeat (10) @(negedge clk);
        quiet;
        start = 1;
        @(negedge clk); start = 0;
        for (i=0; i<6; i=i+1) begin
            repeat (10) @(negedge clk);
            half_cycles = half_periods[song[i][3:0]];
            case (song[i][6:4])
                3: half_cycles = half_cycles * 2;
                5: half_cycles = half_cycles / 2;
                6: half_cycles = half_cycles / 4;
            endcase
            check_period(half_cycles);
            @(negedge clk); keys_raw = 12'b1 << song[i][3:0];
            repeat (20) @(negedge clk);
            keys_raw = 0;
            repeat (20) @(negedge clk);
        end
        if (!mc_done) $fatal(1, "Conclusao da musica no teste de audio");
        quiet;
        // Reset interrompe um tom ativo.
        @(negedge clk); mode_sel = 0; keys_raw = 12'h001;
        repeat (10) @(negedge clk);
        @(posedge audio_pwm);
        @(negedge clk); rst = 1;
        @(negedge clk);
        quiet;
        $display("PASS: tb_audio_output (12 notas, oitavas 3/4/5/6, duty cycle, LEDs e silencio)");
        $finish;
    end
    initial begin #200000000; $fatal(1, "Timeout audio"); end
endmodule
