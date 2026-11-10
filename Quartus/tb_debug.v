`timescale 1ns/1ps
module tb_debug;
    reg clk=0;
    always #10 clk=~clk;
    reg [1:0] key=2'b10;
    reg sw0=1, sw1=0;
    reg [11:0] keys=12'h800;
    wire audio, tx;
    wire [11:0] leds,r,g,b;
    wire [9:0] ledr;
    sensopiano_de0_cv dut(.CLOCK_50(clk),.KEY(key),.SW0(sw0),.SW1(sw1),
        .piano_keys(keys),.LEDR(ledr),.piano_leds_n(leds),
        .rgb_r_n(r),.rgb_g_n(g),.rgb_b_n(b),.esp_txd(tx),.audio_pwm(audio));
    // Acelera apenas os filtros; audio e UART mantem os tempos reais.
    defparam dut.debug_filter.DEBOUNCE_TIME_MS=0;
    time t;
    reg [7:0] data;
    integer i;
    initial begin
        #100; key=3;
        repeat(20) @(negedge clk);
        sw1=1;
        @(negedge tx);
        #(8640/2);
        if(tx!==0) $fatal(1,"Start UART");
        for(i=0;i<8;i=i+1) begin #8640; data[i]=tx; end
        #8640;
        if(tx!==1 || data!==8'h40) $fatal(1,"UART C4: %h",data);
        if(leds!==12'hffe || r!==12'hffe || g!==12'hffe || b!==12'hffe || ledr!==10'b1)
            $fatal(1,"LED/RGB C4");
        @(posedge audio); t=$time;
        @(negedge audio);
        if($time-t != 1911120) $fatal(1,"Frequencia C4");
        sw0=0; keys=0; sw1=0;
        repeat(50) @(negedge clk);
        if(audio!==0 || leds!==12'hfff) $fatal(1,"Saida debug");
        sw1=1;
        @(negedge tx); // reentrada deve retransmitir
        key=2;
        repeat(10) @(negedge clk);
        if(audio!==0 || tx!==1) $fatal(1,"Reset debug");
        $display("PASS: debug C4, UART, LEDs/RGB, prioridade, saida, reentrada e reset");
        $finish;
    end
    initial begin #20000000; $fatal(1,"Timeout"); end
endmodule
