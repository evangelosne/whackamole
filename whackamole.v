`timescale 1 ns / 100 ps

module whack_a_mole (
input Ack, Clk, Reset,
input BtnU, BtnL, BtnR,BtnC, BtnD,
input Sw0, Sw1, Sw2, Sw3, Sw4, Sw5, Sw6, Sw7, Sw8,
output reg game_timer_out,
output reg mole_timer_out,
output reg start_game,
output reg [6:0] score, // 7-bit counter
output reg [32:0] game_counter,
output reg [31:0] mole_timer,
output reg [3:0]  mole_index,
output reg [4:0] state
);


reg [31:0] mole_max;
reg reset_mole_timer;
parameter [32:0] game_max = 33'd6000000000 - 1;

//reg [4:0] state;

reg [3:0] random_num;
reg [3:0] sw_num;
reg [3:0] lfsr;

localparam
WAIT   = 5'b00001,
INI    = 5'b00010,
SPAWN  = 5'b00100,
HIT    = 5'b01000,
DONE   = 5'b10000;


// generating random number
always @(posedge Clk or posedge Reset) begin
        if (Reset) begin
            lfsr <= 4'b1011;  // any non-zero seed
        end else begin
            // polynomial x^4 + x^3 + 1 -> feedback = bit3 ^ bit2
            lfsr <= {lfsr[2:0], lfsr[3] ^ lfsr[2]};
        end
    end

// game counter
always @(posedge Clk or posedge Reset) begin
    if (Reset) begin
        game_counter   <= 0;
        game_timer_out <= 0;
    end else if (!game_timer_out) begin
        if (game_counter == game_max) begin
            game_timer_out <= 1;
        end else begin
            game_counter <= game_counter + 1;
        end
    end
end

//mole timer
always @(posedge Clk or posedge Reset) begin
    if (Reset) begin
        mole_timer     <= 0;
        mole_timer_out <= 0;
    end else if (reset_mole_timer) begin
        mole_timer     <= 0;
        mole_timer_out <= 0;
    end else begin
        if (mole_timer == mole_max) begin
            mole_timer_out <= 1;
            mole_timer     <= 0;
        end else begin
            mole_timer     <= mole_timer + 1;
            mole_timer_out <= 0;  
        end
    end
end
               

// state transitions and RTL logic
always @(posedge Clk or posedge Reset) begin
    if (Reset) begin
        state        <= INI;
        score        <= 7'd0;
        start_game   <= 1'b0;
        mole_max     <= 32'd3000000000; // default difficulty
        reset_mole_timer <= 1;
    end else begin
        reset_mole_timer <= 0; 
        case (state)
            WAIT: begin
                if (Reset) state <= INI;
                start_game <= 0;
            end

            INI: begin
                if (BtnL) begin
                    mole_max   <= 32'd300000000 - 1; // easy
                    start_game <= 1;
                end else if (BtnU) begin
                    mole_max   <= 32'd200000000 - 1; // medium
                    start_game <= 1;
                end else if (BtnR) begin
                    mole_max   <= 32'd100000000 - 1; // hard
                    start_game <= 1;
                end

                if (BtnL || BtnU || BtnR)
                    state <= SPAWN;
            end

            SPAWN: begin
                if (mole_timer_out) begin
                    if (lfsr > 4'd8) begin
                        random_num <= lfsr - 4'd9;
                        mole_index <= lfsr - 4'd9;  
                    end else begin
                        random_num <= lfsr;          // 0-8
                        mole_index <= lfsr;
                    end
                end
                //sw_num <= 4'hF;
                // read switches
                if      (Sw0) sw_num <= 0;
                else if (Sw1) sw_num <= 1;
                else if (Sw2) sw_num <= 2;
                else if (Sw3) sw_num <= 3;
                else if (Sw4) sw_num <= 4;
                else if (Sw5) sw_num <= 5;
                else if (Sw6) sw_num <= 6;
                else if (Sw7) sw_num <= 7;
                else if (Sw8) sw_num <= 8;
                else sw_num <= 15;

                if (game_timer_out)
                    state <= DONE;
                else if (sw_num == random_num)
                    state <= HIT;
            end

            HIT: begin
                score <= score + 1;
                random_num <= 14;
                mole_index <= 14;
                reset_mole_timer <= 1;

                if (game_timer_out)
                    state <= DONE;
                else
                    state <= SPAWN;
            end

            DONE: begin
                if (Ack) state <= WAIT;
            end

            default: begin
                state <= WAIT;
            end
        endcase
    end
end

endmodule

module vga_sync (
input        clk,       // pixel clock (~25 MHz)
input        reset,
output       hSync,
output       vSync,
output       video_on,
output [9:0] pixel_x,
output [9:0] pixel_y
);
// 640x480 @60Hz timing
localparam HD   = 640;  // horizontal display
localparam HF   = 16;   // front porch
localparam HS   = 96;   // sync pulse
localparam HB   = 48;   // back porch
localparam HMAX = HD + HF + HS + HB - 1; // 799

localparam VD   = 480;
localparam VF   = 10;
localparam VS   = 2;
localparam VB   = 33;
localparam VMAX = VD + VF + VS + VB - 1; // 524

reg [9:0] h_count, v_count;

// horizontal counter
always @(posedge clk or posedge reset) begin
    if (reset)
        h_count <= 0;
    else if (h_count == HMAX)
        h_count <= 0;
    else
        h_count <= h_count + 1;
end

// vertical counter
always @(posedge clk or posedge reset) begin
    if (reset)
        v_count <= 0;
    else if (h_count == HMAX) begin
        if (v_count == VMAX)
            v_count <= 0;
        else
            v_count <= v_count + 1;
    end
end

// sync pulses are active low
assign hSync = ~((h_count >= HD + HF) && (h_count < HD + HF + HS));
assign vSync = ~((v_count >= VD + VF) && (v_count < VD + VF + VS));

assign video_on = (h_count < HD) && (v_count < VD);
assign pixel_x  = h_count;
assign pixel_y  = v_count;
endmodule

module clk_div_25MHz (
input  Clk100MHz,
input  Reset,
output pix_clk
);
reg [1:0] div_cnt;
always @(posedge Clk100MHz or posedge Reset) begin
    if (Reset)
        div_cnt <= 0;
    else
        div_cnt <= div_cnt + 1;
end

assign pix_clk = div_cnt[1]; // 100 MHz / 4 = 25 MHz
endmodule


module whackamole_video (
input        pix_clk,
input        reset,
input        video_on,
input  [9:0] pixel_x,
input  [9:0] pixel_y,
input  [3:0] mole_index,   // 0..8

output reg [3:0] vgaR,
output reg [3:0] vgaG,
output reg [3:0] vgaB,
input in_wait,
input in_done
);
// ------------------------------------------------------------
// Layout constants (640x480)
// ------------------------------------------------------------
// Header bar at top
localparam HEADER_H = 80;  // pixels

// Hole/mole positions: centers of 3x3 grid
localparam COL0_X = 110;
localparam COL1_X = 320;
localparam COL2_X = 530;

localparam ROW0_Y = 150;
localparam ROW1_Y = 260;
localparam ROW2_Y = 370;

// Hole size
localparam HOLE_W = 80;
localparam HOLE_H = 40;

// whack a mole characters
localparam game_left = 140; //changed from 50
localparam title_left = 50;
localparam game_btm = 40; // changed from 70

// "GAME OVER" text position (center-ish)
localparam GO_LEFT = 200;  // x start for GAME OVER
localparam GO_BTM  = 220;  // baseline y for GAME OVER

localparam title_btm = 260;
localparam gap = 20;

// Mole body size (sits above hole)
localparam MOLE_W = 60;
localparam MOLE_H = 60;

// ------------------------------------------------------------
// Helper: in header region?
// ------------------------------------------------------------
wire in_header = (pixel_y < HEADER_H);

// ------------------------------------------------------------
// Hole rectangles (simple rounded-rect look)
// ------------------------------------------------------------
// Convenience macros for rectangles
function automatic hole_rect;
    input [9:0] x, y;
    begin
        hole_rect =
            (pixel_x >= x - HOLE_W/2) && (pixel_x < x + HOLE_W/2) &&
            (pixel_y >= y - HOLE_H/2) && (pixel_y < y + HOLE_H/2);
    end
endfunction

function automatic square;
    input [9:0] x, y;
    begin
        square = 
            (pixel_x >= x - 5) && (pixel_x < x + 5) &&
            (pixel_y >= y - 5) && (pixel_y < y + 5);
    end
endfunction

function automatic mole_rect;
    input [9:0] x, y;
    begin
        // Mole body above the hole
        mole_rect =
            (pixel_x >= x - MOLE_W/2) && (pixel_x < x + MOLE_W/2) &&
            (pixel_y >= y - HOLE_H/2 - MOLE_H) &&
            (pixel_y <  y - HOLE_H/2);
    end
endfunction

// Hole pixels (all 9 holes)
wire hole0 = hole_rect(COL0_X, ROW0_Y);
wire hole1 = hole_rect(COL1_X, ROW0_Y);
wire hole2 = hole_rect(COL2_X, ROW0_Y);

wire hole3 = hole_rect(COL0_X, ROW1_Y);
wire hole4 = hole_rect(COL1_X, ROW1_Y);
wire hole5 = hole_rect(COL2_X, ROW1_Y);

wire hole6 = hole_rect(COL0_X, ROW2_Y);
wire hole7 = hole_rect(COL1_X, ROW2_Y);
wire hole8 = hole_rect(COL2_X, ROW2_Y);

wire hole_pixel = hole0 | hole1 | hole2 |
                    hole3 | hole4 | hole5 |
                    hole6 | hole7 | hole8;

// Active mole body (only at the selected index)
wire mole0 = (mole_index == 4'd0) && mole_rect(COL0_X, ROW0_Y);
wire mole1 = (mole_index == 4'd1) && mole_rect(COL1_X, ROW0_Y);
wire mole2 = (mole_index == 4'd2) && mole_rect(COL2_X, ROW0_Y);

wire mole3 = (mole_index == 4'd3) && mole_rect(COL0_X, ROW1_Y);
wire mole4 = (mole_index == 4'd4) && mole_rect(COL1_X, ROW1_Y);
wire mole5 = (mole_index == 4'd5) && mole_rect(COL2_X, ROW1_Y);

wire mole6 = (mole_index == 4'd6) && mole_rect(COL0_X, ROW2_Y);
wire mole7 = (mole_index == 4'd7) && mole_rect(COL1_X, ROW2_Y);
wire mole8 = (mole_index == 4'd8) && mole_rect(COL2_X, ROW2_Y);

wire mole_pixel = mole0 | mole1 | mole2 |
                    mole3 | mole4 | mole5 |
                    mole6 | mole7 | mole8;

// numbers under moles
// One
wire one = square(COL0_X, ROW0_Y + 40) || 
            square(COL0_X, ROW0_Y + 50) ||
            square(COL0_X, ROW0_Y + 60);
// Two
wire two = square(COL1_X - 10, ROW0_Y + 40) ||
            square(COL1_X, ROW0_Y + 40) ||
            square(COL1_X, ROW0_Y + 50) ||
            square(COL1_X, ROW0_Y + 60) ||
            square(COL1_X - 10, ROW0_Y + 60) ||
            square(COL1_X - 10, ROW0_Y + 70) ||
            square(COL1_X - 10, ROW0_Y + 80) ||
            square(COL1_X, ROW0_Y + 80);
// Three
wire three = square(COL2_X - 10, ROW0_Y + 40) ||
                square(COL2_X, ROW0_Y + 40) ||
                square(COL2_X, ROW0_Y + 50) ||
                square(COL2_X, ROW0_Y + 60) ||
                square(COL2_X - 10, ROW0_Y + 60) ||
                square(COL2_X, ROW0_Y + 70) ||
                square(COL2_X - 10, ROW0_Y + 80) ||
                square(COL2_X, ROW0_Y + 80);
// Four
wire four = square(COL0_X - 20, ROW1_Y + 40) ||
            square(COL0_X, ROW1_Y + 40) ||
            square(COL0_X - 20, ROW1_Y + 50) ||
            square(COL0_X - 10, ROW1_Y + 50) ||
            square(COL0_X, ROW1_Y + 50) ||
            square(COL0_X, ROW1_Y + 60) ||
            square(COL0_X, ROW1_Y + 70);
// five
wire five = square(COL1_X - 10, ROW1_Y + 40) ||
            square(COL1_X, ROW1_Y + 40) ||
            square(COL1_X - 10, ROW1_Y + 50) ||
            square(COL1_X, ROW1_Y + 60) ||
            square(COL1_X - 10, ROW1_Y + 60) ||
            square(COL1_X, ROW1_Y + 70) ||
            square(COL1_X - 10, ROW1_Y + 80) ||
            square(COL1_X, ROW1_Y + 80);
// six
wire six = square(COL2_X - 20, ROW1_Y + 40) ||
            square(COL2_X - 10, ROW1_Y + 40) ||
            square(COL2_X, ROW1_Y + 40) ||
            square(COL2_X - 20, ROW1_Y + 50) ||
            square(COL2_X - 20, ROW1_Y + 60) ||
            square(COL2_X - 10, ROW1_Y + 60) ||
            square(COL2_X, ROW1_Y + 60) ||
            square(COL2_X - 20, ROW1_Y + 70) ||
            square(COL2_X, ROW1_Y + 70) ||
            square(COL2_X - 20, ROW1_Y + 80) ||
            square(COL2_X - 10, ROW1_Y + 80) ||
            square(COL2_X, ROW1_Y + 80);
// seven
wire seven = square(COL0_X - 10, ROW2_Y + 40) ||
                square(COL0_X, ROW2_Y + 40) ||
                square(COL0_X, ROW2_Y + 50) ||
                square(COL0_X, ROW2_Y + 60);
// eight
wire eight = square(COL1_X - 20, ROW2_Y + 40) ||
            square(COL1_X - 10, ROW2_Y + 40) ||
            square(COL1_X, ROW2_Y + 40) ||
            square(COL1_X - 20, ROW2_Y + 50) ||
            square(COL1_X, ROW2_Y + 50) ||
            square(COL1_X - 20, ROW2_Y + 60) ||
            square(COL1_X - 10, ROW2_Y + 60) ||
            square(COL1_X, ROW2_Y + 60) ||
            square(COL1_X - 20, ROW2_Y + 70) ||
            square(COL1_X, ROW2_Y + 70) ||
            square(COL1_X - 20, ROW2_Y + 80) ||
            square(COL1_X - 10, ROW2_Y + 80) ||
            square(COL1_X, ROW2_Y + 80);
// nine
wire nine = square(COL2_X - 20, ROW2_Y + 40) ||
            square(COL2_X - 10, ROW2_Y + 40) ||
            square(COL2_X, ROW2_Y + 40) ||
            square(COL2_X - 20, ROW2_Y + 50) ||
            square(COL2_X, ROW2_Y + 50) ||
            square(COL2_X - 20, ROW2_Y + 60) ||
            square(COL2_X - 10, ROW2_Y + 60) ||
            square(COL2_X, ROW2_Y + 60) ||
            square(COL2_X, ROW2_Y + 70) ||
            square(COL2_X, ROW2_Y + 80);

// whack a mole characters
// ------------------------------------------------------------
// WHACKAMOLE title letters (blocky 10x10 squares)
// Uses game_left as starting X and game_btm as baseline Y
// Each letter is ~40px wide, spaced by 20px in X
// ------------------------------------------------------------

// W
wire w =
    // left vertical
    square(game_left + 0,  game_btm + 0)  ||
    square(game_left + 0,  game_btm + 10) ||
    square(game_left + 0,  game_btm + 20) ||
    square(game_left + 0,  game_btm + 30) ||
    // right vertical
    square(game_left + 40, game_btm + 0)  ||
    square(game_left + 40, game_btm + 10) ||
    square(game_left + 40, game_btm + 20) ||
    square(game_left + 40, game_btm + 30) ||
    // bottom middle “V”
    square(game_left + 20, game_btm + 30);

// H
wire h =
    // left vertical
    square(game_left + 60, game_btm + 0)  ||
    square(game_left + 60, game_btm + 10) ||
    square(game_left + 60, game_btm + 20) ||
    square(game_left + 60, game_btm + 30) ||
    // right vertical
    square(game_left + 80, game_btm + 0)  ||
    square(game_left + 80, game_btm + 10) ||
    square(game_left + 80, game_btm + 20) ||
    square(game_left + 80, game_btm + 30) ||
    // middle bar
    square(game_left + 70, game_btm + 15);

// A
wire a =
    // top row
    square(game_left + 100, game_btm + 0)  ||
    square(game_left + 120, game_btm + 0)  ||
    // upper middle
    square(game_left + 110, game_btm + 10) ||
    // vertical legs
    square(game_left + 100, game_btm + 20) ||
    square(game_left + 100, game_btm + 30) ||
    square(game_left + 120, game_btm + 20) ||
    square(game_left + 120, game_btm + 30) ||
    // middle bar
    square(game_left + 110, game_btm + 20);

// C
wire c =
    // top row
    square(game_left + 140, game_btm + 0)  ||
    square(game_left + 150, game_btm + 0)  ||
    // left vertical
    square(game_left + 140, game_btm + 10) ||
    square(game_left + 140, game_btm + 20) ||
    square(game_left + 140, game_btm + 30) ||
    // bottom row
    square(game_left + 140, game_btm + 30) ||
    square(game_left + 150, game_btm + 30);

// K
wire k =
    // vertical spine
    square(game_left + 170, game_btm + 0)  ||
    square(game_left + 170, game_btm + 10) ||
    square(game_left + 170, game_btm + 20) ||
    square(game_left + 170, game_btm + 30) ||
    // upper diagonal
    square(game_left + 180, game_btm + 10) ||
    square(game_left + 190, game_btm + 0)  ||
    // lower diagonal
    square(game_left + 180, game_btm + 20) ||
    square(game_left + 190, game_btm + 30);

// second A (same as first A, just shifted)
wire a2 =
    // top row
    square(game_left + 210, game_btm + 0)  ||
    square(game_left + 230, game_btm + 0)  ||
    // upper middle
    square(game_left + 220, game_btm + 10) ||
    // vertical legs
    square(game_left + 210, game_btm + 20) ||
    square(game_left + 210, game_btm + 30) ||
    square(game_left + 230, game_btm + 20) ||
    square(game_left + 230, game_btm + 30) ||
    // middle bar
    square(game_left + 220, game_btm + 20);

// M
wire m =
    // left vertical
    square(game_left + 250, game_btm + 0)  ||
    square(game_left + 250, game_btm + 10) ||
    square(game_left + 250, game_btm + 20) ||
    square(game_left + 250, game_btm + 30) ||
    // right vertical
    square(game_left + 290, game_btm + 0)  ||
    square(game_left + 290, game_btm + 10) ||
    square(game_left + 290, game_btm + 20) ||
    square(game_left + 290, game_btm + 30) ||
    // inner “peaks”
    square(game_left + 260, game_btm + 10) ||
    square(game_left + 280, game_btm + 10);

// O
wire o =
    // top row
    square(game_left + 310, game_btm + 0)  ||
    square(game_left + 320, game_btm + 0)  ||
    square(game_left + 330, game_btm + 0)  ||
    // side walls
    square(game_left + 310, game_btm + 10) ||
    square(game_left + 310, game_btm + 20) ||
    square(game_left + 330, game_btm + 10) ||
    square(game_left + 330, game_btm + 20) ||
    // bottom row
    square(game_left + 310, game_btm + 30) ||
    square(game_left + 320, game_btm + 30) ||
    square(game_left + 330, game_btm + 30);

// L
wire l =
    // vertical
    square(game_left + 350, game_btm + 0)  ||
    square(game_left + 350, game_btm + 10) ||
    square(game_left + 350, game_btm + 20) ||
    square(game_left + 350, game_btm + 30) ||
    // bottom bar
    square(game_left + 360, game_btm + 30);

// E
wire e =
    // vertical
    square(game_left + 380, game_btm + 0)  ||
    square(game_left + 380, game_btm + 10) ||
    square(game_left + 380, game_btm + 20) ||
    square(game_left + 380, game_btm + 30) ||
    // top bar
    square(game_left + 390, game_btm + 0)  ||
    square(game_left + 400, game_btm + 0)  ||
    // middle bar
    square(game_left + 390, game_btm + 15) ||
    // bottom bar
    square(game_left + 390, game_btm + 30) ||
    square(game_left + 400, game_btm + 30);

// ------------------------------------------------------------
// GAME OVER letters (blocky 10x10 squares)
// Positioned using GO_LEFT, GO_BTM
// G A M E   O V E R
// ------------------------------------------------------------

// G
wire go_g =
    // top row
    square(GO_LEFT + 0,  GO_BTM + 0)  ||
    square(GO_LEFT + 10, GO_BTM + 0)  ||
    square(GO_LEFT + 20, GO_BTM + 0)  ||
    // left column
    square(GO_LEFT + 0,  GO_BTM + 10) ||
    square(GO_LEFT + 0,  GO_BTM + 20) ||
    square(GO_LEFT + 0,  GO_BTM + 30) ||
    // bottom row
    square(GO_LEFT + 0,  GO_BTM + 30) ||
    square(GO_LEFT + 10, GO_BTM + 30) ||
    square(GO_LEFT + 20, GO_BTM + 30) ||
    // inner G bar
    square(GO_LEFT + 20, GO_BTM + 20) ||
    square(GO_LEFT + 10, GO_BTM + 20);

// A
wire go_a =
    // top row
    square(GO_LEFT + 40, GO_BTM + 0)  ||
    square(GO_LEFT + 60, GO_BTM + 0)  ||
    // upper middle
    square(GO_LEFT + 50, GO_BTM + 10) ||
    // legs
    square(GO_LEFT + 40, GO_BTM + 20) ||
    square(GO_LEFT + 40, GO_BTM + 30) ||
    square(GO_LEFT + 60, GO_BTM + 20) ||
    square(GO_LEFT + 60, GO_BTM + 30) ||
    // middle bar
    square(GO_LEFT + 50, GO_BTM + 20);

// M
wire go_m =
    // left vertical
    square(GO_LEFT + 80,  GO_BTM + 0)  ||
    square(GO_LEFT + 80,  GO_BTM + 10) ||
    square(GO_LEFT + 80,  GO_BTM + 20) ||
    square(GO_LEFT + 80,  GO_BTM + 30) ||
    // right vertical
    square(GO_LEFT + 110, GO_BTM + 0)  ||
    square(GO_LEFT + 110, GO_BTM + 10) ||
    square(GO_LEFT + 110, GO_BTM + 20) ||
    square(GO_LEFT + 110, GO_BTM + 30) ||
    // inner peaks
    square(GO_LEFT + 90,  GO_BTM + 10) ||
    square(GO_LEFT + 100, GO_BTM + 10);

// E
wire go_e1 =
    // vertical
    square(GO_LEFT + 130, GO_BTM + 0)  ||
    square(GO_LEFT + 130, GO_BTM + 10) ||
    square(GO_LEFT + 130, GO_BTM + 20) ||
    square(GO_LEFT + 130, GO_BTM + 30) ||
    // top bar
    square(GO_LEFT + 140, GO_BTM + 0)  ||
    square(GO_LEFT + 150, GO_BTM + 0)  ||
    // middle bar
    square(GO_LEFT + 140, GO_BTM + 15) ||
    // bottom bar
    square(GO_LEFT + 140, GO_BTM + 30) ||
    square(GO_LEFT + 150, GO_BTM + 30);

// O
wire go_o =
    // top row
    square(GO_LEFT + 190, GO_BTM + 0)  ||
    square(GO_LEFT + 200, GO_BTM + 0)  ||
    square(GO_LEFT + 210, GO_BTM + 0)  ||
    // sides
    square(GO_LEFT + 190, GO_BTM + 10) ||
    square(GO_LEFT + 190, GO_BTM + 20) ||
    square(GO_LEFT + 210, GO_BTM + 10) ||
    square(GO_LEFT + 210, GO_BTM + 20) ||
    // bottom row
    square(GO_LEFT + 190, GO_BTM + 30) ||
    square(GO_LEFT + 200, GO_BTM + 30) ||
    square(GO_LEFT + 210, GO_BTM + 30);

// V
wire go_v =
    // top left & right
    square(GO_LEFT + 230, GO_BTM + 0)  ||
    square(GO_LEFT + 250, GO_BTM + 0)  ||
    // middle
    square(GO_LEFT + 235, GO_BTM + 10) ||
    square(GO_LEFT + 245, GO_BTM + 10) ||
    // bottom point
    square(GO_LEFT + 240, GO_BTM + 20) ||
    square(GO_LEFT + 240, GO_BTM + 30);

// E (second E)
wire go_e2 =
    // vertical
    square(GO_LEFT + 270, GO_BTM + 0)  ||
    square(GO_LEFT + 270, GO_BTM + 10) ||
    square(GO_LEFT + 270, GO_BTM + 20) ||
    square(GO_LEFT + 270, GO_BTM + 30) ||
    // top bar
    square(GO_LEFT + 280, GO_BTM + 0)  ||
    square(GO_LEFT + 290, GO_BTM + 0)  ||
    // middle bar
    square(GO_LEFT + 280, GO_BTM + 15) ||
    // bottom bar
    square(GO_LEFT + 280, GO_BTM + 30) ||
    square(GO_LEFT + 290, GO_BTM + 30);

// R
wire go_r =
    // vertical spine
    square(GO_LEFT + 310, GO_BTM + 0)  ||
    square(GO_LEFT + 310, GO_BTM + 10) ||
    square(GO_LEFT + 310, GO_BTM + 20) ||
    square(GO_LEFT + 310, GO_BTM + 30) ||
    // upper loop (like P)
    square(GO_LEFT + 320, GO_BTM + 0)  ||
    square(GO_LEFT + 330, GO_BTM + 0)  ||
    square(GO_LEFT + 330, GO_BTM + 10) ||
    square(GO_LEFT + 320, GO_BTM + 20) ||
    // diagonal leg
    square(GO_LEFT + 320, GO_BTM + 30);

// Combine all GAME OVER pixels
wire game_over_letters = go_g | go_a | go_m | go_e1 | go_o | go_v | go_e2 | go_r;


wire number = one | two | three | four |
                five | six | seven | eight | nine;

// just the raw WHACKAMOLE bitmap
wire letters = w | h | a | c | k | a2 | m | o | l | e;


// ------------------------------------------------------------
// TODO (optional): header text "WHACK-A-MOLE" and numbers 1..9
// You can add simple block letters by checking (pixel_x, pixel_y)
// ranges inside the header area and setting them to white.
// ------------------------------------------------------------

// ------------------------------------------------------------
// Color generation
// ------------------------------------------------------------
always @(posedge pix_clk or posedge reset) begin
    if (reset) begin
        vgaR <= 0;
        vgaG <= 0;
        vgaB <= 0;

    end else if (!video_on) begin
        // outside visible area
        vgaR <= 0;
        vgaG <= 0;
        vgaB <= 0;

    end else if (in_wait) begin
        // waiting screen background + title
        if (letters) begin
            vgaR <= 4'hF;
            vgaG <= 4'hF;
            vgaB <= 4'hF;
        end else begin
            vgaR <= 4'h4;
            vgaG <= 4'h0;
            vgaB <= 4'h0;
        end

    end else if (in_done) begin
        // GAME OVER screen: blue background + white text
        if (game_over_letters) begin
            vgaR <= 4'hF;
            vgaG <= 4'hF;
            vgaB <= 4'hF;   // white letters
        end else begin
            vgaR <= 4'h0;
            vgaG <= 4'h0;
            vgaB <= 4'h4;   // dark blue background
        end

    end else if (in_header) begin
        // header during game
        if (letters) begin
            // draw "WHACKAMOLE" in white
            vgaR <= 4'hF;
            vgaG <= 4'hF;
            vgaB <= 4'hF;
        end else begin
            // blue header bar background
            vgaR <= 4'h0;
            vgaG <= 4'h0;
            vgaB <= 4'hF;
        end

    end else if (mole_pixel) begin
        // mole body – brown
        vgaR <= 4'h8;
        vgaG <= 4'h4;
        vgaB <= 4'h0;

    end else if (hole_pixel) begin
        // hole – black
        vgaR <= 4'h0;
        vgaG <= 4'h0;
        vgaB <= 4'h0;

    end else if (number) begin
        // numbers under holes
        vgaR <= 4'hF;
        vgaG <= 4'hF;
        vgaB <= 4'hF;

    end else if (letters) begin
        // (optional) letters drawn outside header/wait (probably won't happen)
        vgaR <= 4'hF;
        vgaG <= 4'hF;
        vgaB <= 4'hF;

    end else begin
        // background – dark green
        vgaR <= 4'h0;
        vgaG <= 4'h4;
        vgaB <= 4'h0;
    end
end


endmodule

// display the score on the ssd
//module ssd_display (

//);

module whackamole_top (
input        Clk100MHz,
//input        Reset,
//input        Ack,
input        BtnC, BtnU, BtnL, BtnR,BtnD,
output       Ld0, Ld1, Ld2, Ld3, Ld4,        
input        Sw0, Sw1, Sw2, Sw3, Sw4, Sw5, Sw6, Sw7, Sw8,

output       hSync,
output       vSync,
output [3:0] vgaR,
output [3:0] vgaG,
output [3:0] vgaB
//output reg [4:0] state

);

localparam
WAIT   = 5'b00001,
INI    = 5'b00010,
SPAWN  = 5'b00100,
HIT    = 5'b01000,
DONE   = 5'b10000;

wire [4:0] state;
wire in_wait;
wire in_done;
wire Ack, Reset;
assign Ack = BtnD;
assign Reset = BtnC;

assign Ld0 = (state == WAIT);
assign Ld1 = (state == INI);
assign Ld2 = (state == SPAWN);
assign Ld3 = (state == HIT);
assign Ld4 = (state == DONE);
assign in_wait = (state == WAIT);
assign in_done = (state == DONE);

wire pix_clk;
clk_div_25MHz clkdiv(
    .Clk100MHz(Clk100MHz),
    .Reset(Reset),
    .pix_clk(pix_clk)
);

wire        game_timer_out;
wire        mole_timer_out;
wire        start_game;
wire [6:0]  score;
wire [32:0] game_counter;
wire [31:0] mole_timer;
wire [3:0]  mole_index;

whack_a_mole game_core (
    .Clk(Clk100MHz),  // game logic usually runs at full 100MHz
    .Reset(Reset),
    .Ack(Ack),
    .BtnC(BtnC), .BtnU(BtnU), .BtnL(BtnL), .BtnR(BtnR),
    .Sw0(Sw0), .Sw1(Sw1), .Sw2(Sw2), .Sw3(Sw3), .Sw4(Sw4),
    .Sw5(Sw5), .Sw6(Sw6), .Sw7(Sw7), .Sw8(Sw8),
    .game_timer_out(game_timer_out),
    .mole_timer_out(mole_timer_out),
    .start_game(start_game),
    .score(score),
    .game_counter(game_counter),
    .mole_timer(mole_timer),
    .mole_index(mole_index),
    .state(state)
);

// VGA timing
wire [9:0] pixel_x;
wire [9:0] pixel_y;
wire       video_on;

vga_sync vga_timing (
    .clk(pix_clk),
    .reset(Reset),
    .hSync(hSync),
    .vSync(vSync),
    .video_on(video_on),
    .pixel_x(pixel_x),
    .pixel_y(pixel_y)
);

// VGA color generation
whackamole_video video_unit (
    .pix_clk(pix_clk),
    .reset(Reset),
    .video_on(video_on),
    .pixel_x(pixel_x),
    .pixel_y(pixel_y),
    .mole_index(mole_index),
    .in_wait(in_wait),
    .in_done(in_done),
    .vgaR(vgaR),
    .vgaG(vgaG),
    .vgaB(vgaB)
);


endmodule