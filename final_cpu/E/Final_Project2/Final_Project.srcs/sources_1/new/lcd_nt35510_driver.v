// =========================================================
// NT35510 LCD Driver (16-bit 8080 interface)
// - Includes init sequence + full-frame streaming (800x480)
// - A-version interface: accepts live game signals and
//   snapshots them internally at frame start.
// =========================================================
module lcd_nt35510_driver #(
    parameter H_RES = 800,
    parameter V_RES = 480
)(
    input  wire        clk,
    input  wire        rst_n,

    // LCD Interface (NT35510, 16bit 8080)
    output reg  [15:0] lcd_db,
    output reg         lcd_wr,
    output reg         lcd_rs,     // 0:Command (Index), 1:Data (Parameter)
    output wire        lcd_cs,
    output wire        lcd_rd,
    output reg         lcd_rst,
    output wire        lcd_bl_ctr,

    // Debug/status (for LEDs etc.)
    output reg  [3:0]  status,

    // ---- game signals (live inputs, internally snapshotted) ----
    input  wire [1:0]  car_lane,
    input  wire [1:0]  obs_lane,
    input  wire [9:0]  obs_x,
    input  wire [1:0]  bonus_lane,
    input  wire [9:0]  bonus_x,
    input  wire        bonus_active,
    input  wire        game_over,
    input  wire        paused
);

    // LCD fixed signals
    assign lcd_cs     = 1'b0;  // always selected
    assign lcd_rd     = 1'b1;  // no read
    assign lcd_bl_ctr = 1'b1;  // backlight on

    // =========================================================
    // 1) LCD init command table (NT35510 16-bit, landscape 800x480)
    // =========================================================
    localparam [16:0] CMD_END = 17'h1_FFFF;
    reg [16:0] cmds [0:128];

    initial begin
        // --- Page 0 unlock ---
        cmds[0]  = {1'b0, 16'hF000}; cmds[1]  = {1'b1, 16'h0055};
        cmds[2]  = {1'b0, 16'hF001}; cmds[3]  = {1'b1, 16'h00AA};
        cmds[4]  = {1'b0, 16'hF002}; cmds[5]  = {1'b1, 16'h0052};
        cmds[6]  = {1'b0, 16'hF003}; cmds[7]  = {1'b1, 16'h0008};
        cmds[8]  = {1'b0, 16'hF004}; cmds[9]  = {1'b1, 16'h0001};

        // --- Page 1 unlock ---
        cmds[10] = {1'b0, 16'hF000}; cmds[11] = {1'b1, 16'h0055};
        cmds[12] = {1'b0, 16'hF001}; cmds[13] = {1'b1, 16'h00AA};
        cmds[14] = {1'b0, 16'hF002}; cmds[15] = {1'b1, 16'h0052};
        cmds[16] = {1'b0, 16'hF003}; cmds[17] = {1'b1, 16'h0008};
        cmds[18] = {1'b0, 16'hF004}; cmds[19] = {1'b1, 16'h0001};

        // --- Power config (simplified) ---
        cmds[20] = {1'b0, 16'hB000}; cmds[21] = {1'b1, 16'h0000};
        cmds[22] = {1'b0, 16'hB001}; cmds[23] = {1'b1, 16'h0000};
        cmds[24] = {1'b0, 16'hB002}; cmds[25] = {1'b1, 16'h0000};

        cmds[26] = {1'b0, 16'hB600}; cmds[27] = {1'b1, 16'h0024};
        cmds[28] = {1'b0, 16'hB601}; cmds[29] = {1'b1, 16'h0024};
        cmds[30] = {1'b0, 16'hB602}; cmds[31] = {1'b1, 16'h0024};

        cmds[32] = {1'b0, 16'hB700}; cmds[33] = {1'b1, 16'h0024};
        cmds[34] = {1'b0, 16'hB701}; cmds[35] = {1'b1, 16'h0024};
        cmds[36] = {1'b0, 16'hB702}; cmds[37] = {1'b1, 16'h0024};

        // --- Sleep Out ---
        cmds[38] = {1'b0, 16'h1100};
        cmds[39] = {1'b1, 16'h0000}; // placeholder -> delay after Sleep Out

        // --- Memory Access Control (landscape) ---
        cmds[40] = {1'b0, 16'h3600}; cmds[41] = {1'b1, 16'h00A0};

        // --- Pixel Format (RGB565) ---
        cmds[42] = {1'b0, 16'h3A00}; cmds[43] = {1'b1, 16'h0055};

        // --- Column Address Set (X: 0~799) ---
        cmds[44] = {1'b0, 16'h2A00}; cmds[45] = {1'b1, 16'h0000};
        cmds[46] = {1'b0, 16'h2A01}; cmds[47] = {1'b1, 16'h0000};
        cmds[48] = {1'b0, 16'h2A02}; cmds[49] = {1'b1, 16'h0003};
        cmds[50] = {1'b0, 16'h2A03}; cmds[51] = {1'b1, 16'h001F}; // 799

        // --- Page Address Set (Y: 0~479) ---
        cmds[52] = {1'b0, 16'h2B00}; cmds[53] = {1'b1, 16'h0000};
        cmds[54] = {1'b0, 16'h2B01}; cmds[55] = {1'b1, 16'h0000};
        cmds[56] = {1'b0, 16'h2B02}; cmds[57] = {1'b1, 16'h0001};
        cmds[58] = {1'b0, 16'h2B03}; cmds[59] = {1'b1, 16'h00DF}; // 479

        // --- Display ON ---
        cmds[60] = {1'b0, 16'h2900};

        cmds[61] = CMD_END;
    end

    // =========================================================
    // 2) LCD state machine (init -> continuous full refresh)
    // =========================================================
    reg [3:0]  state;
    reg [31:0] timer;
    reg [8:0]  idx;

    reg [9:0]  px_x, px_y;
    reg [15:0] color;
    reg [1:0]  wr_phase;
    reg [4:0]  wr_cnt;

    // Frame snapshot registers (avoid tearing)
    reg [1:0] car_lane_r, obs_lane_r, bonus_lane_r;
    reg [9:0] obs_x_r, bonus_x_r;
    reg       bonus_active_r;
    reg       game_over_r;
    reg       paused_r;

    // Colors RGB565
    localparam [15:0] RED    = 16'hF800;
    localparam [15:0] GREEN  = 16'h07E0;
    localparam [15:0] BLUE   = 16'h001F;
    localparam [15:0] WHITE  = 16'hFFFF;
    localparam [15:0] BLACK  = 16'h0000;
    localparam [15:0] YELLOW = 16'hFFE0;

    // Extra colors: pixel car & panel
    localparam [15:0] CAR_BODY   = 16'hFCA0;
    localparam [15:0] CAR_WINDOW = 16'h07FF;
    localparam [15:0] CAR_WHEEL  = 16'h0000;
    localparam [15:0] PANEL_BG   = 16'h2104;
    localparam [15:0] PANEL_TEXT = 16'hFFFF;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= 0;
            timer    <= 0;
            idx      <= 0;

            lcd_rst  <= 1'b1;
            lcd_wr   <= 1'b1;
            lcd_rs   <= 1'b0;
            lcd_db   <= 16'h0000;

            px_x     <= 0;
            px_y     <= 0;
            wr_phase <= 0;
            wr_cnt   <= 0;

            status   <= 0;

            // snapshot init
            car_lane_r     <= 0;
            obs_lane_r     <= 0;
            bonus_lane_r   <= 0;
            obs_x_r        <= 0;
            bonus_x_r      <= 0;
            bonus_active_r <= 0;
            game_over_r    <= 0;
            paused_r       <= 0;

        end else begin
            case (state)

                // 0: power-on delay
                0: begin
                    status <= 4'd0;
                    if (timer < 500_000) timer <= timer + 1;
                    else begin timer <= 0; state <= 1; end
                end

                // 1: hardware reset pulse low
                1: begin
                    status  <= 4'd1;
                    lcd_rst <= 1'b0;
                    if (timer < 200_000) timer <= timer + 1;
                    else begin lcd_rst <= 1'b1; timer <= 0; state <= 2; end
                end

                // 2: post-reset delay
                2: begin
                    status <= 4'd3;
                    if (timer < 2_000_000) timer <= timer + 1;
                    else begin timer <= 0; idx <= 0; state <= 3; end
                end

                // 3: send init commands
                3: begin
                    status <= 4'd2;
                    if (cmds[idx] == CMD_END) begin
                        state    <= 5; // init done -> go refresh
                        wr_phase <= 0;
                    end else if (idx == 39) begin
                        // placeholder for Sleep Out delay (after cmds[38])
                        if (timer < 10_000_000) timer <= timer + 1; // 100ms @100MHz
                        else begin timer <= 0; idx <= idx + 1; end
                    end else begin
                        lcd_rs <= cmds[idx][16];
                        lcd_db <= cmds[idx][15:0];
                        lcd_wr <= 1'b0;
                        state  <= 4;
                    end
                end

                // 4: hold WR low one cycle then release
                4: begin
                    lcd_wr <= 1'b1;
                    idx    <= idx + 1;
                    state  <= 3;
                end

                // 5: send Write RAM (0x2C00) then snapshot & start pixel stream
                5: begin
                    status <= 4'd4;
                    case (wr_phase)
                        0: begin
                            lcd_rs   <= 1'b0;       // command
                            lcd_db   <= 16'h2C00;   // write RAM
                            lcd_wr   <= 1'b0;
                            wr_phase <= 1;
                            wr_cnt   <= 0;
                        end
                        1: begin
                            wr_cnt <= wr_cnt + 1;
                            if (wr_cnt == 5) begin
                                lcd_wr   <= 1'b1;
                                wr_phase <= 2;
                            end
                        end
                        2: begin
                            // snapshot at frame start
                            car_lane_r     <= car_lane;
                            obs_lane_r     <= obs_lane;
                            obs_x_r        <= obs_x;
                            bonus_lane_r   <= bonus_lane;
                            bonus_x_r      <= bonus_x;
                            bonus_active_r <= bonus_active;
                            game_over_r    <= game_over;
                            paused_r       <= paused;

                            state    <= 6;
                            px_x     <= 0;
                            px_y     <= 0;
                            wr_phase <= 0;
                        end
                    endcase
                end

                // 6: stream pixels (full frame)
                6: begin
                    status <= 4'd4;
                    case (wr_phase)

                        // phase0: compute pixel color & output it
                        0: begin
                            lcd_rs <= 1'b1; // data

                            // default background
                            color <= BLACK;

                            // lane separator
                            if (px_y == 10'd160 || px_y == 10'd320)
                                color <= WHITE;

                            // pixel car (x 100~180), head to right
                            if (px_x >= 100 && px_x <= 180) begin
                                case (car_lane_r)
                                    2'd0: if (px_y >= 50 && px_y <= 110) begin
                                        if ( ((px_x >= 100 && px_x <= 105) ||
                                              (px_x >= 175 && px_x <= 180)) &&
                                             (px_y >= 58  && px_y <= 102) )
                                            color <= CAR_WHEEL;
                                        else if (px_x >= 150 && px_x <= 172 &&
                                                 px_y >= 70  && px_y <= 90)
                                            color <= CAR_WINDOW;
                                        else if (px_x >= 105 && px_x <= 175)
                                            color <= CAR_BODY;
                                    end

                                    2'd1: if (px_y >= 210 && px_y <= 270) begin
                                        if ( ((px_x >= 100 && px_x <= 105) ||
                                              (px_x >= 175 && px_x <= 180)) &&
                                             (px_y >= 218 && px_y <= 262) )
                                            color <= CAR_WHEEL;
                                        else if (px_x >= 150 && px_x <= 172 &&
                                                 px_y >= 230 && px_y <= 250)
                                            color <= CAR_WINDOW;
                                        else if (px_x >= 105 && px_x <= 175)
                                            color <= CAR_BODY;
                                    end

                                    2'd2: if (px_y >= 370 && px_y <= 430) begin
                                        if ( ((px_x >= 100 && px_x <= 105) ||
                                              (px_x >= 175 && px_x <= 180)) &&
                                             (px_y >= 378 && px_y <= 422) )
                                            color <= CAR_WHEEL;
                                        else if (px_x >= 150 && px_x <= 172 &&
                                                 px_y >= 390 && px_y <= 410)
                                            color <= CAR_WINDOW;
                                        else if (px_x >= 105 && px_x <= 175)
                                            color <= CAR_BODY;
                                    end
                                endcase
                            end

                            // obstacle (blue)
                            if (px_x >= obs_x_r && px_x <= obs_x_r + 40) begin
                                if (obs_lane_r == 0 && px_y < 160)                 color <= BLUE;
                                if (obs_lane_r == 1 && px_y >= 160 && px_y < 320) color <= BLUE;
                                if (obs_lane_r == 2 && px_y >= 320)               color <= BLUE;
                            end

                            // bonus (yellow)
                            if (bonus_active_r &&
                                px_x >= bonus_x_r && px_x <= bonus_x_r + 40) begin
                                if (bonus_lane_r == 0 && px_y < 160)                 color <= YELLOW;
                                if (bonus_lane_r == 1 && px_y >= 160 && px_y < 320) color <= YELLOW;
                                if (bonus_lane_r == 2 && px_y >= 320)               color <= YELLOW;
                            end

                            // panel + pixel text
                            if (game_over_r || paused_r) begin
                                // panel background + border
                                if (px_x >= 200 && px_x <= 600 &&
                                    px_y >= 160 && px_y <= 320) begin
                                    if (px_x == 200 || px_x == 600 ||
                                        px_y == 160 || px_y == 320)
                                        color <= WHITE;
                                    else
                                        color <= PANEL_BG;
                                end

                                // GAME OVER
                                if (game_over_r) begin
                                    // G
                                    if (px_x >= 220 && px_x < 260 &&
                                        px_y >= 180 && px_y < 220) begin
                                        if ( (px_y >= 180 && px_y <= 184 && px_x >= 224 && px_x <= 256) ||
                                             (px_y >= 216 && px_y <= 220 && px_x >= 224 && px_x <= 256) ||
                                             (px_x >= 220 && px_x <= 224 && px_y >= 184 && px_y <= 216) ||
                                             (px_x >= 252 && px_x <= 256 && px_y >= 200 && px_y <= 216) ||
                                             (px_y >= 198 && px_y <= 202 && px_x >= 236 && px_x <= 256) )
                                            color <= PANEL_TEXT;
                                    end
                                    // A
                                    if (px_x >= 270 && px_x < 310 &&
                                        px_y >= 180 && px_y < 220) begin
                                        if ( (px_y >= 180 && px_y <= 184 && px_x >= 274 && px_x <= 306) ||
                                             (px_y >= 198 && px_y <= 202 && px_x >= 274 && px_x <= 306) ||
                                             (px_x >= 270 && px_x <= 274 && px_y >= 184 && px_y <= 220) ||
                                             (px_x >= 306 && px_x <= 310 && px_y >= 184 && px_y <= 220) )
                                            color <= PANEL_TEXT;
                                    end
                                    // M
                                    if (px_x >= 320 && px_x < 360 &&
                                        px_y >= 180 && px_y < 220) begin
                                        if ( (px_x >= 320 && px_x <= 324 && px_y >= 180 && px_y <= 220) ||
                                             (px_x >= 356 && px_x <= 360 && px_y >= 180 && px_y <= 220) ||
                                             (px_x >= 332 && px_x <= 336 && px_y >= 188 && px_y <= 196) ||
                                             (px_x >= 344 && px_x <= 348 && px_y >= 188 && px_y <= 196) )
                                            color <= PANEL_TEXT;
                                    end
                                    // E
                                    if (px_x >= 370 && px_x < 410 &&
                                        px_y >= 180 && px_y < 220) begin
                                        if ( (px_x >= 370 && px_x <= 374 && px_y >= 180 && px_y <= 220) ||
                                             (px_y >= 180 && px_y <= 184 && px_x >= 374 && px_x <= 406) ||
                                             (px_y >= 198 && px_y <= 202 && px_x >= 374 && px_x <= 400) ||
                                             (px_y >= 216 && px_y <= 220 && px_x >= 374 && px_x <= 406) )
                                            color <= PANEL_TEXT;
                                    end

                                    // O
                                    if (px_x >= 250 && px_x < 290 &&
                                        px_y >= 240 && px_y < 280) begin
                                        if ( (px_y >= 240 && px_y <= 244 && px_x >= 254 && px_x <= 286) ||
                                             (px_y >= 276 && px_y <= 280 && px_x >= 254 && px_x <= 286) ||
                                             (px_x >= 250 && px_x <= 254 && px_y >= 244 && px_y <= 276) ||
                                             (px_x >= 286 && px_x <= 290 && px_y >= 244 && px_y <= 276) )
                                            color <= PANEL_TEXT;
                                    end
                                    // V
                                    if (px_x >= 300 && px_x < 340 &&
                                        px_y >= 240 && px_y < 280) begin
                                        if ( (px_x >= 300 && px_x <= 304 && px_y >= 240 && px_y <= 268) ||
                                             (px_x >= 336 && px_x <= 340 && px_y >= 240 && px_y <= 268) ||
                                             (px_x >= 312 && px_x <= 328 && px_y >= 268 && px_y <= 280) )
                                            color <= PANEL_TEXT;
                                    end
                                    // E
                                    if (px_x >= 350 && px_x < 390 &&
                                        px_y >= 240 && px_y < 280) begin
                                        if ( (px_x >= 350 && px_x <= 354 && px_y >= 240 && px_y <= 280) ||
                                             (px_y >= 240 && px_y <= 244 && px_x >= 354 && px_x <= 386) ||
                                             (px_y >= 258 && px_y <= 262 && px_x >= 354 && px_x <= 380) ||
                                             (px_y >= 276 && px_y <= 280 && px_x >= 354 && px_x <= 386) )
                                            color <= PANEL_TEXT;
                                    end
                                    // R
                                    if (px_x >= 400 && px_x < 440 &&
                                        px_y >= 240 && px_y < 280) begin
                                        if ( (px_x >= 400 && px_x <= 404 && px_y >= 240 && px_y <= 280) ||
                                             (px_y >= 240 && px_y <= 244 && px_x >= 404 && px_x <= 436) ||
                                             (px_y >= 258 && px_y <= 262 && px_x >= 404 && px_x <= 432) ||
                                             (px_x >= 432 && px_x <= 436 && px_y >= 244 && px_y <= 262) ||
                                             (px_x >= 420 && px_x <= 436 && px_y >= 262 && px_y <= 280) )
                                            color <= PANEL_TEXT;
                                    end
                                end

                                // PAUSE (only if paused and not game_over)
                                if (paused_r && !game_over_r) begin
                                    // P
                                    if (px_x >= 260 && px_x < 300 &&
                                        px_y >= 200 && px_y < 260) begin
                                        if ( (px_x >= 260 && px_x <= 264 && px_y >= 200 && px_y <= 260) ||
                                             (px_y >= 200 && px_y <= 204 && px_x >= 264 && px_x <= 296) ||
                                             (px_y >= 228 && px_y <= 232 && px_x >= 264 && px_x <= 296) ||
                                             (px_x >= 296 && px_x <= 300 && px_y >= 204 && px_y <= 228) )
                                            color <= PANEL_TEXT;
                                    end
                                    // A
                                    if (px_x >= 310 && px_x < 350 &&
                                        px_y >= 200 && px_y < 260) begin
                                        if ( (px_y >= 200 && px_y <= 204 && px_x >= 314 && px_x <= 346) ||
                                             (px_y >= 228 && px_y <= 232 && px_x >= 314 && px_x <= 346) ||
                                             (px_x >= 310 && px_x <= 314 && px_y >= 204 && px_y <= 260) ||
                                             (px_x >= 346 && px_x <= 350 && px_y >= 204 && px_y <= 260) )
                                            color <= PANEL_TEXT;
                                    end
                                    // U
                                    if (px_x >= 360 && px_x < 400 &&
                                        px_y >= 200 && px_y < 260) begin
                                        if ( (px_x >= 360 && px_x <= 364 && px_y >= 200 && px_y <= 252) ||
                                             (px_x >= 396 && px_x <= 400 && px_y >= 200 && px_y <= 252) ||
                                             (px_y >= 252 && px_y <= 256 && px_x >= 364 && px_x <= 396) )
                                            color <= PANEL_TEXT;
                                    end
                                    // S
                                    if (px_x >= 410 && px_x < 450 &&
                                        px_y >= 200 && px_y < 260) begin
                                        if ( (px_y >= 200 && px_y <= 204 && px_x >= 414 && px_x <= 446) ||
                                             (px_y >= 228 && px_y <= 232 && px_x >= 414 && px_x <= 446) ||
                                             (px_y >= 256 && px_y <= 260 && px_x >= 414 && px_x <= 446) ||
                                             (px_x >= 410 && px_x <= 414 && px_y >= 204 && px_y <= 228) ||
                                             (px_x >= 446 && px_x <= 450 && px_y >= 232 && px_y <= 256) )
                                            color <= PANEL_TEXT;
                                    end
                                    // E
                                    if (px_x >= 460 && px_x < 500 &&
                                        px_y >= 200 && px_y < 260) begin
                                        if ( (px_x >= 460 && px_x <= 464 && px_y >= 200 && px_y <= 260) ||
                                             (px_y >= 200 && px_y <= 204 && px_x >= 464 && px_x <= 496) ||
                                             (px_y >= 228 && px_y <= 232 && px_x >= 464 && px_x <= 492) ||
                                             (px_y >= 256 && px_y <= 260 && px_x >= 464 && px_x <= 496) )
                                            color <= PANEL_TEXT;
                                    end
                                end
                            end

                            // output pixel
                            lcd_db   <= color;
                            lcd_wr   <= 1'b0;
                            wr_phase <= 1;
                            wr_cnt   <= 0;
                        end

                        // phase1: hold WR low
                        1: begin
                            wr_cnt <= wr_cnt + 1;
                            if (wr_cnt == 4) begin
                                lcd_wr   <= 1'b1;
                                wr_phase <= 2;
                            end
                        end

                        // phase2: advance coordinates
                        2: begin
                            if (px_x < H_RES-1) begin
                                px_x <= px_x + 1;
                            end else begin
                                px_x <= 0;
                                if (px_y < V_RES-1) begin
                                    px_y <= px_y + 1;
                                end else begin
                                    px_y  <= 0;
                                    state <= 5; // frame done -> next 0x2C
                                end
                            end
                            wr_phase <= 0;
                        end

                    endcase
                end

                default: state <= 0;

            endcase
        end
    end

endmodule
