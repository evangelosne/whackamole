`timescale 1 ns / 100 ps

module whack_a_mole (
input Ack, Clk, Reset,
input BtnC, BtnU, BtnL, BtnR,
input Sw0, Sw1, Sw2, Sw3, Sw4, Sw5, Sw6, Sw7, Sw8,
output reg game_timer_out,
output reg mole_timer_out,
output reg start_game,
output reg [6:0] score, // 7-bit counter
output reg [32:0] game_counter,
output reg [31:0] mole_timer,
output reg [3:0]  mole_index
);

reg [31:0] mole_max; 
parameter [32:0] game_max = 6000000000 - 1;

reg [4:0] state;

reg [3:0] random_num;
reg [3:0] sw_num;
reg [3:0] lfsr;

localparam
WAIT   = 5'b00001;
INI    = 5'b00010;
SPAWN  = 5'b00100;
HIT    = 5'b01000;
DONE   = 5'b10000;

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
        end else begin
            case (state)
                WAIT: begin
                    if (BtnC) state <= INI;
                    start_game <= 0;
                end

                INI: begin
                    if (BtnL) begin
                        mole_max   <= 3000000000 - 1; // easy
                        start_game <= 1;
                    end else if (BtnU) begin
                        mole_max   <= 2000000000 - 1; // medium
                        start_game <= 1;
                    end else if (BtnR) begin
                        mole_max   <= 1000000000 - 1; // hard
                        start_game <= 1;
                    end

                    if (BtnL || BtnU || BtnR)
                        state <= SPAWN;
                end

                SPAWN: begin
                    if (mole_timer_out) begin
                        if (lfsr > 4'd8) begin
                            random_num <= lfsr - 4'd9;
                            mole_index <= random_num;  
                        end else begin
                            random_num <= lfsr;          // 0-8
                            mole_index <= random_num;
                        end
                    end

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

                    if (game_timer_out)
                        state <= DONE;
                    else if (sw_num == random_num)
                        state <= HIT;
                end

                HIT: begin
                    score <= score + 1;

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
    output       hsync,
    output       vsync,
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
    assign hsync = ~((h_count >= HD + HF) && (h_count < HD + HF + HS));
    assign vsync = ~((v_count >= VD + VF) && (v_count < VD + VF + VS));

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

    output reg [3:0] vga_r,
    output reg [3:0] vga_g,
    output reg [3:0] vga_b
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
            vga_r <= 0;
            vga_g <= 0;
            vga_b <= 0;
        end else if (!video_on) begin
            // outside visible area
            vga_r <= 0;
            vga_g <= 0;
            vga_b <= 0;
        end else if (in_header) begin
            // blue header bar (like reference image top)
            vga_r <= 4'h0;
            vga_g <= 4'h0;
            vga_b <= 4'hF;
        end else if (mole_pixel) begin
            // mole body – brown
            vga_r <= 4'h8;
            vga_g <= 4'h4;
            vga_b <= 4'h0;
        end else if (hole_pixel) begin
            // hole – dark/black
            vga_r <= 4'h0;
            vga_g <= 4'h0;
            vga_b <= 4'h0;
        end else begin
            // background – dark green
            vga_r <= 4'h0;
            vga_g <= 4'h4;
            vga_b <= 4'h0;
        end
    end

endmodule



module whackamole_top (
    input        Clk100MHz,
    input        Reset,
    input        Ack,
    input        BtnC, BtnU, BtnL, BtnR,
    input        Sw0, Sw1, Sw2, Sw3, Sw4, Sw5, Sw6, Sw7, Sw8,

    output       Hsync,
    output       Vsync,
    output [3:0] VgaRed,
    output [3:0] VgaGreen,
    output [3:0] VgaBlue
);

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
        .mole_index(mole_index)
    );

    // VGA timing
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    wire       video_on;

    vga_sync vga_timing (
        .clk(pix_clk),
        .reset(Reset),
        .hsync(Hsync),
        .vsync(Vsync),
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
        .vga_r(VgaRed),
        .vga_g(VgaGreen),
        .vga_b(VgaBlue)
    );

endmodule
