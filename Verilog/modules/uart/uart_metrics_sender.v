// Snapshots das metricas: M,acertos,erros,tentativas,concluida\r\n
// Contadores decimais com cinco digitos. Ex.: M,00002,00001,00003,0
module uart_metrics_sender (
    input  wire       clk,
    input  wire       rst,
    input  wire       session_start,
    input  wire       correct_pulse,
    input  wire       wrong_pulse,
    input  wire       session_done,
    output reg  [7:0] tx_tdata,
    output wire       tx_tvalid,
    input  wire       tx_tready
);
    reg [15:0] correct_count, wrong_count, attempt_count;
    reg        done_latched, done_prev;
    reg [15:0] snapshot_correct, snapshot_wrong, snapshot_attempts;
    reg        snapshot_done;
    reg        pending, active;
    reg [4:0]  byte_index;

    wire count_attempt = (correct_pulse || wrong_pulse) &&
                         (attempt_count != 16'hffff);
    wire done_event = session_done && !done_prev;
    wire metrics_changed = session_start || count_attempt || done_event;

    // Cada tentativa incrementa exatamente um resultado; acerto tem prioridade
    // caso ambos os pulsos sejam indevidamente apresentados juntos.
    always @(posedge clk) begin
        if (rst) begin
            correct_count <= 16'd0;
            wrong_count   <= 16'd0;
            attempt_count <= 16'd0;
            done_latched  <= 1'b0;
            done_prev     <= 1'b0;
        end else begin
            done_prev <= session_done;
            if (session_start) begin
                correct_count <= 16'd0;
                wrong_count   <= 16'd0;
                attempt_count <= 16'd0;
                done_latched  <= 1'b0;
            end else begin
                if (count_attempt) begin
                    attempt_count <= attempt_count + 16'd1;
                    if (correct_pulse)
                        correct_count <= correct_count + 16'd1;
                    else
                        wrong_count <= wrong_count + 16'd1;
                end
                if (done_event)
                    done_latched <= 1'b1;
            end
        end
    end

    // Congela uma linha inteira. Atualizacoes durante o envio ficam pendentes:
    // a proxima linha leva os totais mais recentes, sem misturar dois snapshots.
    // Os contadores recebem todos os eventos, mesmo com tx_tready baixo.
    always @(posedge clk) begin
        if (rst) begin
            pending           <= 1'b0;
            active            <= 1'b0;
            byte_index        <= 5'd0;
            snapshot_correct  <= 16'd0;
            snapshot_wrong    <= 16'd0;
            snapshot_attempts <= 16'd0;
            snapshot_done     <= 1'b0;
        end else begin
            if (metrics_changed)
                pending <= 1'b1;

            if (!active && pending) begin
                snapshot_correct  <= correct_count;
                snapshot_wrong    <= wrong_count;
                snapshot_attempts <= attempt_count;
                snapshot_done     <= done_latched;
                byte_index        <= 5'd0;
                active            <= 1'b1;
                // Um evento neste clock altera os contadores apos a captura.
                pending           <= metrics_changed;
            end else if (active && tx_tready) begin
                if (byte_index == 5'd22)
                    active <= 1'b0;
                else
                    byte_index <= byte_index + 5'd1;
            end
        end
    end

    function [7:0] decimal_digit;
        input [15:0] value;
        input [2:0] position;
        reg [15:0] quotient;
        begin
            case (position)
                3'd0: quotient = value / 16'd10000;
                3'd1: quotient = value / 16'd1000;
                3'd2: quotient = value / 16'd100;
                3'd3: quotient = value / 16'd10;
                default: quotient = value;
            endcase
            decimal_digit = 8'h30 + (quotient % 16'd10);
        end
    endfunction

    assign tx_tvalid = active;

    always @(*) begin
        tx_tdata = 8'h00;
        case (byte_index)
            5'd0: tx_tdata = "M";
            5'd1, 5'd7, 5'd13, 5'd19: tx_tdata = ",";
            5'd2: tx_tdata = decimal_digit(snapshot_correct, 3'd0);
            5'd3: tx_tdata = decimal_digit(snapshot_correct, 3'd1);
            5'd4: tx_tdata = decimal_digit(snapshot_correct, 3'd2);
            5'd5: tx_tdata = decimal_digit(snapshot_correct, 3'd3);
            5'd6: tx_tdata = decimal_digit(snapshot_correct, 3'd4);
            5'd8: tx_tdata = decimal_digit(snapshot_wrong, 3'd0);
            5'd9: tx_tdata = decimal_digit(snapshot_wrong, 3'd1);
            5'd10: tx_tdata = decimal_digit(snapshot_wrong, 3'd2);
            5'd11: tx_tdata = decimal_digit(snapshot_wrong, 3'd3);
            5'd12: tx_tdata = decimal_digit(snapshot_wrong, 3'd4);
            5'd14: tx_tdata = decimal_digit(snapshot_attempts, 3'd0);
            5'd15: tx_tdata = decimal_digit(snapshot_attempts, 3'd1);
            5'd16: tx_tdata = decimal_digit(snapshot_attempts, 3'd2);
            5'd17: tx_tdata = decimal_digit(snapshot_attempts, 3'd3);
            5'd18: tx_tdata = decimal_digit(snapshot_attempts, 3'd4);
            5'd20: tx_tdata = snapshot_done ? "1" : "0";
            5'd21: tx_tdata = 8'h0d;
            5'd22: tx_tdata = 8'h0a;
        endcase
    end
endmodule
