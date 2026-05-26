`timescale 1ns / 1ps


module tb_dht11();


reg clk, reset, dht11_btn_start;
reg dht11_sensor_io, sensor_io_sel;
reg [39:0] dht11_sensor_data;
wire dhtio;
integer i;


assign dhtio = (sensor_io_sel) ? 1'bz : dht11_sensor_io;
dht11_top dut (
    .clk(clk),
    .reset(reset),
    .dht11_btn_start(dht11_btn_start),
    .dht11_ht_data(),
    .dht11_temp_data(),
    .dht11_valid(),
    .dht11_done(),
    .dhtio(dhtio)

);

    always #5 clk = ~clk;


    initial begin
        #0;
        clk = 0; 
        reset =1;
        dht11_btn_start = 0;
        i=0;
        dht11_sensor_io =1'b0; //start sync =0
        sensor_io_sel = 1'b1;
        //humnidity integral, decimal, temperature interal, decimal , check sum 
        dht11_sensor_data = {8'h32, 8'h00, 8'h19, 8'h00,8'h4b};

        //reset
        #20;
        reset =0;
        #20;
        dht11_btn_start = 1;
        #10;
        dht11_btn_start =0;
        

        //19msec + 30msec
        //Start signal + wait
        #(1900*10*1000+30_000);

        //to output, sensor to fpga 
        sensor_io_sel = 0;


        //sync_L, SYnc_H
        dht11_sensor_io = 1'b0;
        #(80_000);
        dht11_sensor_io = 1'b1;
        #(80_000);

        // 40bit data pattern

        dht11_sensor_io = 1'b0;
        #(50_000);
        for (i = 39 ;i>=0 ;i=i-1 ) begin
        //data sync_L
         dht11_sensor_io =1'b0;
        #(50_000);
        if (dht11_sensor_data[i] == 0) begin
            dht11_sensor_io = 1'b1;
            #(28_000);

        end else begin
            dht11_sensor_io = 1'b1;
            #(70_000);
        end
            
        end


        dht11_sensor_io =0;
        #(50_000);
        //to output, FPGA to Sensor
        sensor_io_sel = 1;

        #100_000;
        $stop;

    end

endmodule
