`timescale 1 ns / 100 ps

module whack_a_mole (Clk, Reset, score, game_counter, mole_timer, BtnC, BtnU, BtnL, BtnR
                        Sw0, Sw1, Sw2, Sw3, Sw4, Sw5, Sw6, Sw7, Sw8);

input Ack, Clk, Reset;
input BtnC, BtnU, BtnL, BtnR;
input Sw0, Sw1, Sw2, Sw3, Sw4, Sw5, Sw6, Sw7, Sw8;
output reg game_timer_out;
output reg mole_timer_out;
parameter mole_max; 
parameter game_max = 60000000000 - 1;
output start_game;

reg [4:0] state;
reg [6:0] score; // 7-bit counter
reg [31:0] game_counter;
reg [31:0] mole_timer;
integer random_num;
integer sw_num;
//assign one_sw_on = Sw1^Sw2^Sw3^Sw4^Sw5^Sw6^Sw7^Sw8;

localparam
WAIT   = 5'b00001;
INI    = 5'b00010;
SPAWN  = 5'b00100;
HIT    = 5'b01000;
DONE   = 5'b10000;

assign {} = state;

// game counter
always @(posedge Clk, posedge Reset)
    begin
        if (Reset) begin
            game_counter <= 0;
            game_timer_out <= 0;
        end
        else begin
            if (game_counter == game_max) begin
                game_timer_out <= 1;
            end
            else
                game_counter <= game_counter + 1;
        end
    end

// mole timer
always @(posedge Clk, posedge Reset)
    begin
        if (Reset) begin
            mole_timer <= 0;
            mole_timer_out <= 0;
        end
        else begin
            mole_timer <= mole_timer + 1;
            if (mole_timer == mole_max) begin
                mole_timer_out <= 1;
                mole_timer <= 0;
            end
        end
    end
                

always @(posedge Clk, posedge Reset)
    begin
        if (Reset)
            begin
                state <= INI;
                score <= 7'bXXXXXXX; 
                game_counter <= 0;
                mole_timer <= 0;
                mole_timer_out <= 0;
                game_timer_out <= 0;
                start_game <= 0;
            end
        else
            begin
                case (state)
                    WAIT :
                        //state transitions
                        if (BtnC) state <= INI;

                        //RTL
                        // nothing

                    INI :
                        // state transitions
                        if (BtnL^BtnR^BtnU) state <= SPAWN;

                        // RTL
                        if (BtnL) begin
                            mole_max <= 3000000000 - 1; // easy
                            start_game <= 1;
                        end
                        else if (BtnU) begin
                            mole_max <= 2000000000 - 1; // medium
                            start_game <= 1;
                        end
                        else if (BtnR) begin
                            mole_max <= 1000000000 - 1; // hard
                            start_game <= 1;
                        end
                        // if (!(BtnL^BtnR^BtnU)) // error handling

                    SPAWN :
                        // state transitions
                        if (sw_num == random_num) state <= HIT;
                        if (game_timer_out) state <= DONE;

                        // RTL
                        // changes mole
                        if (mole_timer_out)
                            random_num = $random % 10;

                        //mole appears VGA

                        // will only pick the first switch put up due to else if
                        if(Sw0) sw_num <= 0;
                        else if (Sw1) sw_num <= 1;
                        else if (Sw2) sw_num <= 2;
                        else if (Sw3) sw_num <= 3;
                        else if (Sw4) sw_num <= 4;
                        else if (Sw5) sw_num<= 5;
                        else if (Sw6) sw_num<= 6;
                        else if (Sw7) sw_num<= 7;
                        else if (Sw8) sw_num<= 8;
                        
                    HIT :
                        // state transitions
                        if (!game_timer_out) state <= SPAWN;
                        if (game_timer_out) state <= DONE;

                        // RTL
                        score <= score + 1;
                        //mole disappears VGA

                    DONE : 
                        // state transitions
                        if (Ack) state <= WAIT;

                        // display game over screen on VGA
            end
    end


endmodule