`timescale 1ns/1ps
module tb_uart_activity_sender;
    reg clk=0;
    always #10 clk=~clk;
    reg rst=1, mode_sel=0, session_start=0, correct=0, wrong=0, ready=0;
    reg [11:0] keys=0;
    reg [2:0] state=0;
    reg [6:0] expected=7'h40;
    wire [7:0] data;
    wire valid;
    reg [7:0] bytes[0:57];
    reg [7:0] stalled, checksum;
    integer i, j, pressed_at, released_at, previous_sequence, saw_drops;
    uart_activity_sender #(.CLK_FREQ_HZ(4000), .FIFO_DEPTH(4)) dut (
        .clk(clk), .rst(rst), .keys(keys), .mode_sel(mode_sel), .state(state),
        .expected_note(expected), .session_start(session_start),
        .correct_pulse(correct), .wrong_pulse(wrong), .tx_tdata(data),
        .tx_tvalid(valid), .tx_tready(ready)
    );
    function integer hex_field;
        input integer offset, length;
        integer k, digit;
        begin
            hex_field=0;
            for(k=0;k<length;k=k+1) begin
                if(bytes[offset+k]>="0" && bytes[offset+k]<="9") digit=bytes[offset+k]-"0";
                else if(bytes[offset+k]>="A" && bytes[offset+k]<="F") digit=bytes[offset+k]-"A"+10;
                else $fatal(1,"Hex invalido");
                hex_field=(hex_field<<4)|digit;
            end
        end
    endfunction
    task frame;
        integer k;
        begin
            for(k=0;k<58;k=k+1) begin
                @(negedge clk); ready=0;
                while(!valid) @(negedge clk);
                stalled=data;
                repeat(2) begin
                    @(negedge clk);
                    if(!valid || data!==stalled) $fatal(1,"Instabilidade com ready=0");
                end
                bytes[k]=data; ready=1;
                @(negedge clk); ready=0;
            end
            if(bytes[0]!="T" || bytes[2]!="1" || bytes[56]!=13 || bytes[57]!=10)
                $fatal(1,"Formato T");
            checksum=0;
            for(k=0;k<54;k=k+1) checksum=checksum^bytes[k];
            if(hex_field(54,2)!=checksum) $fatal(1,"XOR T");
        end
    endtask
    initial begin
        repeat(3) @(negedge clk); rst=0;
        frame();
        if(hex_field(4,8)!=1 || hex_field(13,8)!=0 || hex_field(31,3)!=0 || hex_field(42,2)!=8)
            $fatal(1,"Snapshot inicial");
        @(negedge clk); keys=12'h001;
        repeat(200) @(negedge clk); keys=0;
        frame(); pressed_at=hex_field(13,8);
        if(hex_field(31,3)!=1) $fatal(1,"Pressao nao capturada");
        frame(); released_at=hex_field(13,8);
        if(hex_field(31,3)!=0 || released_at-pressed_at!=50) $fatal(1,"Tempo de soltura");
        @(negedge clk); mode_sel=1; state=1; session_start=1;
        @(negedge clk); session_start=0; state=2; expected=7'h30;
        @(negedge clk); state=3;
        @(negedge clk); keys=12'h200;
        @(negedge clk); state=4; wrong=1;
        @(negedge clk); wrong=0; state=3;
        // Queue plus active frame cannot hold all six observations. Old snapshots
        // stay intact, and the next heartbeat reports cumulative drops/sequence gap.
        previous_sequence=3; saw_drops=0;
        for(j=0;j<9;j=j+1) begin
            frame();
            if(hex_field(4,8)<=previous_sequence) $fatal(1,"Ordem de eventos");
            if(hex_field(45,8)>0) saw_drops=1;
            previous_sequence=hex_field(4,8);
            if(j==0 && (hex_field(22,8)!=1 || hex_field(42,2)!=1)) $fatal(1,"Inicio de sessao");
            if(j==1 && (hex_field(37,1)!=2 || hex_field(39,2)!=8'h30)) $fatal(1,"Guia da atividade");
        end
        if(!saw_drops) $fatal(1,"Overflow nao sinalizado");
        @(negedge clk); state=4; correct=1;
        @(negedge clk); correct=0;
        frame();
        if(hex_field(42,2)!=2) $fatal(1,"Flag acerto");
        @(negedge clk); wrong=1;
        @(negedge clk); wrong=0;
        frame();
        if(hex_field(42,2)!=4) $fatal(1,"Flag erro");
        @(negedge clk); rst=1;
        repeat(3) @(negedge clk); rst=0;
        frame();
        if(hex_field(4,8)!=1 || hex_field(42,2)!=8) $fatal(1,"Reset T");
        $display("PASS: tb_uart_activity_sender (tempo FPGA, teclas, sessao, FIFO, backpressure, XOR, heartbeat e reset)");
        $finish;
    end
    initial begin #1_000_000; $fatal(1,"Timeout T"); end
endmodule
