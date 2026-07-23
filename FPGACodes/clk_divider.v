`timescale 1ns / 1ps

module clk_divider(
    input clk,
    input clr,
    output clk50hz,
    output reg clk25mhz,
    output clk190hz,
    output reg clk400khz // Új 400 kHz-es kimenet
    );
    
    // 21 bites számláló a lassú órajeleknek (50Hz és 190Hz)
    reg [20:0] q;
    
    // Külön számláló a tiszta 25 MHz előállításához (100 MHz / 4)
    reg [1:0] clk25_cnt;

    // Külön számláló a 400 kHz előállításához (100 MHz / (2 * 400 kHz) = 125 ciklus)
    reg [6:0] clk400k_cnt; // 7 bit elég a 0..124 tartomány eléréséhez

    always @ (posedge clk or posedge clr)
    begin
        if (clr == 1) begin
            q           <= 0;
            clk25_cnt   <= 0;
            clk25mhz    <= 0;
            clk400k_cnt <= 0;
            clk400khz   <= 0;
        end else begin
            // A fő számláló növelése
            q <= q + 1;
            
            // A 25 MHz-es órajel generálása
            if (clk25_cnt == 1) begin
                clk25mhz  <= ~clk25mhz;
                clk25_cnt <= 0;
            end else begin
                clk25_cnt <= clk25_cnt + 1;
            end

            // A 400 kHz-es órajel generálása (125 órajelciklusonként billent át)
            if (clk400k_cnt == 124) begin
                clk400khz   <= ~clk400khz;
                clk400k_cnt <= 0;
            end else begin
                clk400k_cnt <= clk400k_cnt + 1;
            end
        end
    end

    // A lassú órajelek leosztása a fő számláló megfelelő bitjeiről
    assign clk190hz = q[18];
    assign clk50hz  = q[20];

endmodule