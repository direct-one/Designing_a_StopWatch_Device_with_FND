`timescale 1ns / 1ps


module tb_sr04();


reg         clk, reset;
reg         echo;
reg         sr04_start;
wire        trigger;
wire [12:0] dist;



sr04_ctrl_top dut (
    .clk(clk),
    .reset(reset),
    .echo(echo),
    .sr04_start(sr04_start),
    .trigger(trigger),
    .dist(dist)
);


always #5 clk = ~clk;


initial begin
    #0;
    clk =0;
    reset =1;
    echo =0;
    sr04_start =0;
    #100

    reset = 0;
    #10;
    sr04_start =1;
    #50;
    sr04_start =0;
    wait(trigger == 1);
    wait(trigger == 0);
    #28_000_000;
    echo =1;
    #580_000;
    echo =0;

    #10_000;

    #1000_000;
    $stop;


end


endmodule
