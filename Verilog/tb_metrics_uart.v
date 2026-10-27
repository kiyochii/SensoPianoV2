`timescale 1ns / 1ps

// Monitor independente: recebe o fio UART com o periodo nominal de 115200 baud.
module metrics_uart_monitor #(
    parameter integer BIT_NS = 8681
) (
    input wire txd,
    input wire rst,
    output integer frames = 0,
    output integer correct_count = -1,
    output integer wrong_count = -1,
    output integer attempt_count = -1,
    output reg completed = 0
);
    reg [7:0] bytes [0:22];
    reg [7:0] received;
    integer index = 0;
    integer bit_index;
    integer epoch = 0;
    integer byte_epoch;

    function integer decimal_field;
        input integer offset;
        integer j;
        begin
            decimal_field = 0;
            for (j = 0; j < 5; j = j + 1) begin
                if (bytes[offset+j] < "0" || bytes[offset+j] > "9")
                    $fatal(1, "Campo decimal invalido no byte %0d", offset+j);
                decimal_field = decimal_field * 10 + bytes[offset+j] - "0";
            end
        end
    endfunction

    always @(posedge rst) begin
        epoch = epoch + 1;
        index = 0;
        frames = 0;
        correct_count = -1;
        wrong_count = -1;
        attempt_count = -1;
        completed = 0;
    end

    always begin
        @(negedge txd);
        if (!rst) begin
            byte_epoch = epoch;
            #(BIT_NS / 2);
            if (!rst && byte_epoch == epoch && txd !== 1'b0)
                $fatal(1, "Start bit invalido");
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                #BIT_NS;
                received[bit_index] = txd;
            end
            #BIT_NS;
            if (!rst && byte_epoch == epoch) begin
                if (txd !== 1'b1)
                    $fatal(1, "Stop bit invalido");
                if (^received === 1'bx)
                    $fatal(1, "Byte UART indefinido");
                bytes[index] = received;
                if (index == 22) begin
                    if (bytes[0] !== "M" || bytes[1] !== "," ||
                        bytes[7] !== "," || bytes[13] !== "," ||
                        bytes[19] !== "," || bytes[21] !== 8'h0d ||
                        bytes[22] !== 8'h0a ||
                        (bytes[20] !== "0" && bytes[20] !== "1"))
                        $fatal(1, "Formato da mensagem de metricas invalido");
                    correct_count = decimal_field(2);
                    wrong_count = decimal_field(8);
                    attempt_count = decimal_field(14);
                    completed = bytes[20] == "1";
                    if (correct_count + wrong_count != attempt_count)
                        $fatal(1, "Snapshot inconsistente: acertos + erros != tentativas");
                    frames = frames + 1;
                    index = 0;
                end else begin
                    index = index + 1;
                end
            end
        end
    end
endmodule

module tb_uart_metrics_sender;
    reg clk = 0;
    always #10 clk = ~clk;
    reg rst = 1;
    reg session_start = 0;
    reg correct_pulse = 0;
    reg wrong_pulse = 0;
    reg session_done = 0;
    wire [7:0] tx_tdata;
    wire tx_tvalid;
    reg tx_tready = 0;
    reg [7:0] stalled_byte;
    integer i;

    uart_metrics_sender dut (
        .clk(clk), .rst(rst), .session_start(session_start),
        .correct_pulse(correct_pulse), .wrong_pulse(wrong_pulse),
        .session_done(session_done), .tx_tdata(tx_tdata),
        .tx_tvalid(tx_tvalid), .tx_tready(tx_tready)
    );

    task pulse;
        input integer kind; // 0=start, 1=correct, 2=wrong
        begin
            @(negedge clk);
            session_start = kind == 0;
            correct_pulse = kind == 1;
            wrong_pulse = kind == 2;
            @(negedge clk);
            session_start = 0;
            correct_pulse = 0;
            wrong_pulse = 0;
        end
    endtask

    task receive_frame;
        input [183:0] expected;
        integer j;
        begin
            for (j = 0; j < 23; j = j + 1) begin
                @(negedge clk);
                tx_tready = 1;
                @(posedge clk);
                while (!tx_tvalid) @(posedge clk);
                if (tx_tdata !== expected[183-j*8 -: 8])
                    $fatal(1, "Byte %0d: esperado %02h, recebido %02h (%s)",
                           j, expected[183-j*8 -: 8], tx_tdata, expected);
                @(negedge clk);
                tx_tready = 0;
                stalled_byte = tx_tdata;
                repeat (3) begin
                    @(posedge clk);
                    if (j < 22 && (!tx_tvalid || tx_tdata !== stalled_byte))
                        $fatal(1, "Dados mudaram durante backpressure");
                end
            end
        end
    endtask

    task expect_quiet;
        begin
            repeat (10) @(posedge clk);
            if (tx_tvalid) $fatal(1, "Frame extra sem alteracao das metricas");
        end
    endtask

    initial begin
        #10_000_000;
        $fatal(1, "Timeout no teste unitario de metricas");
    end

    initial begin
        repeat (3) @(negedge clk);
        rst = 0;
        pulse(0);
        repeat (3) @(negedge clk);
        stalled_byte = tx_tdata;
        pulse(1);
        pulse(2);
        pulse(1);
        if (!tx_tvalid || tx_tdata !== stalled_byte)
            $fatal(1, "Snapshot em espera foi alterado por nova tentativa");
        receive_frame("M,00000,00000,00000,0\015\012");
        receive_frame("M,00002,00001,00003,0\015\012");
        expect_quiet;

        @(negedge clk); session_done = 1;
        receive_frame("M,00002,00001,00003,1\015\012");
        expect_quiet;
        @(negedge clk); session_done = 0;
        expect_quiet;

        // Nova sessao limpa todos os contadores, inclusive o estado concluida.
        pulse(0);
        receive_frame("M,00000,00000,00000,0\015\012");
        expect_quiet;

        // 65535 tentativas: testa todos os digitos, saturacao e agregacao.
        pulse(2);
        repeat (3) @(negedge clk);
        for (i = 1; i < 65535; i = i + 1) pulse(1);
        pulse(1);
        pulse(2);
        receive_frame("M,00000,00001,00001,0\015\012");
        receive_frame("M,65534,00001,65535,0\015\012");
        expect_quiet;

        // Reset descarta uma mensagem pendente e volta a aguardar uma sessao.
        pulse(0);
        repeat (3) @(negedge clk);
        rst = 1;
        repeat (3) @(negedge clk);
        rst = 0;
        expect_quiet;
        pulse(0);
        receive_frame("M,00000,00000,00000,0\015\012");
        expect_quiet;
        $display("PASS: sender, snapshots, backpressure, saturacao e reset");
        $finish;
    end
endmodule

module tb_metrics_uart;
    reg clk = 0;
    always #10 clk = ~clk;
    reg rst = 1;
    reg [11:0] keys_raw = 0;
    reg mode_sel = 0;
    reg start = 0;
    wire pc_txd;
    wire pc_uart_busy;
    wire mc_done;
    wire mc_correct_pulse;
    wire mc_wrong_pulse;
    wire [2:0] mc_state_dbg;
    wire [31:0] frames, correct_count, wrong_count, attempt_count;
    wire completed;
    integer frame_snapshot;
    integer correct_events = 0;
    integer wrong_events = 0;

    top dut (
        .clk(clk), .rst(rst), .keys_raw(keys_raw), .mode_sel(mode_sel),
        .start(start), .pc_txd(pc_txd), .pc_uart_busy(pc_uart_busy),
        .mc_done(mc_done), .mc_correct_pulse(mc_correct_pulse),
        .mc_wrong_pulse(mc_wrong_pulse), .mc_state_dbg(mc_state_dbg)
    );
    metrics_uart_monitor monitor (
        .txd(pc_txd), .rst(rst), .frames(frames),
        .correct_count(correct_count), .wrong_count(wrong_count),
        .attempt_count(attempt_count), .completed(completed)
    );

    always @(posedge clk) begin
        if (rst) begin
            correct_events = 0;
            wrong_events = 0;
        end else begin
            if (mc_correct_pulse) correct_events = correct_events + 1;
            if (mc_wrong_pulse) wrong_events = wrong_events + 1;
        end
    end

    task begin_session;
        begin
            @(negedge clk); mode_sel = 1;
            repeat (10) @(negedge clk);
            start = 1;
            @(negedge clk); start = 0;
        end
    endtask

    task play_key;
        input integer note;
        begin
            @(negedge clk); keys_raw = 12'b1 << note;
            repeat (30) @(negedge clk);
            keys_raw = 0;
            repeat (30) @(negedge clk);
        end
    endtask

    task await_metrics;
        input integer c, w, a;
        input reg d;
        integer cycles;
        begin
            cycles = 0;
            while (correct_count != c || wrong_count != w ||
                   attempt_count != a || completed != d) begin
                @(negedge clk);
                cycles = cycles + 1;
                if (cycles > 400000)
                    $fatal(1, "Metricas ausentes: esperado %0d/%0d/%0d/%0d, recebido %0d/%0d/%0d/%0d",
                           c,w,a,d,correct_count,wrong_count,attempt_count,completed);
            end
        end
    endtask

    task no_new_frames;
        begin
            frame_snapshot = frames;
            #2_500_000;
            if (frames != frame_snapshot)
                $fatal(1, "Transmissao duplicada sem nova tentativa");
        end
    endtask

    initial begin
        #100_000_000;
        $fatal(1, "Timeout na integracao FPGA -> PC");
    end

    initial begin
        repeat (5) @(negedge clk);
        rst = 0;
        // Tocar no modo Livre nao cria uma tentativa da atividade.
        play_key(3);
        no_new_frames;
        if (frames != 0) $fatal(1, "Metricas de atividade emitidas no modo Livre");

        // Uma tecla ja pressionada antes de iniciar nao e uma tentativa.
        keys_raw = 12'b1 << 5;
        repeat (30) @(negedge clk);
        begin_session;
        await_metrics(0,0,0,0);
        no_new_frames;
        if (wrong_events != 0 || correct_events != 0)
            $fatal(1, "Tecla mantida antes de start foi avaliada");
        @(negedge clk); keys_raw = 0;
        repeat (30) @(negedge clk);

        // Mudancas durante o pulso da UC nao podem virar acertos/erros fantasma.
        // O debounce atual e zero: um pulso de um clock chega ate a UC.
        keys_raw = 12'b1;
        @(negedge clk); keys_raw = 0;
        repeat (30) @(negedge clk);
        keys_raw = 12'b1;
        @(negedge clk); keys_raw = (12'b1 << 0) | (12'b1 << 9);
        repeat (30) @(negedge clk);
        keys_raw = 0;
        repeat (30) @(negedge clk);
        no_new_frames;
        if (wrong_events != 0 || correct_events != 0)
            $fatal(1, "Transicao curta para zero/acorde foi avaliada");

        // Erro deve contar uma unica vez mesmo mantendo a tecla pressionada.
        keys_raw = 12'b1 << 9;
        await_metrics(0,1,1,0);
        no_new_frames;
        if (wrong_events != 1) $fatal(1, "Erro repetido ao manter tecla");
        @(negedge clk); keys_raw = 0;
        repeat (30) @(negedge clk);
        play_key(9);
        await_metrics(0,2,2,0);

        // Acordes nao sao tentativas validas; soltar so uma tecla nao rearma.
        @(negedge clk); keys_raw = (12'b1 << 0) | (12'b1 << 9);
        repeat (30) @(negedge clk);
        keys_raw = 12'b1;
        repeat (30) @(negedge clk);
        keys_raw = 0;
        repeat (30) @(negedge clk);
        no_new_frames;
        if (wrong_events != 2 || correct_events != 0)
            $fatal(1, "Acorde ou liberacao parcial contou como tentativa");

        // Notas corretas da atividade; a UART deve recuperar o snapshot final.
        play_key(0);
        await_metrics(1,2,3,0);
        play_key(2);
        play_key(4);
        play_key(1);
        play_key(4);
        play_key(5);
        await_metrics(6,2,8,1);
        if (!mc_done || correct_events != 6 || wrong_events != 2)
            $fatal(1, "Conclusao ou contagem de pulsos incorreta");
        no_new_frames;
        play_key(0);
        no_new_frames;

        // Nova sessao apos sair do modo Aprender.
        @(negedge clk); mode_sel = 0;
        repeat (30) @(negedge clk);
        begin_session;
        await_metrics(0,0,0,0);
        play_key(0);
        await_metrics(1,0,1,0);

        // Reset no meio de um byte: linha volta a repouso e nova sessao funciona.
        play_key(9);
        @(negedge pc_txd);
        #2000;
        @(negedge clk); rst = 1;
        repeat (5) @(negedge clk);
        if (pc_txd !== 1'b1 || pc_uart_busy !== 1'b0)
            $fatal(1, "UART nao voltou a repouso no reset");
        mode_sel = 0;
        keys_raw = 0;
        rst = 0;
        #200_000;
        begin_session;
        await_metrics(0,0,0,0);
        play_key(0);
        await_metrics(1,0,1,0);
        no_new_frames;
        $display("PASS: UART 8N1 no fio, acertos/erros, acordes, conclusao e nova sessao");
        $finish;
    end
endmodule
