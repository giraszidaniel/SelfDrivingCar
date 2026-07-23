`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.06.2026 11:12:11
// Design Name: 
// Module Name: x7segb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module x7segb(
    input [15:0] x,
    input cclk,
    input clr,
    output reg [6:0] a_to_g,
    output reg [3:0] an,
    output dp
    );
    
    reg [1:0] s;
    reg [3:0] digit;
    wire [3:0] aen;
    assign dp = 1;
    assign aen[3] = x[15] | x[14] | x[13] | x[12];
    assign aen[2] = x[15] | x[14] | x[13] | x[12]
                    | x[11] | x[10] | x[9] | x[8];
     assign aen[1] = x[15] | x[14] | x[13] | x[12]
                    | x[11] | x[10] | x[9] | x[8]
                    | x[7] | x[6] | x[5] | x[4];
    assign aen[0] = 1;
    always @(*)
    case(s)
        2'd0: digit = x[3:0];
        2'd1: digit = x[7:4];
        2'd2: digit = x[11:8];
        2'd3: digit = x[15:12];
        default: digit = x[3:0];
    endcase
    always @(*) begin
        case(digit)
            // Kódolás: g f e d c b a
            4'h0: a_to_g = 7'b1000000;
            4'h1: a_to_g = 7'b1111001;
            4'h2: a_to_g = 7'b0100100;
            4'h3: a_to_g = 7'b0110000;
            4'h4: a_to_g = 7'b0011001;
            4'h5: a_to_g = 7'b0010010;
            4'h6: a_to_g = 7'b0000010;
            4'h7: a_to_g = 7'b1111000;
            4'h8: a_to_g = 7'b0000000;
            4'h9: a_to_g = 7'b0010000;
            4'hA: a_to_g = 7'b0001000;
            4'hB: a_to_g = 7'b0000011;
            4'hC: a_to_g = 7'b1000110;
            4'hD: a_to_g = 7'b0100001;
            4'hE: a_to_g = 7'b0000110;
            4'hF: a_to_g = 7'b0001110;
            default: a_to_g = 7'b1000000; // Alapértelmezetten '0'
        endcase
        end
always @(*) begin
    an = 4'b1111;         // Alaphelyzetben minden kijelző ki van kapcsolva (aktív alacsony)
    if (aen[s] == 1) begin
        an[s] = 0;        // Csak az éppen aktuális 's' indexű kijelzőt kapcsoljuk be
    end
end

// Második always blokk: Szekvenciális hálózat az index (s) léptetéséhez
always @(posedge cclk or posedge clr) begin
    if (clr == 1) begin
        s <= 2'b00;       // Reset esetén visszaáll az első kijelzőre
    end else begin
        s <= s + 1;       // Minden órajelre vált a következő kijelzőre (0->1->2->3->0...)
    end
end
endmodule
