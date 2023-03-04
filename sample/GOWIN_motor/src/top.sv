module top(
input wire clk,
input wire sw,
input wire rotary_a,
input wire rotary_b,
input wire rotary_SW,
input wire rotary2_a,
input wire rotary2_b,
input wire rotary2_SW,
output wire motor_pul,
output wire motor_enable,
output wire motor_direction,
output onboard_led,
output wire [7:0] anode,
output wire [7:0] cathode
);

logic overflow;

logic current_direction;
reg motor_pulse;
reg [11:0] position;
reg [8:0] interval_time;
reg [8:0] current_interval_count;
reg [5:0] onboard_led;
reg pulse_triger;
reg [11:0] sleep;
reg m_enable;
reg [8:0] encoder_counter;
wire debounced_rotary_a, debounced_rotary_b;

parameter FULL_STROKE_STEP = 12'd3200;
parameter ACCEL1 = 12'd50;   //accel rate 1/4
parameter ACCEL2 = 12'd100;  //accel rate 1/2
parameter ACCEL3 = 12'd440;  //up to FIRST_INTERVAL
parameter FIRST_INTERVAL = 9'd450;

timer timer_instance(clk, overflow);

initial begin
  position = 12'd0;
  current_direction = 1'b0;
  interval_time = FIRST_INTERVAL;
  encoder_counter = 256;
end

  sw_debounce deb_rotary_a(.clock_in(overflow), .sw_in(rotary_a), .sw_out(debounced_rotary_a));
  sw_debounce deb_rotary_b(.clock_in(overflow), .sw_in(rotary_b), .sw_out(debounced_rotary_b));

  always @(negedge debounced_rotary_a)begin
    if(debounced_rotary_b)begin
      if(encoder_counter > 0)begin
        encoder_counter <= encoder_counter - 'd1;
      end
    end else begin
      if(encoder_counter < 511)begin
        encoder_counter <= encoder_counter + 'd1;
      end
    end
  end

/*instanciate matrix driver
  // Assign row, col to outpus.
  logic [7:0] row, col;
  assign anode   = ~col;
  assign cathode = row;
  reg [3:0] diameter;
  wire debounced_rotary_a;
  wire debounced_rotary_b;
  logic overflow;

  // matrix_led_driver instance.
  matrix_led_driver inst_0 (
    .clk  (clk),
    .sw1  (sw1),
    .row  (row),
    .col  (col),
    .diameter (diameter)
  );
/*



/*
always @(negedge enc_pul_a)begin
  if(encoder_counter > 9'd40)begin
    encoder_counter <= 9'd40;
  end
  else if(encoder_counter == 9'd0) begin
    encoder_counter <= 9'd1;
  end
  else if(enc_pul_b)begin
    encoder_counter <= encoder_counter - 9'd1;
  end else begin
    encoder_counter <= encoder_counter + 9'd1;
  end
end
*/

always @(posedge overflow)begin
  if(current_interval_count == interval_time + encoder_counter)begin
    pulse_triger = 1'b1;
    current_interval_count <= 9'b0;
  end else begin
    pulse_triger = 1'b0;
    current_interval_count <= current_interval_count + 9'b1;
  end
end

always @(posedge pulse_triger)begin
  if(sleep)begin
    m_enable = 1'b1;
    sleep <= sleep + 12'd1;
  end
  else begin
    m_enable = 1'b0;
    if(position == FULL_STROKE_STEP)begin
      current_direction <= current_direction + 1'b1;
      interval_time <= FIRST_INTERVAL;
      sleep <= 12'b1;
      motor_pulse <= motor_pulse + 1'b1;
      position <= 12'd0;
    end

    else if(!sw)begin
      interval_time <= 9'd60;
      position = position + 12'd1;
      motor_pulse <= motor_pulse + 1'b1;
    end

    else begin // if(current_direction)begin    //move to minus direction
      if (position <= ACCEL1) begin
        if(position & 2'd1)begin
          interval_time <= interval_time - 9'd1;
        end
      end
      else if (position <= ACCEL2) begin
        if(position & 1'b1)begin
          interval_time <= interval_time - 9'd1;
        end
      end
      else if (position <= ACCEL3) begin
        interval_time <= interval_time - 9'd1;
      end
      else if(position >= FULL_STROKE_STEP - ACCEL1)begin
        if(position & 2'b1)begin
          interval_time <= interval_time + 9'd1;
        end
      end
      else if(position >= FULL_STROKE_STEP - ACCEL2 )begin
        if(position & 1'b1)begin
          interval_time <= interval_time + 9'd1;
        end
      end
      else if(position >= FULL_STROKE_STEP - ACCEL3 )begin
        interval_time <= interval_time + 9'd1;
      end

      position <= position + 12'd1;
      motor_pulse <= motor_pulse + 1'b1;
    end

  end
end

assign motor_enable = m_enable;
assign motor_direction = current_direction;
assign motor_pul = motor_pulse;

assign onboard_led = ~position[11:6];

endmodule

module matrix_led_driver (
  input  wire       clk,
  input  wire sw1,
  output wire [7:0] row,
  output wire [7:0] col,
  input  wire [3:0] diameter
);

  logic [4:0] row_cnt = 'd0;
  //wire debounced_sw1;

  reg [3:0] dimming_counter;
  wire dim_clk;
  wire scroll_clk;

  reg [31:0] [7:0] [3:0] frame_buffer;

  logic [9:0] [3:0] [31:0] font;

  assign font[0][3] = 32'h0AAAAAA0;
  assign font[0][2] = 32'hA000000A;
  assign font[0][1] = 32'hA000000A;
  assign font[0][0] = 32'h0AAAAAA0;

  assign font[1][3] = 32'h00000000;
  assign font[1][2] = 32'hA000000A;
  assign font[1][1] = 32'hAAAAAAAA;
  assign font[1][0] = 32'h0000000A;

  assign font[2][3] = 32'hA00AAAAA;
  assign font[2][2] = 32'hA00A000A;
  assign font[2][1] = 32'hA00A000A;
  assign font[2][0] = 32'hAAAA000A;

  assign font[3][3] = 32'hA000000A;
  assign font[3][2] = 32'hA00A000A;
  assign font[3][1] = 32'hA00A000A;
  assign font[3][0] = 32'h0AA1AAA0;

  assign font[4][3] = 32'hAAAAA000;
  assign font[4][2] = 32'h0000A000;
  assign font[4][1] = 32'h0000A000;
  assign font[4][0] = 32'hAAAAAAAA;

  assign font[5][3] = 32'hAAAA000A;
  assign font[5][2] = 32'hA00A000A;
  assign font[5][1] = 32'hA00A000A;
  assign font[5][0] = 32'hA00AAAAA;

  assign font[6][3] = 32'hAAAAAAAA;
  assign font[6][2] = 32'hA00A000A;
  assign font[6][1] = 32'hA00A000A;
  assign font[6][0] = 32'hA00AAAAA;

  assign font[7][3] = 32'hAAAA0000;
  assign font[7][2] = 32'hA000AA00;
  assign font[7][1] = 32'hA00000AA;
  assign font[7][0] = 32'hA0000000;

  assign font[8][3] = 32'h0AAAAAA0;
  assign font[8][2] = 32'hA00A000A;
  assign font[8][1] = 32'hA00A000A;
  assign font[8][0] = 32'h0AAAAAA0;

  assign font[9][3] = 32'hAAAA000A;
  assign font[9][2] = 32'hA00A000A;
  assign font[9][1] = 32'hA00A000A;
  assign font[9][0] = 32'hAAAAAAAA;

  assign frame_buffer = {font[0], 32'h00000000, 32'h04400440, 32'h00000000, font[4], 32'h00000000, font[9], 32'h00000000, 32'h00000000, 32'h00000000};


  assign row = ('b00000001 << row_cnt[2:0]);

  assign col = row_data;

  function [4:0] shader(input [4:0] x, input [4:0] y);
    if(x > 3) x = x - 3;
    else x = 3 - x;
    if(y > 3) y = y - 3;
    else y = 3 - y;
    if((x + y) > (diameter)) shader = 0;
    else if ((x + y ) == (diameter)) shader = 4'd1;
    else if ((x + y ) == (diameter - 'd1)) shader = 4'd2;
    else if ((x + y ) == (diameter - 'd2)) shader = 4'd4;
    else if ((x + y ) == (diameter - 'd3)) shader = 4'd8;
    else shader = 4'd15;
  endfunction

  // Increment row_cnt @ overflow.
  reg [3:0] i;
  reg [7:0] row_data;
  reg [4:0] disp_window;

  always_ff @ (posedge clk) begin
    if (dim_clk) begin
      dimming_counter = dimming_counter + 'd1;
      if(dimming_counter == 0) begin
        row_cnt = row_cnt + 'd1;
      end

      for(i=0; i<8; i++)begin
        if(dimming_counter < frame_buffer[disp_window - i][7-row_cnt])begin
          row_data[i] = 1;
        end else begin
          row_data[i] = 0;
        end
      end
    end
  end

  always @ (posedge scroll_clk)begin
    disp_window <= disp_window - 'd1;
  end

   timer1 #(
    .COUNT_MAX (2000)
  ) inst_1 (
    .clk      (clk),
    .overflow (dim_clk)
  );

   timer1 #(
    .COUNT_MAX (4400000)
  ) inst_2 (
    .clk      (clk),
    .overflow (scroll_clk)
  );

endmodule

module timer1 #(
  parameter COUNT_MAX = 27000000
) (
  input  wire  clk,
  output logic overflow
);

  logic [$clog2(COUNT_MAX+1)-1:0] counter = 'd0;

  always_ff @ (posedge clk) begin
    if (counter == COUNT_MAX) begin
      counter  <= 'd0;
      overflow <= 'd1;
    end else begin
      counter  <= counter + 'd1;
      overflow <= 'd0;
    end
  end
endmodule

`default_nettype wire