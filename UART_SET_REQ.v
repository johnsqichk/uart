`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 08/11/2024 04:05:55 PM
// Design Name:
// Module Name: UART_SET_REQ
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
module UART_SET_REQ #(parameter CLKS_FREQ = 100000000,
                      parameter BAUD_RATE = 9600) 
    (
	input             clk                ,
	input             rst_n              ,
	input             rx                 ,
	output            tx                 ,
	///send data
	output reg        clock_set_data_uart,
	output reg [ 4:0] date_send          ,
	output reg [ 3:0] month_send         ,
	output reg [13:0] year_send          ,
	output reg [ 4:0] hour_send          ,
	output reg [ 5:0] min_send           ,
	output reg [ 5:0] sec_send           ,
	///receive data
	input      [ 4:0] date_rx            ,
	input      [ 3:0] month_rx           ,
	input      [13:0] year_rx            ,
	input      [ 4:0] hour_rx            ,
	input      [ 5:0] mint_rx            ,
	input      [ 5:0] sec_rx             ,
	//bcd
	output     [ 3:0] hour_bcd_0         ,
	output     [ 3:0] hour_bcd_1         ,
	output     [ 3:0] mint_bcd_0         ,
	output     [ 3:0] mint_bcd_1
);
	wire [       7:0] tx_byte            ;
	wire              flag_tx_byte       ;
	wire [       7:0] rx_byte            ;
	wire              flag_rx_byte       ;
	wire              tx_busy            ;
	reg  [       3:0] next_state         ;
	reg  [       3:0] current_state      ;
	reg  [ (7*8)-1:0] receive_data       ;
	reg  [       3:0] count_receive_bytes;
	reg  [(19*8)-1:0] send_data          ;
	reg  [       4:0] count_send_bytes   ;

	wire [ 4:0] date_send_cal ;
	wire [ 3:0] month_send_cal;
	wire [13:0] year_send_cal ;
	wire [ 4:0] hour_send_cal ;
	wire [ 5:0] min_send_cal  ;
	wire [ 5:0] sec_send_cal  ;

	wire [3:0] date_0 ;
	wire [3:0] date_1 ;
	wire [3:0] month_0;
	wire [3:0] month_1;
	wire [3:0] year_0 ;
	wire [3:0] year_1 ;
	wire [3:0] year_2 ;
	wire [3:0] year_3 ;
	wire [3:0] hours_0;
	wire [3:0] hours_1;
	wire [3:0] mint_0 ;
	wire [3:0] mint_1 ;
	wire [3:0] sec_0  ;
	wire [3:0] sec_1  ;

	localparam IDEAL_STATE     = 3'd0,
		CHECK_SET_OR_REQ       = 3'd1,
		SET_REQ_DATA           = 3'd2,
		SEND_REQ_DATA          = 3'd3,
		RECEIVE_SET_DATA       = 3'd4,
		RECEIVE_SET_DATA_DONE  = 3'd5;

	UART_TOP  #(
		.CLKS_FREQ(CLKS_FREQ),
		.BAUD_RATE(BAUD_RATE)
	) inst_uart_top  (
		.clk         (clk         ),
		.Rx          (rx          ),
		.Tx          (tx          ),
		.flag_tx_byte(flag_tx_byte),
		.tx_byte     (tx_byte     ),
		.tx_busy     (tx_busy     ),
		.flag_rx_byte(flag_rx_byte),
		.rx_byte     (rx_byte     )
	);

	//=================================
	//======= STATE REGISTER ==========
	//=================================
	always @ (posedge clk) begin
		if (!rst_n)
			current_state <= IDEAL_STATE;
		else
			current_state <= next_state;
	end

	//================================
	//========= STATE LOGIC ==========
	//================================
	always @ (*) begin
		case (current_state)
			// IDEAL STATE
			IDEAL_STATE : begin
				next_state <= CHECK_SET_OR_REQ;
			end

			//CHECK THE REQUEST TYPE
			CHECK_SET_OR_REQ : begin
				if (flag_rx_byte) begin
					if (rx_byte == 8'h4B) //K
						next_state <= RECEIVE_SET_DATA;
					else if (rx_byte == 8'h52) //R
						next_state <= SET_REQ_DATA;
					else
						next_state <= CHECK_SET_OR_REQ;
				end
				else begin
					next_state <= CHECK_SET_OR_REQ;
				end
			end

			//RECEIVE SET DATA
			RECEIVE_SET_DATA : begin
				if (count_receive_bytes == 4'd14)
					next_state <= RECEIVE_SET_DATA_DONE;
				else
					next_state <= RECEIVE_SET_DATA;
			end

			//SEND RECEIVE DATA TO CLOCK
			RECEIVE_SET_DATA_DONE : begin
				next_state <= IDEAL_STATE;
			end

			//SET CLOCK DATA FOR SEND
			SET_REQ_DATA : begin
				next_state <= SEND_REQ_DATA;
			end

			///SEND REQ DATA STATE
			SEND_REQ_DATA : begin
				if (count_send_bytes == 5'd19)
					next_state <= IDEAL_STATE;
				else
					next_state <= SEND_REQ_DATA;
			end
			
			default : begin
			     next_state <= IDEAL_STATE;
			end
		endcase
	end


	//// count_receive_bytes
	always @ (posedge clk) begin
		if (current_state == RECEIVE_SET_DATA) begin
			if (flag_rx_byte)
				count_receive_bytes <= count_receive_bytes + 1'b1;
			else
				count_receive_bytes <= count_receive_bytes;
		end
		else begin
			count_receive_bytes <= 0;
		end
	end

	//// receive_data
	always @ (posedge clk) begin
		if (current_state == IDEAL_STATE)
			receive_data <= 0;
		else if (current_state == RECEIVE_SET_DATA) begin
			if (flag_rx_byte)
				receive_data <= {receive_data[51:0],rx_byte[3:0]};
			else
				receive_data <= receive_data;
		end
		else begin
			receive_data <= receive_data;
		end
	end

	//bcd to decimal date
	bcd_to_decimal inst_date_send_cal (
		.bcd_0  (receive_data[(4*12)+3:(4*12)]),
		.bcd_1  (receive_data[(4*13)+3:(4*13)]),
		.bcd_2  (4'd0                         ),
		.bcd_3  (4'd0                         ),
		.decimal(date_send_cal                )
	);

	//bcd to decimal month
	bcd_to_decimal inst_month_send_cal (
		.bcd_0  (receive_data[(4*10)+3:(4*10)]),
		.bcd_1  (receive_data[(4*11)+3:(4*11)]),
		.bcd_2  (4'd0                         ),
		.bcd_3  (4'd0                         ),
		.decimal(month_send_cal               )
	);

	//bcd to year date
	bcd_to_decimal inst_year_send_cal (
		.bcd_0  (receive_data[(4*6)+3:(4*6)]),
		.bcd_1  (receive_data[(4*7)+3:(4*7)]),
		.bcd_2  (receive_data[(4*8)+3:(4*8)]),
		.bcd_3  (receive_data[(4*9)+3:(4*9)]),
		.decimal(year_send_cal              )
	);

	//bcd to hours month
	bcd_to_decimal inst_hour_send_cal (
		.bcd_0  (receive_data[(4*4)+3:(4*4)]),
		.bcd_1  (receive_data[(4*5)+3:(4*5)]),
		.bcd_2  (4'd0                       ),
		.bcd_3  (4'd0                       ),
		.decimal(hour_send_cal              )
	);

	//bcd to min month
	bcd_to_decimal inst_min_send_cal (
		.bcd_0  (receive_data[(4*2)+3:(4*2)]),
		.bcd_1  (receive_data[(4*3)+3:(4*3)]),
		.bcd_2  (4'd0                       ),
		.bcd_3  (4'd0                       ),
		.decimal(min_send_cal               )
	);

	//bcd to sec month
	bcd_to_decimal inst_sec_send_cal (
		.bcd_0  (receive_data[(4*0)+3:(4*0)]),
		.bcd_1  (receive_data[(4*1)+3:(4*1)]),
		.bcd_2  (4'd0                       ),
		.bcd_3  (4'd0                       ),
		.decimal(sec_send_cal               )
	);


	//// count_receive_bytes
	always @ (posedge clk) begin
		if (current_state == RECEIVE_SET_DATA_DONE) begin
			clock_set_data_uart <= 1'b1;
		end
		else begin
			clock_set_data_uart <= 1'b0;
		end
	end

	///set output values for clock module
	always @(posedge clk) begin
		if(!rst_n) begin
			date_send  <= 0;
			month_send <= 0;
			year_send  <= 0;
			hour_send  <= 0;
			min_send   <= 0;
			sec_send   <= 0;
		end
		else if (current_state == RECEIVE_SET_DATA_DONE) begin
			date_send  <= date_send_cal;
			month_send <= month_send_cal;
			year_send  <= year_send_cal;
			hour_send  <= hour_send_cal;
			min_send   <= min_send_cal;
			sec_send   <= sec_send_cal;
		end
		else begin
			date_send  <= date_send;
			month_send <= month_send;
			year_send  <= year_send;
			hour_send  <= hour_send;
			min_send   <= min_send;
			sec_send   <= sec_send;
		end
	end

	//decimal to bcd date
	decimal_to_bcd inst_date (
		.clk       (clk                 ),
		.decimal_in({9'd0 ,date_rx[4:0]}),
		.BCD_0     (date_0              ),
		.BCD_1     (date_1              ),
		.BCD_2     (                    ),
		.BCD_3     (                    )
	);

	//decimal to bcd month
	decimal_to_bcd inst_month (
		.clk       (clk                   ),
		.decimal_in({10'd0 ,month_rx[3:0]}),
		.BCD_0     (month_0               ),
		.BCD_1     (month_1               ),
		.BCD_2     (                      ),
		.BCD_3     (                      )
	);

	//decimal to bcd year
	decimal_to_bcd inst_year (
	    .clk       (clk    ),
		.decimal_in(year_rx),
		.BCD_0     (year_0 ),
		.BCD_1     (year_1 ),
		.BCD_2     (year_2 ),
		.BCD_3     (year_3 )
	);

	//decimal to bcd hour
	decimal_to_bcd inst_hour (
		.clk       (clk                 ),
		.decimal_in({9'd0 ,hour_rx[4:0]}),
		.BCD_0     (hours_0             ),
		.BCD_1     (hours_1             ),
		.BCD_2     (                    ),
		.BCD_3     (                    )
	);

	//decimal to bcd mint
	decimal_to_bcd inst_mint (
	    .clk       (clk                ),
		.decimal_in({8'd0 ,mint_rx[5:0]}),
		.BCD_0     (mint_0              ),
		.BCD_1     (mint_1              ),
		.BCD_2     (                    ),
		.BCD_3     (                    )
	);

	//decimal to bcd sec
	decimal_to_bcd inst_sec (
		.clk      (clk                ),
		.decimal_in({8'd0 ,sec_rx[5:0]}),
		.BCD_0     (sec_0              ),
		.BCD_1     (sec_1              ),
		.BCD_2     (                   ),
		.BCD_3     (                   )
	);

	assign hour_bcd_0 = hours_0;
	assign hour_bcd_1 = hours_1;

	assign mint_bcd_0 = mint_0;
	assign mint_bcd_1 = mint_1;
	/////send_data
	always @(posedge clk) begin
		if(!rst_n) begin
			send_data <= 0;
		end
		else if (current_state == SET_REQ_DATA) begin
			send_data <= {4'd3, date_1[3:0], 4'd3, date_0[3:0], 8'h2E, 4'd3, month_1[3:0], 4'd3, month_0[3:0], 8'h2E, 4'd3, year_3[3:0],
				4'd3, year_2[3:0], 4'd3, year_1[3:0], 4'd3, year_0[3:0], 8'h20, 4'd3, hours_1[3:0], 4'd3, hours_0[3:0], 8'h3A,
				4'd3, mint_1[3:0], 4'd3, mint_0[3:0], 8'h3A, 4'd3, sec_1[3:0], 4'd3, sec_0[3:0]};
		end
		else if (flag_tx_byte)
			send_data <= {send_data[143:0], 8'h0};
		else
			send_data <= send_data;
	end

	//// count_send_bytes
	always @ (posedge clk) begin
		if (current_state == SET_REQ_DATA)begin
			count_send_bytes <= 0;
		end
		else if (current_state == SEND_REQ_DATA) begin
			if (!tx_busy)
				count_send_bytes <= count_send_bytes + 1'b1;
			else
				count_send_bytes <= count_send_bytes;
		end
		else begin
			count_send_bytes <= count_send_bytes;
		end
	end

	assign tx_byte      = send_data[151:144];
	assign flag_tx_byte = (current_state == SEND_REQ_DATA) ? !tx_busy : 1'b0;

endmodule
