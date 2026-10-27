module mode_controller (
    input  wire        clk,
    input  wire        rst,

    input  wire        mode_sel,         // 0 = livre, 1 = aprender
    input  wire        start,            // inicia modo aprender

    input  wire [11:0] keys_db,
    input  wire [11:0] keys_reg,
    input  wire        key_valid_pulse,

    output reg  [11:0] leds_out,
    output reg  [11:0] rgb_r,
    output reg  [11:0] rgb_g,
    output reg  [11:0] rgb_b,

    output reg         send_note,
    output reg  [3:0]  note_out,
    output reg  [2:0]  octave_out,
    output reg         tone_enable,
    output reg  [3:0]  tone_note,
    output reg  [2:0]  tone_octave,

    output reg         correct_pulse,
    output reg         wrong_pulse,
    output reg         done,
    output reg  [2:0]  state_dbg,
    output wire        session_start_pulse
);

    localparam FREE_MODE   = 3'd0;
    localparam LEARN_IDLE  = 3'd1;
    localparam LEARN_SHOW  = 3'd2;
    localparam LEARN_WAIT  = 3'd3;
    localparam LEARN_CHECK = 3'd4;
    localparam LEARN_DONE  = 3'd5;

    reg [2:0] state, next_state;
    reg [2:0] song_index;
    reg       attempt_correct;
    reg       learn_armed;

    reg [6:0] expected_full;
    reg [3:0] expected_note;
    reg [2:0] expected_octave;

    wire [11:0] expected_onehot;
    wire        expected_key_down;
    wire        free_key_any;
    wire        free_key_valid;
    wire        accept_attempt;

    assign expected_onehot   = (12'b000000000001 << expected_note);
    assign expected_key_down = keys_db[expected_note];
    assign session_start_pulse = (state == LEARN_IDLE) && mode_sel && start;
    assign free_key_any      = |keys_db;
    assign free_key_valid    = free_key_any && ((keys_db & (keys_db - 12'd1)) == 12'd0);
    assign accept_attempt    = key_valid_pulse && learn_armed && free_key_valid;

    // ==========================================
    // ROM simples da música
    // Formato: [6:4] = oitava, [3:0] = nota
    // ==========================================
    function [6:0] song_rom;
        input [2:0] idx;
        begin
            case (idx)
                3'd0: song_rom = 7'b011_0000; // oitava 3, nota 0
                3'd1: song_rom = 7'b100_0010; // oitava 4, nota 2
                3'd2: song_rom = 7'b101_0100; // oitava 5, nota 4
                3'd3: song_rom = 7'b110_0001; // oitava 6, nota 1
                3'd4: song_rom = 7'b101_0100; // oitava 5, nota 4
                3'd5: song_rom = 7'b110_0101; // oitava 6, nota 5
                default: song_rom = 7'b100_0000;
            endcase
        end
    endfunction

    function [3:0] key_vector_to_note;
        input [11:0] keys_in;
        begin
            key_vector_to_note = 4'd0;

            if (keys_in[0])
                key_vector_to_note = 4'd0;
            else if (keys_in[1])
                key_vector_to_note = 4'd1;
            else if (keys_in[2])
                key_vector_to_note = 4'd2;
            else if (keys_in[3])
                key_vector_to_note = 4'd3;
            else if (keys_in[4])
                key_vector_to_note = 4'd4;
            else if (keys_in[5])
                key_vector_to_note = 4'd5;
            else if (keys_in[6])
                key_vector_to_note = 4'd6;
            else if (keys_in[7])
                key_vector_to_note = 4'd7;
            else if (keys_in[8])
                key_vector_to_note = 4'd8;
            else if (keys_in[9])
                key_vector_to_note = 4'd9;
            else if (keys_in[10])
                key_vector_to_note = 4'd10;
            else if (keys_in[11])
                key_vector_to_note = 4'd11;
        end
    endfunction

    // ==========================================
    // Registradores principais
    // ==========================================
    always @(posedge clk) begin
        if (rst) begin
            state             <= FREE_MODE;
            song_index        <= 3'd0;
            attempt_correct   <= 1'b0;
            learn_armed       <= 1'b0;
        end else begin
            state             <= next_state;

            // Uma tentativa exige uma nova tecla individual apos soltar todas.
            // Registra a decisao antes de mudar o indice da musica.
            if (!mode_sel || state == LEARN_IDLE) begin
                learn_armed <= 1'b0;
            end else if (state == LEARN_WAIT) begin
                if (!free_key_any)
                    learn_armed <= 1'b1;
                else if (accept_attempt) begin
                    attempt_correct <= expected_key_down;
                    learn_armed <= 1'b0;
                end
            end

            if (!mode_sel) begin
                song_index <= 3'd0;
            end else begin
                if (state == LEARN_IDLE && start)
                    song_index <= 3'd0;
                else if (state == LEARN_CHECK && attempt_correct) begin
                    if (song_index != 3'd5)
                        song_index <= song_index + 3'd1;
                end
            end
        end
    end

    // ==========================================
    // Nota e oitava esperadas
    // ==========================================
    always @(*) begin
        expected_full   = song_rom(song_index);
        expected_octave = expected_full[6:4];
        expected_note   = expected_full[3:0];
    end

    // ==========================================
    // Próximo estado
    // ==========================================
    always @(*) begin
        next_state = state;

        case (state)
            FREE_MODE: begin
                if (mode_sel)
                    next_state = LEARN_IDLE;
            end

            LEARN_IDLE: begin
                if (!mode_sel)
                    next_state = FREE_MODE;
                else if (start)
                    next_state = LEARN_SHOW;
            end

            LEARN_SHOW: begin
                next_state = LEARN_WAIT;
            end

            LEARN_WAIT: begin
                if (!mode_sel)
                    next_state = FREE_MODE;
                else if (accept_attempt)
                    next_state = LEARN_CHECK;
            end

            LEARN_CHECK: begin
                if (!mode_sel)
                    next_state = FREE_MODE;
                else if (attempt_correct) begin
                    if (song_index == 3'd5)
                        next_state = LEARN_DONE;
                    else
                        next_state = LEARN_SHOW;
                end else begin
                    next_state = LEARN_WAIT;
                end
            end

            LEARN_DONE: begin
                if (!mode_sel)
                    next_state = FREE_MODE;
            end

            default: begin
                next_state = FREE_MODE;
            end
        endcase
    end

    // ==========================================
    // Saídas
    // ==========================================
    always @(*) begin
        leds_out      = 12'd0;
        rgb_r         = 12'd0;
        rgb_g         = 12'd0;
        rgb_b         = 12'd0;

        send_note     = 1'b0;
        note_out      = 4'd0;
        octave_out    = 3'd0;
        tone_enable   = 1'b0;
        tone_note     = 4'd0;
        tone_octave   = 3'd0;

        correct_pulse = 1'b0;
        wrong_pulse   = 1'b0;
        done          = 1'b0;
        state_dbg     = state;

        case (state)
            FREE_MODE: begin
                leds_out = keys_db;
                rgb_r    = keys_db;
                rgb_g    = keys_db;
                rgb_b    = keys_db;

                if (free_key_valid) begin
                    tone_enable = 1'b1;
                    tone_note   = key_vector_to_note(keys_db);
                    tone_octave = 3'd4;
                end

                if (key_valid_pulse) begin
                    send_note  = 1'b1;
                    // keys_reg so atualiza no clock seguinte ao pulso da UC.
                    // Para montar o byte UART no mesmo ciclo do evento,
                    // usamos a tecla debounced atual, que ja esta valida.
                    note_out   = key_vector_to_note(keys_db);
                    octave_out = 3'd4;
                end
            end

            LEARN_SHOW: begin
                leds_out   = expected_onehot;
                send_note  = 1'b1;
                note_out   = expected_note;
                octave_out = expected_octave;
                tone_enable = 1'b1;
                tone_note   = expected_note;
                tone_octave = expected_octave;

                case (expected_octave)
                    3'd0, 3'd1, 3'd2: rgb_r = expected_onehot; // grave
                    3'd3, 3'd4, 3'd5: rgb_g = expected_onehot; // medio
                    default:           rgb_b = expected_onehot; // agudo
                endcase
            end

            LEARN_WAIT: begin
                leds_out = expected_onehot;
                tone_enable = 1'b1;
                tone_note   = expected_note;
                tone_octave = expected_octave;

                case (expected_octave)
                    3'd0, 3'd1, 3'd2: rgb_r = expected_onehot;
                    3'd3, 3'd4, 3'd5: rgb_g = expected_onehot;
                    default:           rgb_b = expected_onehot;
                endcase
            end

            LEARN_CHECK: begin
                if (attempt_correct)
                    correct_pulse = 1'b1;
                else
                    wrong_pulse = 1'b1;
            end

            LEARN_DONE: begin
                done = 1'b1;
            end
        endcase
    end

endmodule
