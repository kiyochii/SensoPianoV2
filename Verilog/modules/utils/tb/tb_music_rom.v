`timescale 1ns / 1ps

module tb_music_rom;
    reg [1:0] music_sel;
    reg [3:0] note_idx;
    wire [3:0] note_out, song_length;
    reg [31:0] songs [0:3];
    integer lengths [0:3];
    integer song, idx, expected;
    music_rom dut (.music_sel(music_sel), .note_idx(note_idx),
                   .note_out(note_out), .song_length(song_length));
    initial begin
        songs[0] = 32'h24575420; lengths[0] = 8;
        songs[1] = 32'h00247977; lengths[1] = 6;
        songs[2] = 32'h0007b740; lengths[2] = 5;
        songs[3] = 32'h0000479b; lengths[3] = 4;
        for (song = 0; song < 4; song = song + 1)
            for (idx = 15; idx >= 0; idx = idx - 1) begin
                music_sel = song; note_idx = idx; #1;
                expected = idx < lengths[song] ? ((songs[song] >> (idx*4)) & 15) : 0;
                if (note_out !== expected[3:0] || song_length !== lengths[song])
                    $fatal(1, "ROM: musica=%0d indice=%0d nota=%0d tamanho=%0d",
                           song, idx, note_out, song_length);
            end
        $display("PASS: tb_music_rom (64 combinacoes, quatro musicas e indices invalidos)");
        $finish;
    end
    initial begin #1000; $fatal(1, "Timeout ROM"); end
endmodule
