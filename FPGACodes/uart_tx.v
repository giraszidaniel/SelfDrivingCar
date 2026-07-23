`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.06.2026 08:57:43
// Design Name: 
// Module Name: uart_tx
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


module uart_tx(
    input clk,
    input clr,
    input  [7:0] tx_data,
    input wire ready,
    output reg TxD,
    output reg tdre
    );
    reg [2:0] state;
    parameter mark = 3'b000, start = 3'b001, delay = 3'b010, shift = 3'b011, stop = 3'b100;
    reg [7:0] txbuff;
    reg [11:0] baud_count;
    reg [3:0] bit_count;
    parameter bit_time = 12'hA28;
    
    always @ (posedge clk or posedge clr)
    begin
        if (clr ==1)
        begin
            state<=mark;
            txbuff <= 0;
            baud_count<= 0;
            bit_count<= 0;
            TxD <= 1;
        end
        else begin
        case(state)
            mark:
            begin
                    bit_count <= 0;
                    tdre <= 1;
                    if(ready == 0)
                    begin
                        state <= mark;
                        txbuff <= tx_data + 8'h30;
                    end
                    else
                    begin
                    baud_count <= 0;
                    state<= start;
                    end
            end
            start:
            begin
                        baud_count <= 3'h000;
                        TxD <= 0;
                        tdre <= 0;
                        state <= delay;
            end
            delay:
                begin
                    tdre <= 0;
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
                    else
                    begin
                        baud_count <= baud_count +1;
                        state <= delay;
                    end
                end
            shift:
            begin
                tdre <= 0;
                TxD <= txbuff[0];
                txbuff[6:0] <= txbuff[7:1];
                bit_count <= bit_count +1;
                state <= delay;
            end
            stop:
            begin
                tdre <= 0;
                TxD <= 1;
                if (baud_count >= bit_time)
                begin
                    baud_count <= 0;
                    state <= mark;
                end
                else
                begin
                    baud_count <= baud_count +1;
                    state <= stop;
                end
            end
            endcase 
        end

    end
endmodule
