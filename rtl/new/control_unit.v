`timescale 1ns / 1ps

module control_unit (
    input       clk,
    input       reset,

    input [2:0] mode_sw,
    input       i_run_stop,
    input       i_clear,
    input       cu_btn_m,

    output      o_mode_sw,
    output reg  o_run_stop,
    output reg  o_clear,

    output      clock_mode,
    output      time_set_mode,

    output      clk_next,
    output      clk_up,
    output      clk_down
);

    assign o_mode_sw  = mode_sw[0]; // Stopwatch mode UP/DOWN
    assign clock_mode = mode_sw[1]; // 0: stopwatch, 1: clock

    assign time_set_mode = mode_sw[1] & mode_sw[2]; // Enable time-set mode only when in clock mode

    assign clk_up   = i_run_stop & time_set_mode; // Active only in time-setting mode
    assign clk_down = i_clear    & time_set_mode; // btn_u, btn_d, btn_m
    assign clk_next = cu_btn_m   & time_set_mode; //

    wire sw_runstop_in = i_run_stop & ~clock_mode; // Ignore stopwatch input in clock mode
    wire sw_clear_in   = i_clear    & ~clock_mode; //

    localparam STOP  = 2'b00;
    localparam RUN   = 2'b01;
    localparam CLEAR = 2'b10;

    reg [1:0] c_state, n_state;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            c_state <= STOP;
        end else begin
            c_state <= n_state;
        end
    end

    always @(*) begin
        n_state = c_state;
        o_run_stop = 1'b0;
        o_clear = 1'b0;

        case (c_state)
            STOP: begin
                if (sw_runstop_in) begin
                n_state = RUN;
                end else if (sw_clear_in) begin
                n_state = CLEAR;
                end
            end

            RUN: begin
                o_run_stop = 1'b1;
                if (sw_runstop_in)begin 
                n_state = STOP;
                end
            end

            CLEAR: begin
                o_clear = 1'b1;
                n_state = STOP;
            end

            default: begin
                n_state = STOP;
            end
        endcase
    end

endmodule