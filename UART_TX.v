`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/11/2024 03:42:29 PM
// Design Name: 
// Module Name: UART_TX
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
//////////////////////////////////////////////////////////////////////////////////
// Set Parameter CLKS_PER_BIT as follows:
// CLKS_PER_BIT = (Frequency of input_Clock)/(Frequency of UART)
// Example: 50 MHz Clock, 9600 baud UART
// (50000000)/(9600) = 5208
// clk must be 2 time or more faster then the baud rate
module UART_TX #(parameter CLKS_FREQ = 50000000,
                 parameter BAUD_RATE = 9600) 
    (
    input clk,
    input flag_tx,
    input [7:0] TX_Byte,
    output Tx,
    output Busy 
    );
    
   localparam CLKS_PER_BIT = CLKS_FREQ/BAUD_RATE;  
  //STATE Decleration

  localparam IDLE                = 2'b00,
             TX_START_DATA_STOP  = 2'b01;
  //Signal Decleration

  reg [$clog2(CLKS_PER_BIT):0] t_Clock_Count = 0;
  reg [                   3:0] t_Bit_Index   = 0; //8 bits total
  reg [                   9:0] t_TX_Byte     = 0;
  reg [                   1:0] STATE         = 0;
  wire                         r_TX_DV;

assign r_TX_DV = (STATE == IDLE)? 1'b1 : t_TX_Byte[t_Bit_Index];  
assign Busy    = (STATE == IDLE)? 1'b0 : 1'b1;  
assign Tx      =  r_TX_DV;  
  // Purpose: Control RX state machine
  always @(posedge clk)
    begin     
     t_Clock_Count <= 0;
      case (STATE)
        IDLE :
          begin
            t_TX_Byte <= {1'b1,TX_Byte,1'b0}; 
            t_Bit_Index   <= 0;
            if (flag_tx  == 1'b1)          // Flag Receive
              STATE <= TX_START_DATA_STOP;
            else
              STATE <= IDLE;
          end  
          
        // Wait CLKS_PER_BIT-1 clock cycles to sample serial data
        TX_START_DATA_STOP :
          begin
            if (t_Clock_Count < CLKS_PER_BIT-1)
              begin
                t_Clock_Count <= t_Clock_Count + 1;
                STATE         <= TX_START_DATA_STOP;
              end
            else
              begin
                // Check if we have send all bits including start and stop bits
                if (t_Bit_Index < 9)
                  begin
                    t_Bit_Index <= t_Bit_Index + 1;
                    STATE       <= TX_START_DATA_STOP;
                  end
                else
                  begin
                    t_Bit_Index <= 0;
                    STATE       <= IDLE;
                  end
              end
          end // case: TX_DATA
          
        default :
          STATE <= IDLE;
      endcase
    end
endmodule

