`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.06.2026 08:58:07
// Design Name: 
// Module Name: uart_rx
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


module uart_rx(
    input RxD,
    input clk,
    input clr,
    input rdrf_clr,
    output reg rdrf,
    output [7:0] rx_data,
    output reg FE
    );
    
    reg [2:0] state;
    parameter mark = 3'b000, start = 3'b001, delay = 3'b010, shift = 3'b011, stop = 3'b100;
    reg [7:0] rxbuff;
    reg [11:0] baud_count;
    reg [3:0] bit_count;
    reg rdrf_set, fe_set, cclr, cclr8, rxload;
    parameter bit_time = 12'hA28;
    parameter half_bit_time = 12'h514;
    assign rx_data = rxbuff;
    
    always @(posedge clk or posedge clr or posedge rdrf_clr)
    begin
    if (clr == 1)
    begin
        state <= mark;
        rxbuff <= 0;
        baud_count <= 0;
        bit_count <= 0;
        rdrf <= 0;
        FE <= 0;
    end
    else
    begin
        if(rdrf_clr == 1)
        begin
            rdrf <= 0;
        end
        else
        begin
            case(state)
                mark:
                    begin
                        bit_count <= 0;
                        baud_count <= 0;
                        if(RxD == 1)
                        begin
                            state <= mark;
                        end
                        else
                        begin
                            FE <= 0;
                            state <= start;
                        end
                    end
                 start: 
                        if(baud_count >= half_bit_time)
                        begin
                            baud_count <= 0;
                            state <= delay;
                        end
                        else
                        begin
                            baud_count <= baud_count +1;
                            state <= start;
                        end
                 delay:
                        if(baud_count >= bit_time)
                        begin
                            baud_count <= 0;
                            if (bit_count < 8)
                            begin
                                state <= shift;
                            end
                            else
                            begin
                                state <= stop;
                            end
                        end
                        else begin 
                            baud_count <= baud_count +1;
                            state <= delay;
                        end
                 shift:
                        begin
                            rxbuff[7] <= RxD;
                            rxbuff[6:0] <= rxbuff[7:1];
                            bit_count <= bit_count +1;
                            state <= delay;
                        end
                stop:
                        begin
                            rdrf <= 1;
                            if(RxD == 0)
         
                                FE <= 1;
                            
                            else 
                                FE <= 0;
                                state <= mark;
                            
                        end
            endcase
        end
    end
    end
    
endmodule
