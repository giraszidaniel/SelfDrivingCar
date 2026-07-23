`timescale 1ns / 1ps

module pwm_generate(
    input clk,             // 100 MHz órajel
    input [3:0] data,      // RPi-től érkező parancs
    output reg JA3,
    output reg JB0,
    output reg JB1,
    output reg JC0
    );

    reg [20:0] counter = 0;
    reg [16:0] ramp_counter = 0;         // 1 ms-os ütemező (100 000 ciklus)

    // Célértékek az egyes motorcsoportoknak
    reg [19:0] target_left;
    reg [19:0] target_right;

    // Tényleges, lágyított értékek az egyes motorcsoportoknak
    reg [19:0] actual_left = 100000;
    reg [19:0] actual_right = 100000;
    localparam RAMP_STEMP = 170;
    localparam border = 126490;

    // 1. Célértékek meghatározása az irányok alapján
    // Bal oldal: JA3, JB0 | Jobb oldal: JB1, JC0
    always @(*) begin
        case(data)
            4'd0:begin
                target_left = 100000;
                target_right = 100000;
            end
            4'd1: begin // Előre nagyon lassú
                target_left  = 100000;
                target_right = 100000;
            end
            4'd2: begin // Előre lassú
                target_left  = border;
                target_right = border;
            end
            4'd3: begin // Előre közepes
                target_left  = 130000;
                target_right = 130000;
            end
            4'd4: begin // Jobbra kanyarodik (Bal oldal megy, jobb oldal áll)
                target_left  = border;
                target_right = 100000; // Stop állapot a jobb oldalnak
            end
            4'd5: begin // Balra kanyarodik (Bal oldal áll, jobb oldal megy)
                target_left  = 100000; // Stop állapot a bal oldalnak
                target_right = border;
            end
            4'd6: begin
                target_left = border +200;
                target_right = border;
            end
            4'd7: begin
                target_left = border;
                target_right = border + 200;
            end
            default: begin // Stop (4'd0 és minden más)
                target_left  = 100000;
                target_right = 100000;
            end
        endcase
    end

    // 2. Különálló rámpagenerátorok a bal és jobb oldalra
    // A lépésközt 300-ra emeltem a gyorsabb, de még mindig lágy reakcióért!
    always @(posedge clk) begin
        if (ramp_counter >= 99999) begin
            ramp_counter <= 0;
            
            // --- BAL OLDAL RÁMPA ---
            if (actual_left < target_left) begin
                if (target_left - actual_left < RAMP_STEMP)
                    actual_left <= target_left;
                else
                    actual_left <= actual_left + RAMP_STEMP;
            end 
            else if (actual_left > target_left) begin
                if (actual_left - target_left < RAMP_STEMP)
                    actual_left <= target_left;
                else
                    actual_left <= actual_left - RAMP_STEMP;
            end

            // --- JOBB OLDAL RÁMPA ---
            if (actual_right < target_right) begin
                if (target_right - actual_right < RAMP_STEMP)
                    actual_right <= target_right;
                else
                    actual_right <= actual_right + RAMP_STEMP;
            end 
            else if (actual_right > target_right) begin
                if (actual_right - target_right < RAMP_STEMP)
                    actual_right <= target_right;
                else
                    actual_right <= actual_right - RAMP_STEMP;
            end

        end else begin
            ramp_counter <= ramp_counter + 1;
        end
    end

    // 3. Periódusszámláló (20 ms / 50 Hz)
    always @(posedge clk) begin
        if (counter >= 1999999) begin
            counter <= 0;
        end else begin
            counter <= counter + 1;
        end
    end

    // 4. Kimenetek közvetlen meghajtása a saját, lágyított számlálóik alapján
    // Így teljesen megszűnnek a logikai ütközések és az aszinkron ugrások!
  always @(*) begin
        // Bal oldali motorok (JA3, JB0)
        if (counter < actual_left) begin
            JA3 = 1;
            JB0 = 1;
        end else begin
            JA3 = 0;
            JB0 = 0;
        end

        // Jobb oldali motorok (JB1)
        if (counter < actual_right) begin
            JB1 = 1;
        end else begin
            JB1 = 0;
        end
        
        // Jobb oldali motor 2 (JC0) - Küszöbölés
        if (actual_right >= border) begin
            if (counter < actual_right)
                JC0 = 1;
            else
                JC0 = 0;
        end else begin
            if (counter < 100000)
                JC0 = 1;
            else
                JC0 = 0;
        end
    end // Ez az egyetlen end zárja le az always @(*) begin blokkot

endmodule