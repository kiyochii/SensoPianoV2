// Physical observations, independent of the guide-note UART. No extra pins.
// T,1,event_sequence,fpga_ms,session,keys,mode,state,expected,flags,dropped,xor\r\n
// Numeric fields are fixed-width uppercase hex. XOR covers bytes 0..53.
module uart_activity_sender #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer FIFO_DEPTH = 16
) (
    input wire clk, rst,
    input wire [11:0] keys,
    input wire mode_sel,
    input wire [2:0] state,
    input wire [6:0] expected_note,
    input wire session_start, correct_pulse, wrong_pulse,
    output reg [7:0] tx_tdata,
    output wire tx_tvalid,
    input wire tx_tready
);
    localparam integer MS_CYCLES = CLK_FREQ_HZ / 1000;
    localparam integer PTR_BITS = (FIFO_DEPTH > 1) ? $clog2(FIFO_DEPTH) : 1;
    reg [31:0] divider, milliseconds, event_sequence, session, dropped;
    reg [9:0] heartbeat;
    reg [11:0] previous_keys;
    reg previous_mode, initial_event;
    reg [2:0] previous_state;
    wire ms_tick = divider == MS_CYCLES - 1;
    wire heartbeat_tick = ms_tick && heartbeat == 999;
    wire changed = initial_event || keys != previous_keys || mode_sel != previous_mode ||
                   state != previous_state || session_start || correct_pulse || wrong_pulse || heartbeat_tick;
    wire [7:0] flags = {3'b000, heartbeat_tick, initial_event, wrong_pulse, correct_pulse, session_start};
    // Packed payload: event_sequence, milliseconds, session, keys, mode, state,
    // expected note, flags, cumulative FIFO drops. The queued snapshot is immutable.
    reg [159:0] fifo [0:FIFO_DEPTH-1];
    reg [PTR_BITS-1:0] write_ptr, read_ptr;
    reg [PTR_BITS:0] count;
    reg [159:0] snapshot;
    reg active;
    reg [5:0] index;
    reg [7:0] checksum;
    wire pop = !active && count != 0;
    wire push = changed && (count < FIFO_DEPTH || pop);
    assign tx_tvalid = active;

    function [7:0] hex_digit;
        input [3:0] value;
        begin hex_digit = value < 10 ? 8'h30 + value : 8'h41 + value - 10; end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            divider <= 0; milliseconds <= 0; heartbeat <= 0;
            event_sequence <= 0; session <= 0; dropped <= 0;
            previous_keys <= 0; previous_mode <= 0; previous_state <= 0;
            initial_event <= 1; write_ptr <= 0; read_ptr <= 0; count <= 0;
            active <= 0; snapshot <= 0; index <= 0; checksum <= 0;
        end else begin
            if (ms_tick) begin
                divider <= 0;
                milliseconds <= milliseconds + 1'b1;
                heartbeat <= heartbeat == 999 ? 0 : heartbeat + 1'b1;
            end else divider <= divider + 1'b1;
            previous_keys <= keys; previous_mode <= mode_sel; previous_state <= state;
            initial_event <= 0;
            if (session_start) session <= session + 1'b1;
            if (changed) begin
                event_sequence <= event_sequence + 1'b1;
                if (!push && dropped != 32'hffffffff) dropped <= dropped + 1'b1;
            end
            if (push) begin
                fifo[write_ptr] <= {event_sequence + 32'd1, milliseconds,
                    session + (session_start ? 32'd1 : 32'd0), keys, mode_sel, state,
                    1'b0, expected_note, flags, dropped};
                write_ptr <= write_ptr == FIFO_DEPTH - 1 ? 0 : write_ptr + 1'b1;
            end
            case ({push, pop})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
            if (pop) begin
                snapshot <= fifo[read_ptr];
                read_ptr <= read_ptr == FIFO_DEPTH - 1 ? 0 : read_ptr + 1'b1;
                active <= 1; index <= 0; checksum <= 0;
            end else if (active && tx_tready) begin
                if (index < 54) checksum <= checksum ^ tx_tdata;
                if (index == 57) active <= 0;
                else index <= index + 1'b1;
            end
        end
    end

    always @(*) begin
        tx_tdata = ",";
        case (index)
            0: tx_tdata = "T";
            2: tx_tdata = "1";
            1,3,12,21,30,34,36,38,41,44,53: tx_tdata = ",";
            35: tx_tdata = snapshot[51] ? "1" : "0";
            37: tx_tdata = hex_digit({1'b0, snapshot[50:48]});
            54: tx_tdata = hex_digit(checksum[7:4]);
            55: tx_tdata = hex_digit(checksum[3:0]);
            56: tx_tdata = 8'h0d;
            57: tx_tdata = 8'h0a;
            default: begin
                if (index >= 4 && index <= 11) tx_tdata = hex_digit(snapshot[159 - (index-4)*4 -: 4]);
                else if (index >= 13 && index <= 20) tx_tdata = hex_digit(snapshot[127 - (index-13)*4 -: 4]);
                else if (index >= 22 && index <= 29) tx_tdata = hex_digit(snapshot[95 - (index-22)*4 -: 4]);
                else if (index >= 31 && index <= 33) tx_tdata = hex_digit(snapshot[63 - (index-31)*4 -: 4]);
                else if (index >= 39 && index <= 40) tx_tdata = hex_digit(snapshot[47 - (index-39)*4 -: 4]);
                else if (index >= 42 && index <= 43) tx_tdata = hex_digit(snapshot[39 - (index-42)*4 -: 4]);
                else if (index >= 45 && index <= 52) tx_tdata = hex_digit(snapshot[31 - (index-45)*4 -: 4]);
            end
        endcase
    end
endmodule
