`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/11/2024 03:43:23 PM
// Design Name: 
// Module Name: UART_RX
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
module UART_RX #(parameter CLKS_FREQ = 50000000,
                 parameter BAUD_RATE = 9600) 
    (
        input        clk    ,
        input        Rx     ,
        output       flag_Rx,
        output [7:0] RX_Byte
    );

   localparam CLKS_PER_BIT = CLKS_FREQ/BAUD_RATE;  
  //STATE Decleration

  localparam IDLE         = 3'b000,
             START        = 3'b001,
             RX_DATA      = 3'b010,
             STOP         = 3'b011,
             FLAG         = 3'b100;

  //Signal Decleration

  reg [$clog2(CLKS_PER_BIT):0] r_Clock_Count = 0;
  reg [                   2:0] r_Bit_Index   = 0; //8 bits total
  reg [                   7:0] r_RX_Byte     = 0;
  reg                          r_RX_DV       = 0;
  reg [                   2:0] STATE         = 0;
 
  // Purpose: Control RX state machine
  always @(posedge clk)
    begin
     r_RX_DV       <= 1'b0;
     r_Clock_Count <= 0;
      case (STATE)
        IDLE :
          begin
            r_Bit_Index   <= 0;
            if (Rx  == 1'b0)          // Start bit detected
              STATE <= START;
            else
              STATE <= IDLE;
          end

        // Check middle of start bit to make sure it's still low
        START :
          begin
            if (r_Clock_Count == (CLKS_PER_BIT-1)/2)
              begin
                if (Rx == 1'b0)
                  begin
                    STATE         <= RX_DATA;
                  end
                else
                  STATE <= IDLE;
              end
            else
              begin
                r_Clock_Count <= r_Clock_Count + 1;
                STATE         <= START;
              end
          end

        // Wait CLKS_PER_BIT-1 clock cycles to sample serial data
        RX_DATA :
          begin
            if (r_Clock_Count < CLKS_PER_BIT-1)
              begin
                r_Clock_Count <= r_Clock_Count + 1;
                STATE         <= RX_DATA;
              end
            else
              begin
                r_RX_Byte[r_Bit_Index] <= Rx;

                // Check if we have received all bits
                if (r_Bit_Index < 7)
                  begin
                    r_Bit_Index <= r_Bit_Index + 1;
                    STATE       <= RX_DATA;
                  end
                else
                  begin
                    r_Bit_Index <= 0;
                    STATE       <= STOP;
                  end
              end
          end // case: RX_DATA_BITS

        // Receive Stop bit.  Stop bit = 1
        STOP :
          begin
            // Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish
            if (r_Clock_Count < CLKS_PER_BIT-1)
              begin
                r_Clock_Count <= r_Clock_Count + 1;
                STATE         <= STOP;
              end
            else
              begin
                r_RX_DV       <= Rx; //Flag high if stop bit is valid
                r_Clock_Count <= 0;
                STATE         <= FLAG;
              end
          end

        // Stay here 1 clock
        FLAG :
          begin
            if (Rx)
                STATE   <= IDLE;
          end

        default :
          STATE <= IDLE;
      endcase
    end
  assign flag_Rx = r_RX_DV;
  assign RX_Byte = r_RX_Byte;
endmodule