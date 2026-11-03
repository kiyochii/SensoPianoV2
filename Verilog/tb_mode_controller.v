`timescale 1ns / 1ps

module tb_mode_controller;
    reg clk = 0;
    always #10 clk = ~clk;
    reg rst = 1, mode_sel = 0, start = 0, key_valid_pulse = 0;
    reg [11:0] keys_db = 0, keys_reg = 0;
    wire [11:0] leds_out, rgb_r, rgb_g, rgb_b;
    wire send_note, tone_enable, correct_pulse, wrong_pulse, done, session_start_pulse;
    wire [3:0] note_out, tone_note;
    wire [2:0] octave_out, tone_octave, state_dbg;
    integer i, correct_events = 0, wrong_events = 0, sent = 0, starts = 0;
    reg [6:0] song [0:5];
    mode_controller dut (.clk(clk), .rst(rst), .mode_sel(mode_sel), .start(start),
        .keys_db(keys_db), .keys_reg(keys_reg), .key_valid_pulse(key_valid_pulse),
        .leds_out(leds_out), .rgb_r(rgb_r), .rgb_g(rgb_g), .rgb_b(rgb_b),
        .send_note(send_note), .note_out(note_out), .octave_out(octave_out),
        .tone_enable(tone_enable), .tone_note(tone_note), .tone_octave(tone_octave),
        .correct_pulse(correct_pulse), .wrong_pulse(wrong_pulse), .done(done),
        .state_dbg(state_dbg), .session_start_pulse(session_start_pulse));
    always @(posedge clk) if (!rst) begin
        if (correct_pulse) correct_events = correct_events + 1;
        if (wrong_pulse) wrong_events = wrong_events + 1;
        if (send_note) sent = sent + 1;
        if (session_start_pulse) starts = starts + 1;
        if (correct_pulse && wrong_pulse) $fatal(1, "Resultados simultaneos");
    end
    task tick;
        begin @(posedge clk); #1; end
    endtask
    task stimulus;
        input [11:0] keys;
        input pulse;
        begin @(negedge clk); keys_db = keys; key_valid_pulse = pulse; tick; end
    endtask
    task expected_tone;
        input [6:0] full_note;
        reg [11:0] mask;
        begin
            mask = 12'b1 << full_note[3:0];
            if (leds_out !== mask || tone_enable !== 1 ||
                tone_note !== full_note[3:0] || tone_octave !== full_note[6:4])
                $fatal(1, "Nota esperada %02h: LEDs/tom incorretos", full_note);
            if (full_note[6:4] <= 5) begin
                if (rgb_r !== 0 || rgb_g !== mask || rgb_b !== 0) $fatal(1, "RGB medio");
            end else if (rgb_r !== 0 || rgb_g !== 0 || rgb_b !== mask) $fatal(1, "RGB agudo");
        end
    endtask
    initial begin
        song[0]=7'h30; song[1]=7'h42; song[2]=7'h54;
        song[3]=7'h61; song[4]=7'h54; song[5]=7'h65;
        tick;
        @(negedge clk); rst = 0;
        for (i=0; i<12; i=i+1) begin
            @(negedge clk); keys_db = 12'b1 << i; key_valid_pulse = 1; #1;
            if (leds_out !== keys_db || rgb_r !== keys_db || rgb_g !== keys_db ||
                rgb_b !== keys_db || !tone_enable || tone_note !== i[3:0] ||
                tone_octave !== 4 || !send_note || note_out !== i[3:0] || octave_out !== 4)
                $fatal(1, "Modo Livre: tecla %0d", i);
            tick;
            stimulus(0,0);
        end
        stimulus(12'h003,0);
        if (tone_enable || send_note) $fatal(1, "Acorde no modo Livre");
        stimulus(0,0);
        if (tone_enable) $fatal(1, "Silencio no modo Livre");
        @(negedge clk); mode_sel = 1; tick;
        if (state_dbg !== 1 || send_note || tone_enable) $fatal(1, "LEARN_IDLE");
        // Iniciar com tecla pressionada nao pode avaliar a tecla anterior.
        @(negedge clk); keys_db = 12'h200; start = 1; #1;
        if (!session_start_pulse) $fatal(1, "Pulso de inicio ausente");
        tick;
        if (state_dbg !== 2 || !send_note || {octave_out,note_out} !== song[0])
            $fatal(1, "Primeiro SHOW");
        @(negedge clk); start = 0; tick;
        stimulus(12'h200,1);
        if (state_dbg !== 3 || correct_pulse || wrong_pulse) $fatal(1, "Tecla anterior ao inicio");
        stimulus(0,0);
        stimulus(12'h200,1);
        if (state_dbg !== 4 || !wrong_pulse || correct_pulse) $fatal(1, "Tentativa errada");
        stimulus(12'h200,0);
        expected_tone(song[0]);
        repeat (3) stimulus(12'h200,1);
        if (state_dbg !== 3) $fatal(1, "Tecla mantida rearmou tentativa");
        stimulus(0,0);
        stimulus(12'h201,1);
        if (state_dbg !== 3) $fatal(1, "Acorde foi aceito");
        // A UC e responsavel por nao pulsar apos liberacao parcial do acorde.
        stimulus(0,0);
        for (i=0; i<6; i=i+1) begin
            expected_tone(song[i]);
            stimulus(12'b1 << song[i][3:0],1);
            if (state_dbg !== 4 || !correct_pulse || wrong_pulse) $fatal(1, "Acerto %0d", i);
            stimulus(12'b1 << song[i][3:0],0);
            if (i < 5) begin
                if (state_dbg !== 2 || !send_note || {octave_out,note_out} !== song[i+1])
                    $fatal(1, "Avanco da musica %0d", i);
                stimulus(0,0);
                stimulus(0,0);
            end
        end
        if (!done || tone_enable || leds_out !== 0 || rgb_r !== 0 || rgb_g !== 0 || rgb_b !== 0)
            $fatal(1, "Conclusao deve silenciar e apagar LEDs");
        repeat (5) stimulus(12'h001,1);
        if (!done || correct_events != 6 || wrong_events != 1 || sent != 18 || starts != 1)
            $fatal(1, "Eventos: acertos=%0d erros=%0d notas=%0d inicios=%0d",
                   correct_events, wrong_events, sent, starts);
        @(negedge clk); mode_sel = 0; key_valid_pulse = 0; keys_db = 0; tick;
        if (state_dbg !== 0 || done) $fatal(1, "Saida de DONE");
        @(negedge clk); mode_sel = 1; tick;
        @(negedge clk); start = 1; tick;
        @(negedge clk); start = 0; tick;
        expected_tone(song[0]);
        @(negedge clk); mode_sel = 0; tick;
        if (state_dbg !== 0 || tone_enable) $fatal(1, "Cancelar sessao");
        @(negedge clk); mode_sel = 1; tick;
        @(negedge clk); start = 1; tick;
        @(negedge clk); rst = 1; start = 0; mode_sel = 0; tick;
        if (state_dbg !== 0 || done || send_note || tone_enable) $fatal(1, "Reset durante sessao");
        $display("PASS: tb_mode_controller (12 teclas, LEDs/RGB, erros, seis notas e sessoes)");
        $finish;
    end
    initial begin #100000; $fatal(1, "Timeout controle de modo"); end
endmodule
