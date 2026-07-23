`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.06.2026 17:06:03
// Design Name: 
// Module Name: test_rx_ctrl
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

module test_rx_ctrl(input wire clk, clr, rdrf, output reg rdrf_clr);

    reg state;
    parameter wtrdrf = 0, load = 1;
    
    always @(posedge clk or posedge clr)
    begin
        if(clr == 1)
        begin
            state <= wtrdrf;
            rdrf_clr <= 0;
        end
        else
            case (state)
                wtrdrf: // wait for rdrf
                    begin
                        rdrf_clr <= 0;
                        if(rdrf == 0)
                            state <= wtrdrf;
                        else
                            state <= load;
                    end
                load:
                    begin
                        rdrf_clr <= 1;
                        state <= wtrdrf;
                    end
            endcase
    end
endmodule